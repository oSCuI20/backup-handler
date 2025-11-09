#!/bin/bash
#
# Event handler to execute backups for the server
#
_ROOT="$(/bin/dirname $(/bin/readlink -f $0))"
_CURRENT_DATE=$(/bin/date +%Y%m%d)
_HOSTNAME="$(/bin/hostname -f)"

# default arguments
_CONFIG_DIR="${_ROOT}/config"
_CONFIG_FILE="${_CONFIG_DIR}/backup.conf"
_CONFIG_RCLONE="${_ROOT}/config/rclone.conf"
_SCRIPTS_DIR="${_ROOT}/scripts"
_NOTIFICATIONS_SCRIPTS_DIR="${_ROOT}/notifications"
_LOGDIR="${_ROOT}/logs"
_LOGFILE=
_PIDFILE=/var/run/backup-handler.locked
_QUIET=false
_DEBUG=false

. ${_ROOT}/manager-functions

# default vars
__DEFAULT_DEBUG=false
__DEFAULT_LOGGING=true
__DEFAULT_TMPDIR=/var/tmp/backup

__DEFAULT_RUN_BACKUP=false
__DEFAULT_RUN_BACKUP_IN=daily # daily, weekly, monthly, annually
__DEFAULT_RUN_BACKUP_IN_DAY=
__DEFAULT_BACKUP_MODE=${__BACKUP_MODE_COMPLETE:-complete}

__DEFAULT_BACKUP_DIRECTORIES=
__DEFAULT_BACKUP_FILES=
__DEFAULT_LOGFILE=

# default rclone backups options
__DEFAULT_RCLONE_REMOTE_BACKUP=
__DEFAULT_RCLONE_EXTRA_OPTIONS=

#__DEFAULT_KEEP_LAST_INCREMENT=
__DEFAULT_KEEP_LAST_DAILY=0      # keep last daily
__DEFAULT_KEEP_LAST_WEEKLY=0     # keep last day of the week
__DEFAULT_KEEP_LAST_MONTHLY=0    # keep last day of the month
__DEFAULT_KEEP_LAST_ANNUALLY=0   # keep last day of the year

# default notifications
### email, slack, telegram
__DEFAULT_NOTIFICATION=

## telegram integration
__DEFAULT_TELEGRAM_API=https://api.telegram.org
__DEFAULT_TELEGRAM_TOKEN=
__DEFAULT_TELEGRAM_CHAT_ID=
__DEFAULT_TELEGRAM_DEBUG=false

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

  msg="start at::$(date '+%Y-%m-%d %H:%M:%S')"
  for script in $(ls ${_SCRIPTS_DIR}); do
    [ ! -f "${_CONFIG_DIR}/${script}.backup.conf" ] && {
      continue
    }

    msg="${msg}\nloading vars and functions for script ${script}"

    _LOGFILE="${_LOGDIR}/${script}.log-${_CURRENT_DATE}"

    . ${_CONFIG_DIR}/${script}.backup.conf   # load vars script
    . ${_SCRIPTS_DIR}/${script}              # load script functions, `checking_vars` and `run`

    set_script_vars

    msg="${msg}\nchecking variables for ${script}"
    checking_vars; local _result_checking_vars=$?
    [ ${_result_checking_vars} -ne ${__RETURNCODE_OK} ] && {
      [ ${_result_run} -eq ${__RETURNCODE_SCRIPT_ERROR_ANY} ] && \
        msg="${msg}\nthe script ${script} has any error, check log, failed!"

      [ ${_result_run} -eq ${__RETURNCODE_SCRIPT_VARS_NOT_DEFINED} ] && \
        msg="${msg}\nscript ${script}, vars undefined"

      [ ${_result_run} -eq ${__RETURNCODE_SCRIPT_BACKUP_MODE_NOT_SUPPORT} ] && \
        msg="${msg}\nbackup mode not support"
    }

    [ ${_result_checking_vars} -eq ${__RETURNCODE_OK} ] && {
      msg="${msg}\nrun script ${script}"
      run; local _result_run=$?

      [ ${_result_run} -eq ${__RETURNCODE_OK} ] && \
        msg="${msg}\nrun ${script} successful!"

      [ ${_result_run} -ne ${__RETURNCODE_OK} ] && {
        [ ${_result_run} -eq ${__RETURNCODE_SCRIPT_NOTHING} ] && \
          msg="${msg}\nskipping backup files for ${_HOSTNAME}"

        [ ${_result_run} -eq ${__RETURNCODE_SCRIPT_ERROR_ANY} ] && \
          msg="${msg}\nthe script ${script} has any error, check log, failed!"

        msg="${msg}\nrun ${script} failed!"
      }
    }

    unset_script_vars "${_CONFIG_DIR}/${script}.backup.conf"
  done

  msg="${msg}\nend at::$(date '+%Y-%m-%d %H:%M:%S')"

  . ${_NOTIFICATIONS_SCRIPTS_DIR}/dummy    # load dummy send_notification function
  [ -n "${__DEFAULT_NOTIFICATION}" ] && \
    . ${_NOTIFICATIONS_SCRIPTS_DIR}/${__DEFAULT_NOTIFICATION}

  send_notification ${msg}
}


load_fileconf() {
  [ ! -f "${1}" ] && {
    __logger --icon=${__ERROR} --msg="Not found configuration file, ${1}\n"
  }

  . $1

  [ -z "${__DEFAULT_RCLONE_REMOTE_BACKUP}" ] && {
    __logger --icon=${__ERROR} --msg="__DEFAULT_RCLONE_REMOTE_BACKUP undefined\n"
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
        _QUIET=true
        ;;
      --debug|-d)
        _DEBUG=true
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
        __logger --icon=${__ERROR} --msg="Not recognized option ${key}"
        print_usage
        print_help
        exit 1
      ;;
    esac
    shift
  done

  [ ! -f ${_CONFIG_FILE} ] && {
    __logger --icon=${__ERROR} --msg="Not found ${_CONFIG_FILE}\n"
  }

  [ ! -f ${_CONFIG_RCLONE} ] && {
    __logger --icon=${__ERROR} --msg="Not found ${_CONFIG_RCLONE}\n"
  }

  [ ! -d ${_SCRIPTS_DIR} ] && {
    __logger --icon=${__ERROR} --msg="Not found ${_SCRIPTS_DIR} directory\n"
  }

  [ ! -d ${_LOGDIR} ] && {
    mkdir -p "${_LOGDIR}"

    __logger --icon=${__WARN} --msg="Not found ${_LOGDIR}, creating logs directory\n"
  }

}  #parse_arguments


main "$@"
