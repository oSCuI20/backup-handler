#!/bin/bash
#
# Event handler to execute backups for the server
#
_ROOT="$(/bin/dirname $(/bin/readlink -f $0))"
_CURRENT_DATE=$(/bin/date +%Y%m%d)

# default arguments
_CONFIG_DIR="${_ROOT}/config"
_CONFIG_FILE="${_CONFIG_DIR}/backup.conf"
_CONFIG_RCLONE="${_ROOT}/config/rclone.conf"
_SCRIPTS_DIR="${_ROOT}/scripts"
_LOGDIR="${_ROOT}/logs"
_PIDFILE=/var/run/backup-handler.locked

. ${_ROOT}/manager-functions

# default vars
__DEFAULT_DEBUG=false
__DEFAULT_QUIET=false
__DEFAULT_LOGGING=true
__DEFAULT_TMPDIR=/var/tmp/backup

__DEFAULT_RUN_BACKUP=false
__DEFAULT_BACKUP_MODE=${__BACKUP_MODE_COMPLETE:-complete}

__DEFAULT_BACKUP_DIRECTORIES=
__DEFAULT_BACKUP_FILES=

# default rclone backups options
__DEFAULT_RCLONE_REMOTE_BACKUP=
__DEFAULT_RCLONE_EXTRA_OPTIONS=

#__DEFAULT_KEEP_LAST_INCREMENT=
__DEFAULT_KEEP_LAST_DAILY=0      # keep last daily
__DEFAULT_KEEP_LAST_WEEKLY=0     # keep last day of the week
__DEFAULT_KEEP_LAST_MONTHLY=0    # keep last day of the month
__DEFAULT_KEEP_LAST_ANNUALLY=0   # keep last day of the year

# default notifications
__DEFAULT_NOTIFICATIONS_SCRIPTS=(
  ${_ROOT}/notifications/email
  ${_ROOT}/notifications/slack
)
__DEFAULT_NOTIFICATIONS_EMAIL=false
__DEFAULT_NOTIFICATIONS_SLACK=false

# return code for functions
__RETURNCODE_OK=0
__RETURNCODE_NOTHING=1256
__RETURNCODE_SCRIPT_NOTHING=1255
__RETURNCODE_SCRIPT_ERROR_ANY=1254
__RETURNCODE_SCRIPT_VARS_NOT_DEFINED=1253
__RETURNCODE_SCRIPT_CLEAN_OLD_BACKUPS=1252
__RETURNCODE_SSH_FAILED=1251
__RETURNCODE_SSH_FAILED_ARGUMENTS=1250
__RETURNCODE_CHECKING_GLOBAL_VARS=1249
__RETURNCODE_SCRIPT_BACKUP_MODE_NOT_SUPPORT=1248
__RETURNCODE_SCRIPT_RCLONE_LOCALFILE_NOTFOUND=1247
__RETURNCODE_SCRIPT_RCLONE_LOCALDIRECTORY_NOTFOUND=1246

__RESTORE_IFS=$IFS


main() {
  parse_arguments "$@"  #parse arguments and load configs

  __locked

  load_fileconf ${_CONFIG_FILE}

  for script in $(ls ${_SCRIPTS_DIR}); do
    [ ! -f "${_CONFIG_DIR}/${script}.backup.conf" ] && {
      continue
    }

    . ${_CONFIG_DIR}/${script}.backup.conf   # load vars script
    . ${_SCRIPTS_DIR}/${script}              # load script functions, `checking_vars` and `run`

    set_script_vars

    checking_vars || continue
    run

    unset_script_vars "${_CONFIG_DIR}/${script}.backup.conf"
  done
}


load_fileconf() {
  [ ! -f "${1}" ] && {
    __logger ${__ERROR} "Not found configuration file, ${1}\n"
  }

  . $1

  [ -z "${__DEFAULT_RCLONE_REMOTE_BACKUP}" ] && {
    __logger ${__ERROR} "__DEFAULT_RCLONE_REMOTE_BACKUP not define\n"
  }
}  #load_fileconf


print_help() {
  cat << EOF
--quiet|-q         Enable quiet mode, not output in stdout
--script-dir|-s    Set directory for custom scripts, default ${_SCRIPTS_DIR}. The name file is the self of script file name
--log-dir|-l       Set directory for save output in file when debug mode is enable, default ${_LOGDIR}. The name file is the self of script file name
--config-file|-c   Set backup file, default ${_CONFIG_FILE}
--config-rclone|r  Set rclone file configuration, default ${_CONFIG_RCLONE}
--pid-file|-p      Set pidfile file, default ${_PIDFILE}
EOF
}  #print_help


print_usage() {
  cat << EOF
Usage: $0 [--help] [--quiet|-q] [--log-dir|-l /path/to/dir]  [--script-dir|-s /path/to/dir]  [--config-file|-c /path/to/file] [--config-rclone|- /path/to/file]  [--pid-file|-p /path/to/pidfile]
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
      --log-dir|-l)
        _LOGDIR=$(/bin/readlink -f "${value}")
        ;;
      --script-dir|-s)
        _SCRIPTS_DIR=$(/bin/readlink -f "${value}")
        ;;
      --quiet|-q)
        _QUIET=false
        ;;
      --pid-file|-p)
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
    __logger ${__ERROR} "Not found ${_CONFIG_FILE}\n"
  }

  [ ! -f ${_CONFIG_RCLONE} ] && {
    __logger ${__ERROR} "Not found ${_CONFIG_RCLONE}\n"
  }

  [ ! -d ${_SCRIPTS_DIR} ] && {
    __logger ${__ERROR} "Not found ${_SCRIPTS_DIR} directory\n"
  }

  [ ! -d ${_LOGDIR} ] && {
    mkdir -p "${_LOGDIR}"

    __logger ${__WARN} "Not found ${_LOGDIR}, creating logs directory\n"
  }

}  #parse_arguments


main "$@"
