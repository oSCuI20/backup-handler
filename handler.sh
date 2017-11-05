#!/bin/bash
#
# Eduardo Banderas Alba
# Event handler
# ./event-handler.sh

export _CONFIGDIR
export _FILECONF
export _SCRIPTDIR
export _ORDER
export _QUIET
export _LOGDIR
export _DEBUG
export _EXEC
export _SCRIPTCONF
export _LOGFILE
export _PIDFILE


main() {
  parse_arguments "$@"

  #Load config file and manager-functions
  . ${_CONFIGDIR}/manager-functions
  load_fileconf "${_FILECONF}"

  _locked  #Lock the script

  if [ "${_EXEC}" == "null" ]; then
    ${BACKUP_FILES} && {
      for s in `/bin/ls -v ${_SCRIPTDIR}/backup_files-* 2> /dev/null`; do
        script=$(/usr/bin/basename ${s})
        disabled=false
        [ "${script: -9}" == ".disabled" ] && disabled=true

        ! ${disabled} && {
          _LOGFILE="${_LOGDIR}/${script}_log"
          [ -f "${_LOGFILE}" ] && /bin/rm -f "${_LOGFILE}"
          read_config "${_SCRIPTCONF}/${script}.conf" && {
            for dir in ${BACKUP_DIR[@]}; do
              run_script ${script} ${dir}
            done
          }
          ${EMAIL} && _send_email "${EMAILADDR}" "${EMAILSUBJECT}" "$_LOGFILE"
          unset_config "${_SCRIPTCONF}/${script}.conf"
        }
      done
    }  #${BACKUP_FILES}

    ${BACKUP_MYSQL} && {
      for s in `/bin/ls -v ${_SCRIPTDIR}/backup_mysql-* 2> /dev/null`; do
        script=$(/usr/bin/basename ${s})
        disabled=false
        [ "${script: -9}" == ".disabled" ] && disabled=true

        ! ${disabled} && {
          _LOGFILE="${_LOGDIR}/${script}_log"
          [ -f "${_LOGFILE}" ] && /bin/rm -f "${_LOGFILE}"
          read_config "${_SCRIPTCONF}/${script}.conf" && {
            for h in ${SSH_HOST[@]}; do
              run_script ${script} ${h}
            done
          }
          ${EMAIL} && _send_email "${EMAILADDR}" "${EMAILSUBJECT}" "$_LOGFILE"
          unset_config "${_SCRIPTCONF}/${script}.conf"
        }
      done
    }  #${BACKUP_MYSQL}

    ${BACKUP_VIRTUALBOX} && {
      for s in `/bin/ls -v ${_SCRIPTDIR}/backup_vbox-* 2> /dev/null`; do
        script=$(/usr/bin/basename ${s})
        disabled=false
        [ "${script: -9}" == ".disabled" ] && disabled=true

        ! ${disabled} && {
          _LOGFILE="${_LOGDIR}/${script}_log"
          [ -f "${_LOGFILE}" ] && /bin/rm -f "${_LOGFILE}"
          read_config "${_SCRIPTCONF}/${script}.conf" && {
            for h in ${SSH_HOST[@]}; do
              run_script ${script} ${h}
            done
          }
          ${EMAIL} && _send_email "${EMAILADDR}" "${EMAILSUBJECT}" "$_LOGFILE"
          unset_config "${_SCRIPTCONF}/${script}.conf"
        }
      done
    }  #${BACKUP_VIRTUALBOX}

    scripts_files=$(/bin/ls -v "${_SCRIPTDIR}")
    for script_name in ${scripts_files}; do
      disabled=false
      if [ "${script_name: -9}" == ".disabled" ] || \
         [[ "${script_name}" =~ backup_(files*|mysql*|vbox*) ]]; then
        disabled=true
      fi

      ! ${disabled} && {
        #Execute custom script
        _LOGFILE="${_LOGDIR}/${script_name}_log"
        script_conf_name="${_SCRIPTCONF}/${script_name}.conf"
        [ -f "${_LOGFILE}" ] && /bin/rm -f "${_LOGFILE}"
        read_config "${script_conf_name}" && {
          run_script "${script_name}"
        }
        ${EMAIL} && _send_email "${EMAILADDR}" "${EMAILSUBJECT}" "$_LOGFILE"
        unset_config "${script_conf_name}"
      } #! $disabled
    done  #for script_name in ${scripts_files}

  else
    _LOGFILE="${_LOGDIR}/${_EXEC}_log"
    script_conf_name="${_SCRIPTCONF}/${_EXEC}.conf"
    [ -f "${_LOGFILE}" ] && /bin/rm -Rf "${_LOGFILE}"
    if read_config "${script_conf_name}"; then
      run_script "${_EXEC}"
    fi
    unset_config "${script_conf_name}"
  fi  #if [ ${_EXEC} = "null" ]

  _clean_all
  /bin/rm -f "${_PIDFILE}"  #unlock script
}  #main


load_fileconf() {
  declare -a require_vars
  require_vars[0]="SERVER"
  require_vars[1]="ARCHIVEROOT"
  require_vars[2]="BACKUP_FILES"
  require_vars[3]="BACKUP_MYSQL"
  require_vars[4]="BACKUP_VIRTUALBOX"
  require_vars[5]="EMAIL"

  if [ ! -f "${1}" ]; then
    log_failure_msg "Not found configuration file, ${1}"
    exit 1
  fi

  for line in `/bin/cat ${1}`; do
    _is_not_comment "${line}" && {
      var=${line//#*/}    #Remove comment in the line
      key=${var%=*}       #Extract var key
      value=${var#*=}     #Extract var value
      export ${key}
    }  #_is_not_comment "${line}"
  done  #for line in `/bin/cat ${_FILECONF}`

  . ${1}
  enviroment=$(env)

  for req in ${require_vars[@]}; do
    if ! printf "${enviroment}" | /bin/grep -q "${req}="; then
      log_failure_msg "Not exists enviroment var ${req}"
      exit 1
    fi  #if ! /bin/printf "${d}" | /bin/grep "${req}"
  done  #for req in ${require_vars[@]}
  log_success_msg "Load ${1} file"
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
      --confdir|-c)
        _CONFIGDIR=$(remove_last_backslash "${value}")
        ;;
      --logdir|-l)
        _LOGDIR=$(remove_last_backslash "${value}")
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
        /usr/bin/printf "Not recognized option ${key}\n"
        print_usage
        print_help
        exit 1
      ;;
    esac
    shift
  done

  [ -z ${_CONFIGDIR} ] && _CONFIGDIR=/root/manager
  [ -z ${_SCRIPTDIR} ] && _SCRIPTDIR="${_CONFIGDIR}/scripts"
  [ -z ${_FILECONF} ] && _FILECONF="${_CONFIGDIR}/manager.conf"
  [ -z ${_LOGDIR} ] && _LOGDIR="${_CONFIGDIR}/log"
  [ -z ${_SCRIPTCONF} ] && _SCRIPTCONF="${_CONFIGDIR}/conf"
  [ -z ${_PIDFILE} ] && _PIDFILE="${_CONFIGDIR}/locked"

  if [ ! -d ${_CONFIGDIR} ]; then
    printf "Not found configdir ${_CONFIGDIR}\n"
    exit 1
  fi

  if [ ! -d ${_SCRIPTDIR} ]; then
    printf "Not found scriptdir ${_SCRIPTDIR}\n"
    exit 1
  fi

  /bin/mkdir -p "${_SCRIPTCONF}"
  /bin/mkdir -p "${_LOGDIR}"
}  #parse_arguments


remove_last_backslash() {
  if [ "${1: -1}" == "/" ]; then
    printf "${1:0:((${#1}-1))}"
  else
    printf "$1"
  fi
}  #remove_last_backslash


main "$@"
