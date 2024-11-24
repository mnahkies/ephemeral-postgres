# ephemeral-postgres
[![Docker Pulls](https://img.shields.io/docker/pulls/mnahkies/ephemeral-postgres)](https://hub.docker.com/r/mnahkies/ephemeral-postgres) [![GitHub Repo stars](https://img.shields.io/github/stars/mnahkies/ephemeral-postgres)](https://github.com/mnahkies/ephemeral-postgres)

A bash script that starts an ephemeral postgres locally in docker for **development purposes**.

By default, **Data is destroyed** between runs, and on Linux the data is stored on a `tmpfs` (ramdisk)
for faster startup.

For persistent data, configure `EPHEMERAL_POSTGRES_DATA_DIR` to be a path you wish to 
store the data on your host machine.

The container loads a `ClientAuthentication` hook `ensure_role_and_database_exists` that
automatically creates roles & databases that don't exist when connections are made.

This allows you to just start the container and not worry about pre-creating users or
databases for your integration test suites, etc.

By default, it will create users with `LOGIN CREATEDB` and authenticate using `TRUST` but
this can be customized with the environment variables below.

Prebuild images are pulled from dockerhub automatically for recent postgres versions.

## Installation

- Requires `docker` to be installed https://docs.docker.com/engine/install/
- Clone the repo
- (Optionally) add the repo to your `$PATH`

```shell
git clone git@github.com:mnahkies/ephemeral-postgres.git ~/.local/share/ephemeral-postgres
ln -s ~/.local/share/ephemeral-postgres/start-ephemeral-postgres.sh ~/.local/bin/start-postgres
ln -s ~/.local/share/ephemeral-postgres/connect-ephemeral-postgres.sh ~/.local/bin/connect-postgres
```

## Usage

Start the `postgres` server:

```shell
start-ephemeral-postgres.sh
```

**Options**
- `POSTGRES_VERSION=17`
- `POSTGRES_USER=postgres`
- `POSTGRES_PASSWORD=postgres`
- `POSTGRES_HOST_AUTH_METHOD=trust` - could be `scram-sha-256` / `md5` / etc
- `POSTGRES_ROLE_ATTRIBUTES='LOGIN CREATEDB'` - could be `SUPERUSER` / `CREATEROLE BYPASSRLS` / etc
- `POSTGRES_EXTENSIONS=` - could be `postgis ltree` / etc
- `EPHEMERAL_POSTGRES_FORCE_BUILD=0` - force building the docker image locally instead of pulling a prebuilt image
- `EPHEMERAL_POSTGRES_AUTO_UPDATE=1` - whether to automatically check for updates to `ephemeral-postgres`
- `EPHEMERAL_POSTGRES_DATA_DIR=` - when empty, use a tmpfs / ram disk, otherwise a path to bind mount to the postgres data directory
- `EPHEMERAL_POSTGRES_LINUX_USER=$(id -u)` - linux `uid` / `gid` to run postgres as, defaulting to current users
- `EPHEMERAL_POSTGRES_DOCKER_RUN_ARGS` - used internally, but you can pass arbitrary flags for `docker run` here, eg: `--network=foo`

You can also create a `.env.sh` file and this will be automatically loaded by `start-ephemeral-postgres.sh`

Connect using `psql`:

```shell
docker exec -it postgres psql -U postgres postgres
docker exec -it postgres psql -U any_username any_database_name
```

## References

See https://github.com/taminomara/psql-hooks for the unofficial documentation of Postgresql hooks

These slides are also a good reference: https://wiki.postgresql.org/images/e/e3/Hooks_in_postgresql.pdf
