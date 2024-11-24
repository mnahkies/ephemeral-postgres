#!/usr/bin/env bash

export POSTGRES_VERSION="17"
export POSTGRES_USER="postgres"
export POSTGRES_PASSWORD="postgres"
export POSTGRES_HOST_AUTH_METHOD="trust"
export POSTGRES_ROLE_ATTRIBUTES="LOGIN CREATEDB"
export POSTGRES_EXTENSIONS="ltree postgis"

export EPHEMERAL_POSTGRES_AUTO_UPDATE="1"
export EPHEMERAL_POSTGRES_FORCE_BUILD="0"

# Set to empty string to use a tmpfs / ram disk instead
export EPHEMERAL_POSTGRES_DATA_DIR="./data"

# Defaults to uid:gid of current user, set to empty to use upstream default user
EPHEMERAL_POSTGRES_LINUX_USER=$(id -u)
export EPHEMERAL_POSTGRES_LINUX_USER
