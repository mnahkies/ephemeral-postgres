#include "postgres.h"
#include "fmgr.h"

#include "libpq/auth.h"
#include "executor/spi.h"
#include "miscadmin.h"

PG_MODULE_MAGIC;

static ClientAuthentication_hook_type original_client_auth_hook = NULL;

static void execute_command(const char *cmd) {
    int result = system(cmd);

    if (result != 0) {
        ereport(ERROR, (
                    errmsg("command failed"),
                    errdetail("Command: %s\nExit code: %d", cmd, WEXITSTATUS(result))
                )
        );
    }
}

static void ensure_role_and_database_exists(Port *port, int status) {
    char *cmd = NULL;
    const char *postgres_user = getenv("POSTGRES_USER");
    const char *role_attributes = getenv("POSTGRES_ROLE_ATTRIBUTES");

    if (original_client_auth_hook) {
        original_client_auth_hook(port, status);
    }

    if (!postgres_user) {
        ereport(ERROR, errmsg("POSTGRES_USER environment variable is not set."));
    }

    if (!role_attributes) {
        ereport(ERROR, errmsg("POSTGRES_ROLE_ATTRIBUTES environment variable is not set."));
    }

    // don't infinitely recurse when connecting as superuser
    if (strcmp(port->user_name, postgres_user) == 0 && strcmp(port->database_name, postgres_user) == 0) {
        return;
    }

    elog(LOG, "handling connection for username '%s' to database '%s'", port->user_name, port->database_name);

    elog(LOG, "ensuring user_name '%s' exists with attributes '%s'", port->user_name, role_attributes);
    if (asprintf(&cmd,
                 "echo \"SELECT 'CREATE ROLE %s WITH %s' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '%s')\\gexec\" | psql -U %s -d %s",
                 port->user_name,
                 role_attributes,
                 port->user_name,
                 postgres_user,
                 postgres_user
    ) < 0) {
        ereport(ERROR, errmsg("failed to allocate command string"));
    }

    execute_command(cmd);
    free(cmd);

    elog(LOG, "ensuring database '%s' exists", port->database_name);

    if (asprintf(&cmd,
                 "echo \"SELECT 'CREATE DATABASE %s WITH OWNER = %s' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '%s')\\gexec\" | psql -U %s -d %s",
                 port->database_name,
                 port->user_name,
                 port->database_name,
                 postgres_user,
                 postgres_user
    ) < 0) {
        ereport(ERROR, errmsg("failed to allocate command string"));
    }

    execute_command(cmd);
    free(cmd);
}

void _PG_init(void) {
    original_client_auth_hook = ClientAuthentication_hook;
    ClientAuthentication_hook = ensure_role_and_database_exists;
}
