#include "postgres.h"
#include "fmgr.h"

#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>
#include "lib/stringinfo.h"

#include "libpq/auth.h"
#include "miscadmin.h"

PG_MODULE_MAGIC;

#define INTERNAL_MARKER "ephemeral_pg.internal=true"

static ClientAuthentication_hook_type original_client_auth_hook = NULL;

static void execute_command(const char *cmd) {
    int         pipefd[2];
    pid_t       pid;

    if (pipe(pipefd) == -1)
        ereport(ERROR, (errmsg("failed to create pipe: %m")));

    pid = fork();
    if (pid == -1)
    {
        close(pipefd[0]);
        close(pipefd[1]);
        ereport(ERROR, (errmsg("failed to fork: %m")));
    }

    if (pid == 0)
    {
        /* Child process */
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);

        execl("/bin/sh", "sh", "-c", cmd, (char *) NULL);
        /* If execl returns, it failed */
        _exit(127);
    }
    else
    {
        /* Parent process */
        char            buffer[1024];
        ssize_t         nbytes;
        StringInfoData  output;
        int             status;

        close(pipefd[1]);
        initStringInfo(&output);

        while ((nbytes = read(pipefd[0], buffer, sizeof(buffer))) != 0)
        {
            if (nbytes == -1)
            {
                if (errno == EINTR)
                    continue;
                break;
            }
            appendBinaryStringInfo(&output, buffer, nbytes);
        }

        close(pipefd[0]);

        if (waitpid(pid, &status, 0) == -1)
            ereport(ERROR, (errmsg("waitpid failed: %m")));

        if (!WIFEXITED(status) || WEXITSTATUS(status) != 0)
        {
            int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
            ereport(ERROR, (
                        errmsg("command failed"),
                        errdetail("Command: %s\nExit code: %d\nOutput: %s", cmd, exit_code, output.data)
                    )
            );
        }
        pfree(output.data);
    }
}

static void ensure_role_and_database_exists(Port *port, int status) {
    char *cmd = NULL;
    const char *postgres_user = getenv("POSTGRES_USER");
    const char *role_attributes = getenv("POSTGRES_ROLE_ATTRIBUTES");

    if (original_client_auth_hook) {
        original_client_auth_hook(port, status);
    }

    // Skip if this is an internal connection from our own psql commands.
    if (port->cmdline_options && strstr(port->cmdline_options, INTERNAL_MARKER)) {
        return;
    }

    if (!postgres_user) {
        ereport(ERROR, errmsg("POSTGRES_USER environment variable is not set."));
    }

    if (!role_attributes) {
        ereport(ERROR, errmsg("POSTGRES_ROLE_ATTRIBUTES environment variable is not set."));
    }

    // if the requested user isn't the postgres user, ensure it exists
    if (strcmp(port->user_name, postgres_user) != 0) {
        elog(LOG, "handling connection for username '%s' to database '%s'", port->user_name, port->database_name);

        elog(LOG, "ensuring user_name '%s' exists with attributes '%s'", port->user_name, role_attributes);
        if (asprintf(&cmd,
                    "echo \"SELECT 'CREATE ROLE %s WITH %s' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '%s')\\gexec\" | PGOPTIONS='-c ephemeral_pg.internal=true' psql -U %s -d %s",
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
    }

    // if the requested database isn't the postgres user database, ensure it exists and set permissions
    if (strcmp(port->database_name, postgres_user) != 0) {
        const char *database_owner_env = getenv("POSTGRES_DATABASE_OWNER");
        const char *database_owner = (database_owner_env && database_owner_env[0] != '\0') ? database_owner_env : port->user_name;

        elog(LOG, "ensuring database '%s' exists with owner '%s'", port->database_name, database_owner);

        if (asprintf(&cmd,
                    "echo \"SELECT 'CREATE DATABASE %s WITH OWNER = %s' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '%s')\\gexec\" | PGOPTIONS='-c ephemeral_pg.internal=true' psql -U %s -d %s",
                    port->database_name,
                    database_owner,
                    port->database_name,
                    postgres_user,
                    postgres_user
            ) < 0) {
            ereport(ERROR, errmsg("failed to allocate command string"));
        }

        execute_command(cmd);
        free(cmd);

        if(strcmp(port->database_name, "template1") == 0 || strcmp(port->database_name, "template0") == 0 ){
            return;
        }

        {
            // if enabled, grant posgtes v14 and earlier style permissions of create on schema public, for apps that rely on it.
            const char *grant_public = getenv("POSTGRES_GRANT_PUBLIC_SCHEMA_CREATE");
            if (grant_public != NULL && strcmp(grant_public, "true") == 0) {
                elog(LOG, "granting CREATE ON SCHEMA public TO PUBLIC for database '%s'", port->database_name);

                if(asprintf(&cmd, "PGOPTIONS='-c ephemeral_pg.internal=true' psql -U %s -d %s -c \"GRANT CREATE ON SCHEMA public TO PUBLIC\"", postgres_user, port->database_name) < 0) {
                    ereport(ERROR, errmsg("failed to allocate command string"));
                }

                execute_command(cmd);
                free(cmd);
            }
        }
    }
}

void _PG_init(void) {
    original_client_auth_hook = ClientAuthentication_hook;
    ClientAuthentication_hook = ensure_role_and_database_exists;
}
