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

# Helpers

# Load config from env file or set defaults
load_config () {
  script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

  if [[ -f ${script_dir}/.env ]]; then
    source ${script_dir}/.env
  fi

  if [[ ! -z ${TRAP+x} ]]; then
    trap "${TRAP}" ERR
  fi

  date=$(date ${DATE_FORMAT:=+%Y%m%d_%H%M})
  backups_route=${BACKUPS_ROUTE:=/opt/backups}
  compression=${COMPRESSION:=1}
}

# Source all "modules" in modules folder
source_modules () {
  for module_file in `ls ${script_dir}/modules`; do
    source ${script_dir}/modules/$module_file
  done
}

# Get an env variable from a container
# Arguments: container name, variable name (without dollar sign)
get_env_from_container () {
  docker exec $1 bash -c 'echo "$'$2'"'
  # Alternative use for a stopped container:
  #docker inspect --format '{{ .Config.Env }}' $1 |  tr ' ' '\n' | grep $2 | sed 's/^.*=//'
}

# Steps to do after the backup has been created.
post_backup () {
  backup_path=$1

  # Compress
  if [[ $compression = 1 ]]; then
    (( $DEBUG )) && echo "-Compressing backup."
    if [[ -d $1 ]]; then
      # Backup is a folder
      tar -czf $1.tar.gz -C $(dirname $1) $(basename $1)
      backup_path=$1.tar.gz
    else
      # Backup is a file
      gzip -f $1
      backup_path=$1.gz
    fi
  fi

  # Change ownership
  if [[ ! -z ${OWNERSHIP+x} ]]; then
    (( $DEBUG )) && echo "-Changing ownership."
    chown -R ${OWNERSHIP} $backup_path
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
