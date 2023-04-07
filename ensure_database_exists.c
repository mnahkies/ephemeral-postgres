#include "postgres.h"
#include "fmgr.h"

#include "libpq/auth.h"

#include <unistd.h>

PG_MODULE_MAGIC;

static ClientAuthentication_hook_type original_client_auth_hook = NULL;

static void ensure_database_exists(Port *port, int status) {
    char *cmd;

    if (original_client_auth_hook) {
        original_client_auth_hook(port, status);
    }

    if (strcmp(port->database_name, "postgres") == 0) {
        return;
    }

    fprintf(stderr, "ensuring database '%s' exists\n", port->database_name);

    asprintf(&cmd,
             "echo \"SELECT 'CREATE DATABASE %s' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '%s')\\gexec\" | psql",
             port->database_name, port->database_name);
    system(cmd);
    free(cmd);
}

void _PG_init(void) {
    original_client_auth_hook = ClientAuthentication_hook;
    ClientAuthentication_hook = ensure_database_exists;
}
