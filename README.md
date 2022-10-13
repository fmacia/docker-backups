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
    - _String, required, default: +%Y%m%d\_%H%M_
  - **BACKUPS_ROUTE:** Local folder (in host machine) where the backups will be saved. By default, "/opt/backups". Every backup from the same container will be saved in a subfolder (configured in container labels, detailed below)
    - _String, required, default: /opt/backups_
  - **COMPRESSION:** Backups will be compressed in gzip format if value is 1
    - _Integer, optional, default: 1_
  - **ACTIVE_MODULES:** The modules that will be used (currently the name of the function within the module). For example, only files would be: `ACTIVE_MODULES="files"`
    - _String, required, default: (All modules)_
  - **DEBUG:** If set to 1, the script will print more information on screen
    - _Integer, optional, default: 0_
  - **TRAP:** Command to execute if there is an error executing the backups. Useful for notifications via email, etc.
    - _String, optional, default: null_
  - **OWNERSHIP:** (Optional) User and group to set as author of the backup files (user:group. Example: root:root)
    - _String, optional, default: null_
    - Note: changing ownership can only be done if the script is run as root
  - **REMOVE_OLDER:** Makes the script remove backups older than the specified value (in days)
    - _Integer, optional, default: null_
    - Note: this will only remove older backups for the active modules with running containers only
  - **VERBOSE:** Controls if the script must output status messages as it runs
    - _Integer, optional, default: 1_

## Container labels

The script works by querying current running containers for specific labels:

- **com.defcomsoftware.backup.[type]=true:** The type of backup to create. Currently, the script supports:
  - "mysql" (for MariaDB or MySQL)
  - "postgresql" (for PostgreSQL)
  - "files" (for files)
  - "drush" (for Drush)
- **com.defcomsoftware.backup.[type].destination:** The path on the host where the backups of this container will be placed (relative to the BACKUPS_ROUTE parameter)
- **com.defcomsoftware.backup.files.source:** (Only used for type "files") The folder to copy from the container
- **com.defcomsoftware.backup.drush.path:** (Only used for type "drush") The drush executable path

A new label will be added in the near future to allow to set the backup name instead of directly using the container name.

Example:

```
...
labels:
  - com.defcomsoftware.backup.type=postgresql
  - com.defcomsoftware.backup.destination=path_of_folder_where_backups_will_be_placed
```

## Container env variables

The script reuses the env variables of the container to know things like the database name.

### For MySQL:

- MYSQL_USER: The database user
- MYSQL_DATABASE: The database name

Additionally, some method to prevent mysql from asking the password is needed. For example, putting the credentials in the my.cnf file, using mysql_config_editor or the MYSQL_PWD environment variable.

### For PostgreSQL:

- POSTGRES_DB: The database name
- POSTGRES_USER: The postgres user (defaults to "postgres" if not set)

Note: The script assumes the container runs with the default user (postgres)

## Requirements

### Drush

The Drush module requires `mysqldump` command inside the container and the drush file specified in `drush_path` to be executable.

## "Modules"

The script allows to choose the types of backups to run.

- **To select the modules to run:** Edit the `ACTIVE_MODULES` variable in the env file. The elements must be the name of the module (example: _files_)
- **To add a new module:** Duplicate one of the current modules (under the "modules" subfolder) and edit the name of the function (make sure the name matches the name of the file), the "type" variable (it's the one that is used to find the containers) and the content of the for loop to fit your use case. Then, add the module to the `ACTIVE_MODULES` variable in .env file.
