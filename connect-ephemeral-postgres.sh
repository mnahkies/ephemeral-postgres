#!/usr/bin/env bash

set -eo pipefail

docker exec -it postgres psql -U postgres
