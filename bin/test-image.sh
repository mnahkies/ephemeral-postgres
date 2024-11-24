#!/usr/bin/env bash

set -xeo pipefail

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pushd "$__dir"
trap popd EXIT

if [[ -z "$1" ]]; then
  echo "Error: POSTGRES_VERSION is required as the first argument."
  exit 1
fi

export POSTGRES_VERSION="${1}"
export POSTGRES_EXTENSIONS=ltree postgis
# reuse the image we just built
export FORCE_BUILD=1

../start-ephemeral-postgres.sh

docker exec -it postgres psql -e -U some_user -d some_database -c "SELECT PostGIS_Version();"
