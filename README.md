#  ephemeral-postgres

A bash script that starts an ephemeral postgres locally in docker. 

**Data is destroyed** between runs, on Linux the data is stored on a `tmpfs` / ramdisk
for faster startup

The container loads a `ClientAuthentication` hook `ensure_database_exists` that
automatically creates databases that don't exist when connections are made.

This allows you to just start the container and not worry about pre-creating databases
for your integration test suites, etc.

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
- `POSTGRES_VERSION=15`
- `POSTGRES_PASSWORD=postgres`

Connect using `psql`:

```shell
connect-ephemeral-postgres.sh
```

## References
See https://github.com/taminomara/psql-hooks for the unofficial documentation of Postgresql hooks

These slides are also a good reference: https://wiki.postgresql.org/images/e/e3/Hooks_in_postgresql.pdf
