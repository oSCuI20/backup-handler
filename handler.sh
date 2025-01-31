#!/bin/bash
#
# Eduardo Banderas Alba
# Event handler
#
_DEBUG=false
_QUIET=true

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

  ${_RUN_BACKUP_FILES} && {
    . ${_SCRIPTS_DIR}/files

    run
  }

}  #main


load_fileconf() {
  [ ! -f "${1}" ] && {
    __logger ${__ERROR} Not found configuration file, ${1}
  }

  . $1

  _RUN_BACKUP_FILES=${_RUN_BACKUP_FILES:-false }
  _RUN_BACKUP_MYSQL=${_RUN_BACKUP_MYSQL:-false }
  _RUN_BACKUP_POSTGRESQL=${_RUN_BACKUP_POSTGRESQL:-false }
  _RUN_BACKUP_VBOX=${_RUN_BACKUP_VBOX:-false }

  [ -z "${RCLONE_BACKUP_REMOTE}" ] && {
    __logger ${__ERROR} RCLONE_BACKUP_REMOTE not define
  }
}  #load_fileconf


print_help() {
  printf "\
  --debug|-d
\tEnable debug mode
  --quiet|-q
\tEnable quiet mode, not output in stdout
  --logdir| -l
\tSet directory for save output in file when debug mode is enable, default \
${_LOGDIR}. The name file is the self of script file name
  --confdir|-c
\tSet directory as main
  --pidfile|-p
\tSet pidfile
  --only-[script_name]
\tExecute only the script
"
}  #print_help


print_usage() {
  printf "Usage: $0"
  printf "[--debug|-d] [--quiet|-q] "
  printf "[--logdir|-l /path/to/dir] "
  printf "[--confdir|-c /path/to/dir] "
  printf "[--pidfile|-p /path/to/pidfile] \n"
}  #print_usage


parse_arguments() {
  while [ $# -ge 1 ]; do
    key=${1/ /}
    if [ "${key}" != "--debug" ] && [ "${key}" != "-d" ] && \
       [ "${key}" != "--quiet" ] && [ "${key}" != "-q" ] && \
       [ "${key}" != "--help" ] && [ "${key}" != "-h" ] && \
       [ "${key}" != "--pidfile" ] && [ "${key}" != "-p" ] && \
       [[ ! "${key}" =~ --only-.* ]]; then
      shift
      value=$1
    fi

    case $key in
      --config-file|-c)
        _CONFIG_FILE=$(/bin/readlink -f "${value}")
        ;;
      --config-rclone|-c)
        _CONFIG_RCLONE=$(/bin/readlink -f "${value}")
        ;;
      --logdir|-l)
        _LOGDIR=$(/bin/readlink -f "${value}")
        ;;
      --debug|-d)
        _DEBUG=true
        ;;
      --quiet|-q)
        _QUIET=false
        ;;
      --pidfile|-p)
        _PIDFILE=$value
        ;;
      --only-*)
        _EXEC=${key/--only-/}
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
