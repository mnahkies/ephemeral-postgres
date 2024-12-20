#include <stdlib.h>

#include "postgres.h"
#include "fmgr.h"

#include "libpq/auth.h"
#include <unistd.h>

PG_MODULE_MAGIC;

static ClientAuthentication_hook_type original_client_auth_hook = NULL;

static void ensure_role_and_database_exists(Port *port, int status) {
    char *cmd;
    char *postgres_user;
    char *role_attributes;

    if (original_client_auth_hook) {
        original_client_auth_hook(port, status);
    }

    postgres_user = getenv("POSTGRES_USER");

    fprintf(stderr, "handling connection for username '%s' to database '%s'\n", port->user_name, port->database_name);

    // don't infinitely recurse when connecting as superuser
    if (strcmp(port->database_name, postgres_user) == 0 && strcmp(port->user_name, postgres_user) == 0) {
        return;
    }

    role_attributes = getenv("POSTGRES_ROLE_ATTRIBUTES");

    fprintf(stderr, "ensuring user_name '%s' exists with attributes '%s'\n", port->user_name, role_attributes);
    asprintf(&cmd,
             "echo \"SELECT 'CREATE ROLE %s WITH %s' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '%s')\\gexec\" | psql -U %s -d %s",
             port->user_name, role_attributes, port->user_name, postgres_user, postgres_user);
    system(cmd);
    free(cmd);

    fprintf(stderr, "ensuring database '%s' exists\n", port->database_name);
    asprintf(&cmd,
             "echo \"SELECT 'CREATE DATABASE %s WITH OWNER = %s' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '%s')\\gexec\" | psql -U %s -d %s",
             port->database_name, port->user_name, port->database_name, postgres_user, postgres_user);
    system(cmd);
    free(cmd);
}

void _PG_init(void) {
    original_client_auth_hook = ClientAuthentication_hook;
    ClientAuthentication_hook = ensure_role_and_database_exists;
}
