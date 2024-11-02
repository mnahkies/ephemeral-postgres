#!/usr/bin/env bash

set -xeo pipefail

POSTGRES_VERSIONS=(
	14 
	15 
	16 
	17
)

for POSTGRES_VERSION in "${POSTGRES_VERSIONS[@]}"; do
    docker build --build-arg POSTGRES_VERSION="${POSTGRES_VERSION}" . -t mnahkies/ephemeral-postgres:"${POSTGRES_VERSION}"
    docker push mnahkies/ephemeral-postgres:"${POSTGRES_VERSION}"
done
