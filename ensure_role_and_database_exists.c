#include <stdlib.h>
#include <sys/wait.h>

#include "postgres.h"
#include "fmgr.h"

#include "libpq/auth.h"
#include <unistd.h>

PG_MODULE_MAGIC;

static ClientAuthentication_hook_type original_client_auth_hook = NULL;

static int execute_command(const char *cmd) {
    int result = system(cmd);

    if (result != 0) {
        fprintf(stderr, "Command failed: %s (exit code: %d)\n", cmd, result);
        ereport(ERROR,
                (errmsg("command failed"),
                 errdetail("Command: %s\nExit code: %d", cmd, WEXITSTATUS(result))));
    }

    return result;
}

static void ensure_role_and_database_exists(Port *port, int status) {
    char *cmd = NULL;
    const char *postgres_user = getenv("POSTGRES_USER");
    const char *role_attributes = getenv("POSTGRES_ROLE_ATTRIBUTES");

    if (original_client_auth_hook) {
        original_client_auth_hook(port, status);
    }

    if (!postgres_user) {
        fprintf(stderr, "Error: POSTGRES_USER environment variable is not set.\n");
        return;
    }

    fprintf(stderr, "handling connection for username '%s' to database '%s'\n", port->user_name, port->database_name);

    // don't infinitely recurse when connecting as superuser
    if (strcmp(port->database_name, postgres_user) == 0 && strcmp(port->user_name, postgres_user) == 0) {
        return;
    }

    if (!role_attributes) {
        fprintf(stderr, "Error: POSTGRES_ROLE_ATTRIBUTES environment variable is not set.\n");
        return;
    }

    fprintf(stderr, "ensuring user_name '%s' exists with attributes '%s'\n", port->user_name, role_attributes);

    asprintf(&cmd,
             "echo \"SELECT 'CREATE ROLE %s WITH %s' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '%s')\\gexec\" | psql -U %s -d %s",
             port->user_name, role_attributes, port->user_name, postgres_user, postgres_user);

    execute_command(cmd);
    free(cmd);

    fprintf(stderr, "ensuring database '%s' exists\n", port->database_name);

    asprintf(&cmd,
             "echo \"SELECT 'CREATE DATABASE %s WITH OWNER = %s' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '%s')\\gexec\" | psql -U %s -d %s",
             port->database_name, port->user_name, port->database_name, postgres_user, postgres_user);

    execute_command(cmd);
    free(cmd);
}

void _PG_init(void) {
    original_client_auth_hook = ClientAuthentication_hook;
    ClientAuthentication_hook = ensure_role_and_database_exists;
}
