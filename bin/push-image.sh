#!/usr/bin/env bash

set -xeo pipefail

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "$__dir"
trap popd EXIT

if [[ -z "$1" ]]; then
  echo "Error: POSTGRES_VERSION is required as the first argument."
  exit 1
fi

POSTGRES_VERSION="${1}"

docker push mnahkies/ephemeral-postgres:"${POSTGRES_VERSION}"
