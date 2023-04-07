#!/usr/bin/env bash

set -eo pipefail

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd $__dir
trap popd EXIT

: "${POSTGRES_VERSION:=15}"
: "${POSTGRES_PASSWORD:=postgres}"

docker build --build-arg POSTGRES_VERSION=$POSTGRES_VERSION . -t ephemeral-postgres:$POSTGRES_VERSION

docker stop postgres || echo 'already stopped'

if [[ "$OSTYPE" =~ ^linux ]]; then
  MNT='--mount type=tmpfs,destination=/var/lib/postgresql/data'
else
  MNT=''
fi

docker run --rm -d --name postgres $MNT \
  -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  -p 5432:5432 ephemeral-postgres:$POSTGRES_VERSION \
  -c shared_buffers=256MB \
  -c 'shared_preload_libraries=$libdir/ensure_database_exists'
