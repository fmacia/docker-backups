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

post_backup () {
  # Compress
  if [[ $compression = 1 ]]; then
    gzip -f $1
  fi

  # Change ownership
  if [[ ! -z ${OWNERSHIP+x} ]]; then
    if [[ $compression = 1 ]]; then
      chown ${OWNERSHIP} ${1}.gz
    else
      chown ${OWNERSHIP} ${1}
    fi
  fi
}

main () {
  load_config
  source_modules

  # Launch desired modules here
  backup_postgresql
  backup_mysql
}

main
