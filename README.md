# Docker backup creator

Simple bash script to generate backups from containers I use for myself.

It reuses the database container by reading info from labels and env variables. The backups are named "[CONTAINER_NAME]_[DATE].sql" (plus ".gz" at the end if compressed).

The script can create backups for PostgreSQL and MySQL/MariaDB databases, as well as files.

**Note:** The script has been tested with the following docker images: [Postgres](https://hub.docker.com/_/postgres/), [MariaDB](https://hub.docker.com/_/mariadb) and [Drupal](https://hub.docker.com/_/drupal)

## How to use

1. Clone repository or download files
2. Copy ".env.example" to ".env" and adjust configuration variables (detailed below)
3. Add labels to the database containers to backup (detailed below). The container must be recreated afterwards (`docker-compose up -d`)
4. Give execution permission to "create_backups.sh" (or run it with `bash -c [NAME]`)
5. Execute "create_backups.sh" or insert it in cron

## Script configuration

The following parameters may be configured changing the values in .env file:
  - **DATE_FORMAT:** Date that is appended to every backup file. By default, Year-month-day_hour-minute (without hyphens)
  - **BACKUPS_ROUTE:** Local folder (in host machine) where the backups will be saved. By default, "/opt/backups". Every backup from the same container will be saved in a subfolder (configured in container labels, detailed below)
  - **COMPRESSION:** Backups will be compressed in gzip format if value is 1
  - **ACTIVE_MODULES:** The modules that will be used (currently the name of the function within the module). For example, only files would be: `ACTIVE_MODULES="backup_files"`
  - **DEBUG:** If set to 1, the script will print more information on screen
  - **TRAP:** (Optional) Command to execute if there is an error executing the backups. Useful for notifications via email, etc.
  - **OWNERSHIP:** (Optional) User and group to set as author of the backup files (user:group. Example: root:root)
    - Note: changing ownership can only be done if the script is run as root
  - **REMOVE_OLDER:** _(Optional) Integer, default: null._ Makes the script remove backups older than the specified value (in days)
    - Note: this will only remove older backups for the active modules with running containers only

## Container labels

The script works by querying current running containers for specific labels:

- **defcomsoftware.backup.type:** The type of backup to create. Currently, the script supports:
  - "mysql" (for MariaDB or MySQL)
  - "postgresql" (for PostgreSQL)
  - "files" (for files)
- **defcomsoftware.backup.folder:** The path on the host where the backups of this container will be placed
- **defcomsoftware.backup.source:** (Only used for type "files") The folder to copy from the container

A new label will be added in the near future to allow to set the backup name instead of directly using the container name.

Example:

```
...
labels:
  - defcomsoftware.backup.type=postgresql
  - defcomsoftware.backup.folder=name_of_folder_where_backups_will_be_placed
```

## Container env variables

The script reuses the env variables of the container to know things like the database name.

### For MySQL:

- MYSQL_USER: The database user
- MYSQL_DATABASE: The database name
- MYSQL_PWD: The database password. This env variable is not needed by the container image, but is needed by the script, as it allows mysql connections from cli without asking the password

### For PostgreSQL:

- POSTGRES_DB: The database name

Note: The script assumes the container runs with the default user (postgres)

## "Modules"

The script allows to choose the types of backups to run.

- **To select the modules to run:** Edit the `ACTIVE_MODULES` variable in the env file. The elements must be the name of the function inside the module
- **To add a new module:** Duplicate one of the current modules (under the "modules" subfolder) and edit the name of the funcion, the "type" variable (it's the one that is used to find the containers) and the content of the for loop to fit your use case. Then, add the module to the `ACTIVE_MODULES` variable
