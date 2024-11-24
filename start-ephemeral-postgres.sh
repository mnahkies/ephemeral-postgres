#!/usr/bin/env bash

set -eo pipefail

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd $__dir
trap popd EXIT

: "${POSTGRES_VERSION:=17}"
: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_PASSWORD:=postgres}"
: "${POSTGRES_HOST_AUTH_METHOD:=trust}"
: "${POSTGRES_ROLE_ATTRIBUTES:=LOGIN CREATEDB}"
: "${POSTGRES_EXTENSIONS:=}"

: "${EPHEMERAL_POSTGRES_AUTO_UPDATE:=1}"
: "${EPHEMERAL_POSTGRES_FORCE_BUILD:=0}"

if [ -f .env.sh ]; then
  echo "loading config from '.env.sh'"
  source .env.sh
fi

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

docker stop postgres || echo 'already stopped'
docker rm postgres || echo 'already removed'

if [[ "${EPHEMERAL_POSTGRES_FORCE_BUILD}" -ne 0 ]]; then
  echo "Force build enabled. Skipping pull and building Docker image with POSTGRES_VERSION=$POSTGRES_VERSION"
  docker build --build-arg POSTGRES_VERSION="${POSTGRES_VERSION}" . -t "${IMAGE}"
else

  if ! docker pull "$IMAGE"; then
    echo "Prebuilt image '${IMAGE}' not found. Building Docker image with POSTGRES_VERSION=$POSTGRES_VERSION"
    docker build --build-arg POSTGRES_VERSION="${POSTGRES_VERSION}" . -t "${IMAGE}"
  fi
fi

if [[ "$OSTYPE" =~ ^linux ]]; then
  MNT='--mount type=tmpfs,destination=/var/lib/postgresql/data'
else
  MNT=''
fi

docker run -d --rm --name postgres $MNT \
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
