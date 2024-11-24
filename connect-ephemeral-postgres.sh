#!/usr/bin/env bash

set -eo pipefail

__dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
pushd "$__dir"
trap popd EXIT

source ./ephemeral-postgres-config.sh

docker exec -it postgres psql -U postgres
