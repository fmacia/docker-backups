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
    source ${script_dir}/.env
  fi

  if [[ ! -z ${TRAP+x} ]]; then
    trap "${TRAP}" ERR
  fi

  # Defaults
  date=$(date ${DATE_FORMAT:=+%Y%m%d_%H%M})
  backups_route=${BACKUPS_ROUTE:=/opt/backups}
  compression=${COMPRESSION:=1}
  debug=${DEBUG:=0}
}

# Source all "modules" in modules folder
source_modules () {
  for module_file in `ls ${script_dir}/modules`; do
    source ${script_dir}/modules/$module_file
  done
}

# Get an env variable from a container
# Arguments:
# - Container name
# - Variable name (without dollar sign)
get_env_from_container () {
  container=$1
  var_name=$2

  docker exec $container bash -c 'echo "$'$var_name'"'
}

# Steps to do after the backup has been created.
# Arguments:
# - Backup path
post_backup () {
  backup_path=$1

  # Compress
  if [[ $compression = 1 ]]; then
    (( $debug )) && echo "-Compressing backup."
    if [[ -d $1 ]]; then
      # Backup is a folder
      tar -czf $1.tar.gz -C $(dirname $1) $(basename $1)
      backup_path=$1.tar.gz
      rm -rf $1
    else
      # Backup is a file
      gzip -f $1
      backup_path=$1.gz
    fi
  fi

  # Change ownership
  if [[ ! -z ${OWNERSHIP+x} ]]; then
    (( $debug )) && echo "-Changing ownership."
    chown -R ${OWNERSHIP} $backup_path
  fi

  # Remove old backups
  if [[ ! -z ${REMOVE_OLDER+x} ]]; then
    (( $debug )) && echo "-Removing backups older than ${REMOVE_OLDER} days."
    find $(dirname $backup_path) -maxdepth 1 -mindepth 1 -mtime +${REMOVE_OLDER} -exec rm -rf {} \;
  fi
}

main () {
  load_config
  source_modules

  if [ -z ${ACTIVE_MODULES+x} ]; then
    echo "There are no active modules. Please fill at least one in ACTIVE_MODULES var in env file."
    exit 1
  fi

  for module in $ACTIVE_MODULES; do
    $module
  done

  echo "Done."
}

main
