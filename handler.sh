#!/bin/bash
#
# Eduardo Banderas Alba
# Event handler

export _CONFIGDIR=/root/manager
export _PIDFILE=/var/run/handler.locked

_FILECONF=${_CONFIGDIR}/manager.conf
_EXEC="null"


main() {
  #Load config file and manager-functions
  load_fileconf "${_FILECONF}"
  parse_arguments "$@"
  . ${_CONFIGDIR}/manager-functions
  _locked  #Lock the script

  for s in `/bin/ls -v ${_SCRIPTCONF}/* 2> /dev/null`; do
    cnf=$(/usr/bin/basename ${s})
    disabled=false
    [ "${cnf: -9}" == ".disabled" ] && disabled=true

    ! ${disabled} && {
      export _LOGFILE="${_LOGDIR}/${cnf}.log"
      /bin/rm -f ${_LOGFILE}
      read_config "${_SCRIPTCONF}/$cnf" && {
        run_script "${_SCRIPTDIR}/files"
        ret_files=$?

        run_script "${_SCRIPTDIR}/mysql"
        ret_mysql=$?

        run_script "${_SCRIPTDIR}/vbox"
        ret_vbox=$?

        ${EMAIL} && {
          subject="Check email - ${EMAILSUBJECT}"

          if [ ${ret_files} -eq 0 ] && [ ${ret_mysql} -eq 0 ] && \
             [ ${ret_vbox} -eq 0 ]; then
            subject="Success - ${EMAILSUBJECT}"
          fi

          if [ ${ret_files} -eq 256 ] || [ ${ret_mysql} -eq 256 ] || \
             [ ${ret_vbox} -eq 256 ]; then
            subject="Success - ${EMAILSUBJECT}"
          fi

          if ([ ${ret_files} -gt 0 ] && [ ${ret_files} -lt 256 ]) || \
             ([ ${ret_mysql} -gt 0 ] && [ ${ret_mysql} -lt 256 ]) || \
             ([ ${ret_vbox} -gt 0 ] && [ ${ret_vbox} -lt 256 ]); then
            subject="Failed - ${EMAILSUBJECT}"
          fi

          _send_email "${EMAILADDR}" "${subject}" "$_LOGFILE"
        }  #${EMAIL}
      }  #read_config "${_SCRIPTCONF}/$cnf"
    }  #! ${disabled}
  done # for s in `/bin/ls -v ${_SCRIPTCONF}/* 2> /dev/null`

  /bin/rm -f "${_PIDFILE}"  #unlock script
}  #main


load_fileconf() {
  declare -a require_vars
  require_vars[0]="SERVER"
  #require_vars[1]="ARCHIVEROOT"

  if [ ! -f "${1}" ]; then
    printf "Not found configuration file, ${1}"
    exit 1
  fi

  for line in `/bin/cat ${1}`; do
    var=${line//#*/}    #Remove comment in the line
    key=${var%=*}       #Extract var key
    value=${var#*=}     #Extract var value

    if [ "${value}" != "" ]; then
      export ${key}=${value}
    else
      export ${key}
    fi
  done  #for line in `/bin/cat ${_FILECONF}`

  enviroment=$(env)

  for req in ${require_vars[@]}; do
    if ! printf "${enviroment}" | /bin/grep -q "${req}="; then
      printf "Not exists enviroment var ${req}\n"
      exit 1
    fi  #if ! /bin/printf "${d}" | /bin/grep "${req}"
  done  #for req in ${require_vars[@]}
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
        _CONFIGDIR=$(/bin/readlink -f "${value}")
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
        /usr/bin/printf "Not recognized option ${key}\n"
        print_usage
        print_help
        exit 1
      ;;
    esac
    shift
  done

  if [ ! -d ${_CONFIGDIR} ]; then
    printf "Not found configdir ${_CONFIGDIR}\n"
    exit 1
  fi

  export _SCRIPTDIR=${_CONFIGDIR}/scripts
  export _LOGDIR=${_CONFIGDIR}/logs
  export _SCRIPTCONF=${_CONFIGDIR}/config

  if [ ! -d ${_SCRIPTDIR} ]; then
    printf "Not found scriptdir ${_SCRIPTDIR}\n"
    exit 1
  fi

  /bin/mkdir -p "${_LOGDIR}"
}  #parse_arguments


main "$@"

