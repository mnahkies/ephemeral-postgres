#!/usr/bin/env bash

set -xeo pipefail

if [[ -z "$1" ]]; then
  echo "Error: POSTGRES_VERSION is required as the first argument."
  exit 1
fi

POSTGRES_VERSION="${1}"

docker build --build-arg POSTGRES_VERSION="${POSTGRES_VERSION}" . -t mnahkies/ephemeral-postgres:"${POSTGRES_VERSION}"
docker push mnahkies/ephemeral-postgres:"${POSTGRES_VERSION}"
