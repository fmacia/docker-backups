#! /usr/bin/env bash
#  ___           ___
# |  _|      _  |_  |
# | |       | |   | |
# | |     __| |   | |
# | |    / _  |   | |
# | |   | (_| |   | |
# | |_   \__,_|  _| |
# |___|         |___|

# @author: fmacia (with help from Stack Overflow, of course)

set -Eeuo pipefail
# Uncomment this to see the commands that are executing.
#set -x

# Load config from env file or set defaults
load_config () {
  script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

  if [[ -f ${script_dir}/.env ]]; then
    source "${script_dir}"/.env
  fi

  if [[ -n ${TRAP:=} ]]; then
    # shellcheck disable=SC2064
    trap "${TRAP}" ERR
  fi

  # Defaults
  date=$(date "${DATE_FORMAT:=+%Y%m%d_%H%M}")
  backups_route=${BACKUPS_ROUTE:=/opt/backups}
  compression=${COMPRESSION:=1}
  verbose=${VERBOSE:=1}
}

# Source all "modules" in modules folder
source_modules () {
  for module_file in "${script_dir}"/modules/*; do
    source "${module_file}"
  done
}

# Get an env variable from a container
# Arguments:
# - Container name
# - Variable name (without dollar sign)
get_env_from_container () {
  container=$1
  var_name=$2

  docker exec "$container" bash -c 'echo "$'"$var_name"'"'
}

# Get the value of a container label
# Arguments:
# - Container name
# - Label name
get_container_label () {
  container=$1
  label=$2

  docker inspect -f "{{ index .Config.Labels \"$label\"}}" "$container"
}

# Prints message only if verbose is active
# Arguments:
# - String to print
echo_verbose () {
  string=$1
  if [ $verbose -ne 1 ]; then
    return
  fi

  echo "$string"
}

# Steps to do after the backup has been created.
# Arguments:
# - Backup path
post_backup () {
  backup_path=$1

  # Compress
  if [[ $compression = 1 ]]; then
    echo_verbose "-Compressing backup."
    if [[ -d $1 ]]; then
      # Backup is a folder
      tar -czf "$1".tar.gz -C "$(dirname "$1")" "$(basename "$1")"
      backup_path="$1".tar.gz
      rm -rf "$1"
    else
      # Backup is a file
      gzip -f "$1"
      backup_path="$1".gz
    fi
  fi

  # Change ownership
  if [[ -n ${OWNERSHIP:=} ]]; then
    echo_verbose "-Changing ownership."
    chown -R ${OWNERSHIP} "$backup_path"
  fi

  # Remove old backups
  if [[ -n ${REMOVE_OLDER:=} ]]; then
    echo_verbose "-Removing backups older than ${REMOVE_OLDER} days."
    find "$(dirname "$backup_path")" -maxdepth 1 -mindepth 1 -mtime +${REMOVE_OLDER} -type f -exec rm -rf {} \;
  fi
}

# Execute all active modules
run_modules () {
  if [[ -z ${ACTIVE_MODULES:=} ]]; then
    echo_verbose "There are no active modules. Please fill at least one in ACTIVE_MODULES var in env file."
    exit 1
  fi

  for module in $ACTIVE_MODULES; do
    type=$module
    containers=$(docker ps --filter="label=com.defcomsoftware.backup.${type}=true" --format "{{.Names}}")
    if [ -z "$containers" ]; then
      echo_verbose "No containers for type ${type}."
    fi

    for container in ${containers}; do
      echo_verbose "Creating ${type} backup for ${container}."

      destination=${backups_route}/$(get_container_label "${container}" "com.defcomsoftware.backup.${type}.destination")
      if [ -z "$destination" ]; then
        echo_verbose "-No destination path defined. Skipping."
        continue
      fi
      mkdir -p "${destination}"

      $module "$container" "$destination"
    done
  done
}

main () {
  load_config
  source_modules
  run_modules

  echo_verbose "Done."
}

main
