#!/usr/bin/env bash

set -eo pipefail

__dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
pushd "$__dir"
trap popd EXIT

source ./ephemeral-postgres-config.sh

has_no_cow() {
    local file="$1"
    [[ "$(lsattr "$file" 2>/dev/null | awk '{print $1}')" == *C* ]]
}

disable_cow() {
    local dir="$1"

    if has_no_cow "$dir"; then
        echo "Skipping $dir: already has No_COW attribute"
        return
    fi

    # Set the No_COW attribute on the directory
    chattr +C "$dir"
    if [[ $? -ne 0 ]]; then
        echo "Failed to set +C attribute on $dir"
        exit 1
    fi

    # Recreate files and directories to ensure +C applies to them
    for file in "$dir"/*; do
        if [[ -f "$file" ]]; then
          if has_no_cow "$file"; then
              echo "Skipping $file: already has No_COW attribute"
          else
          echo "Disable CoW on $file"
            mv "$file" "$file.tmp"
            cp --preserve=all "$file.tmp" "$file"
            rm "$file.tmp"
          fi
        elif [[ -d "$file" ]]; then
            disable_cow "$file" # Recursively disable CoW in subdirectories
        fi
    done
}

if [[ "${EPHEMERAL_POSTGRES_AUTO_UPDATE}" -eq 1 ]]; then
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    if [ -z "$(git status --porcelain)" ]; then
      echo "Repository is clean. Pulling latest changes..."
      git pull
    else
      echo "Repository has uncommitted changes. Skipping pull."
    fi
  else
    echo "Current directory is not a Git repository."
  fi
fi

IMAGE=mnahkies/ephemeral-postgres:$POSTGRES_VERSION

docker stop postgres > /dev/null 2>&1 || echo 'already stopped'
docker rm postgres > /dev/null 2>&1 || echo 'already removed'

if [[ "${EPHEMERAL_POSTGRES_FORCE_BUILD}" -ne 0 ]]; then
  echo "Force build enabled. Skipping pull and building Docker image with POSTGRES_VERSION=$POSTGRES_VERSION"
  docker build --build-arg POSTGRES_VERSION="${POSTGRES_VERSION}" . -t "${IMAGE}"
else

  if ! docker pull "$IMAGE"; then
    echo "Prebuilt image '${IMAGE}' not found. Building Docker image with POSTGRES_VERSION=$POSTGRES_VERSION"
    docker build --build-arg POSTGRES_VERSION="${POSTGRES_VERSION}" . -t "${IMAGE}"
  fi
fi

if [ -n "$EPHEMERAL_POSTGRES_DATA_DIR" ]; then
  EPHEMERAL_POSTGRES_DATA_DIR=$(realpath "$EPHEMERAL_POSTGRES_DATA_DIR")

  if [ ! -d "$EPHEMERAL_POSTGRES_DATA_DIR" ]; then
    echo "Creating $EPHEMERAL_POSTGRES_DATA_DIR"
    mkdir -p "$EPHEMERAL_POSTGRES_DATA_DIR"
  fi

  EPHEMERAL_POSTGRES_DOCKER_RUN_ARGS+=" -v $EPHEMERAL_POSTGRES_DATA_DIR:/var/lib/postgresql/data"
  echo "Using data directory $EPHEMERAL_POSTGRES_DATA_DIR"

  # CoW (eg: with btrs) has a bad time with the frequent small writes from postgres
  if [[ "$OSTYPE" =~ ^linux ]]; then
    echo "Disabling CoW (copy on write) in data directory $EPHEMERAL_POSTGRES_DATA_DIR"
    disable_cow "$EPHEMERAL_POSTGRES_DATA_DIR"
  fi

else
  if [[ "$OSTYPE" =~ ^linux ]]; then
    echo "Using ram disk"
    EPHEMERAL_POSTGRES_DOCKER_RUN_ARGS+='--mount type=tmpfs,destination=/var/lib/postgresql/data'
    # Postgres encounters permission issues when using the ram disk unless run as its default linux user
    EPHEMERAL_POSTGRES_LINUX_USER=''
  fi
fi

if [ -n "$EPHEMERAL_POSTGRES_LINUX_USER" ]; then
  EPHEMERAL_POSTGRES_DOCKER_RUN_ARGS+=" --user $EPHEMERAL_POSTGRES_LINUX_USER"
fi

# shellcheck disable=SC2086
docker run -d --name postgres $EPHEMERAL_POSTGRES_DOCKER_RUN_ARGS \
  -e POSTGRES_USER="${POSTGRES_USER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  -e POSTGRES_HOST_AUTH_METHOD="${POSTGRES_HOST_AUTH_METHOD}" \
  -e POSTGRES_ROLE_ATTRIBUTES="${POSTGRES_ROLE_ATTRIBUTES}" \
  -p 5432:5432 "${IMAGE}" \
  -c shared_buffers=256MB \
  -c 'shared_preload_libraries=$libdir/ensure_role_and_database_exists'

while ! docker exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_USER" -c 'SELECT 1;' > /dev/null 2>&1; do
  echo "Waiting for postgres to start..."
  sleep 1
done

for POSTGRES_EXTENSION in $POSTGRES_EXTENSIONS; do
  docker exec postgres psql -e -U "$POSTGRES_USER" -d template1 -c "CREATE EXTENSION IF NOT EXISTS $POSTGRES_EXTENSION;"
done
