#!/bin/bash
#
# Event handler to execute backups for the server
#

__RETURNCODE_OK=0
__RETURNCODE_NOTHING=1256
__RETURNCODE_SCRIPT_NOTHING=1255
__RETURNCODE_SCRIPT_ERROR_ANY=1254
__RETURNCODE_SCRIPT_VARS_NOT_DEFINED=1253
__RETURNCODE_SCRIPT_CLEAN_OLD_BACKUPS=1252
__RETURNCODE_SSH_FAILED=1251
__RETURNCODE_SSH_FAILED_ARGUMENTS=1250

_RUN_BACKUP_RCLONE=false
_RUN_BACKUP_MYSQL=false
_RUN_BACKUP_POSTGRESQL=false
_RUN_BACKUP_VBOX=false

_NOW_DATE=$(/bin/date +%Y%m%d)

_DEBUG=false
_QUIET=true
_LOGGING=true

_ROOT="$(/bin/dirname $(/bin/readlink -f $0))"
_CONFIG_FILE="${_ROOT}/config/backup.conf"
_CONFIG_RCLONE="${_ROOT}/config/rclone.conf"

_SCRIPTS_DIR="${_ROOT}/scripts"
_LOGDIR="${_ROOT}/logs"

_PIDFILE=/var/run/hanled-backup.locked
_EXEC="null"

. ${_ROOT}/manager-functions


main() {
  parse_arguments "$@"  #parse arguments and load configs

  load_fileconf ${_CONFIG_FILE}

  for script in $(ls ${_SCRIPTS_DIR}); do

    . ${_SCRIPTS_DIR}/${script}

    run

    # ${_RUN_BACKUP_MYSQL} && {
    #   checking_vars
    #   [ $? -ne ${__RETURNCODE_OK} ] && continue

    #   run
    # }

      # ${_RUN_BACKUP_POSTGRESQL} && {
      # }

      # ${_RUN_BACKUP_VBOX} && {
      # }

  done

}  #main


load_fileconf() {
  [ ! -f "${1}" ] && {
    __logger ${__ERROR} Not found configuration file, ${1}
  }

  . $1

  [ -z "${RCLONE_BACKUP_REMOTE}" ] && {
    __logger ${__ERROR} RCLONE_BACKUP_REMOTE not define
  }
}  #load_fileconf


print_help() {
  cat << EOF
--quiet|-q \tEnable quiet mode, not output in stdout
--logdir| -l \tSet directory for save output in file when debug mode is enable, default ${_LOGDIR}. The name file is the self of script file name
--config-file|-c \tSet backup file, default ${_CONFIG_FILE}
--config-rclone|r \tSet rclone file configuration, default ${_CONFIG_RCLONE}
--pidfile|-p \tSet pidfile file, default ${_PIDFILE}
EOF
}  #print_help


print_usage() {
  cat << EOF
Usage: $0 [--help] [--quiet|-q] [--logdir|-l /path/to/dir]  [--config-file|-c /path/to/file] [--config-rclone|- /path/to/file]  [--pidfile|-p /path/to/pidfile]
EOF
}  #print_usage


parse_arguments() {
  while [ $# -ge 1 ]; do
    key=${1/ /}
    if [ "${key}" != "--quiet" ] && [ "${key}" != "-q" ] && \
       [ "${key}" != "--help" ] && [ "${key}" != "-h" ] && \
       [ "${key}" != "--pidfile" ] && [ "${key}" != "-p" ]; then
      shift
      value=$1
    fi

    case $key in
      --config-file|-c)
        _CONFIG_FILE=$(/bin/readlink -f "${value}")
        ;;
      --config-rclone|-r)
        _CONFIG_RCLONE=$(/bin/readlink -f "${value}")
        ;;
      --logdir|-l)
        _LOGDIR=$(/bin/readlink -f "${value}")
        ;;
      --quiet|-q)
        _QUIET=false
        ;;
      --pidfile|-p)
        _PIDFILE=$value
        ;;
      --help)
        print_usage
        print_help
        exit 0
        ;;
      *)
        __logger ${__ERROR} Not recognized option ${key}
        print_usage
        print_help
        exit 1
      ;;
    esac
    shift
  done

  [ ! -f ${_CONFIG_FILE} ] && {
    __logger ${__ERROR} Not found ${_CONFIG_FILE}
  }

  [ ! -f ${_CONFIG_RCLONE} ] && {
    __logger ${__ERROR} Not found ${_CONFIG_RCLONE}
  }

  [ ! -d ${_LOGDIR} ] && {
    __logger ${__WARN} Not found ${_LOGDIR}, creating logs directory

    mkdir -p "${_LOGDIR}"
  }

}  #parse_arguments


main "$@"
