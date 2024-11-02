# ephemeral-postgres
![Docker Pulls](https://img.shields.io/docker/pulls/mnahkies/ephemeral-postgres)

A bash script that starts an ephemeral postgres locally in docker for **development purposes**.

**Data is destroyed** between runs, on Linux the data is stored on a `tmpfs` / ramdisk
for faster startup.

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

## Usage

Start the `postgres` server:

```shell
start-ephemeral-postgres.sh
```

**Options**

- `POSTGRES_VERSION=17`
- `POSTGRES_PASSWORD=postgres`
- `POSTGRES_HOST_AUTH_METHOD=trust` - could be `scram-sha-256` / `md5` / etc
- `ROLE_ATTRIBUTES='LOGIN CREATEDB'` - could be `SUPERUSER` / `CREATEROLE BYPASSRLS` / etc
- `FORCE_BUILD=0` - force building the docker image locally instead of pulling a prebuilt image

Connect using `psql`:

```shell
docker exec -it postgres psql -U postgres postgres
docker exec -it postgres psql -U any_username any_database_name
```

## References

See https://github.com/taminomara/psql-hooks for the unofficial documentation of Postgresql hooks

These slides are also a good reference: https://wiki.postgresql.org/images/e/e3/Hooks_in_postgresql.pdf
