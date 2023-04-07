#  ephemeral-postgres

A bash script that starts an ephemeral postgres locally in docker. 

**Data is destroyed** between runs, on Linux the data is stored on a `tmpfs` / ramdisk
for faster startup

The container loads a `ClientAuthentication` hook `ensure_database_exists` that
automatically creates databases that don't exist when connections are made.

This allows you to just start the container and not worry about pre-creating databases
for your integration test suites, etc.

## Usage

Start the `postgres` server:

```shell
start-ephemeral-postgres.sh
```

**Options**
- `POSTGRES_VERSION=15`
- `POSTGRES_PASSWORD=postgres`

Add the cloned repo to your `$PATH` for added convenience.

Connect using `psql`:

```shell
connect-ephemeral-postgres.sh
```
