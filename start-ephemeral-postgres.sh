#!/usr/bin/env bash

set -xeo pipefail

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd $__dir
trap popd EXIT

: "${POSTGRES_VERSION:=17}"
: "${POSTGRES_PASSWORD:=postgres}"
: "${POSTGRES_HOST_AUTH_METHOD:=trust}"
: "${ROLE_ATTRIBUTES:=LOGIN CREATEDB}"

IMAGE=mnahkies/ephemeral-postgres:$POSTGRES_VERSION

docker stop postgres || echo 'already stopped'
docker rm postgres || echo 'already removed'

if ! docker pull "$IMAGE"; then
  echo "Image '${IMAGE}' not found. Building Docker image with POSTGRES_VERSION=$POSTGRES_VERSION"
  docker build --build-arg POSTGRES_VERSION="${POSTGRES_VERSION}" . -t "${IMAGE}"
fi

if [[ "$OSTYPE" =~ ^linux ]]; then
  MNT='--mount type=tmpfs,destination=/var/lib/postgresql/data'
else
  MNT=''
fi

docker run -d --rm --name postgres $MNT \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  -e POSTGRES_HOST_AUTH_METHOD="${POSTGRES_HOST_AUTH_METHOD}" \
  -e ROLE_ATTRIBUTES="${ROLE_ATTRIBUTES}" \
  -p 5432:5432 "${IMAGE}" \
  -c shared_buffers=256MB \
  -c 'shared_preload_libraries=$libdir/ensure_role_and_database_exists'
