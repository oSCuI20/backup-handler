# backup-handler

Backup Handler is a tool for backup files, mysql databases and VirtualBox environment.
* Backup files use rsync tool.
* Backup mysql database use mysqldump over ssh in `server` mode. In `client` mode dump of database and copy with scp to backup server.
* Backup VirtualBox use tar and ssh. The VM should be halt.
It's possible add custom script into ./scripts directory.

Usage:
  ./handler.sh [--confdir <directory> --logdir <directory> --debug --quiet --pidfile <path/to/pidfile> --only-<script_name>]

  * --debug options not implement

Configure the environment:
You can configure the environment in `server` mode or `client` mode

  Main configuration file is ./manager.conf
    SERVER=false            #Set true if you execute the scripts in backup server or false if is a client

    BACKUP_MYSQL=false         #Set true or false
    BACKUP_FILES=false         #Set true or false
    BACKUP_VIRTUALBOX=false    #Set true or false

    EMAIL=true                 #Set true if you want receive email
    EMAILADDR=                 #Set email address
    EMAILSUBJECT=""

    ARCHIVEROOT=/backups

    _CONFIGDIR=                #Set root config directory, default /root/manager
    _SCRIPTDIR=                #Set root scripts directory, default _CONFIGDIR/scripts
    _QUIET=true                #Show messages in stdout
    _LOGDIR=                   #Set log directory, default _CONFIGDIR/log
    _DEBUG=false               #DEBUG not implement
    _SCRIPTCONF=               #Set root scripts config directory, default _CONFIGDIR/conf
                               #handler.sh search fileconf with the same name of script
                               #Example: script1, fileconf should be fileconf.conf
    _PIDFILE=                  #Save process id in the file, default _CONFIGDIR/locked
