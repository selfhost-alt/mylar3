#!/bin/sh
##
##    Taken entirety from the program that Mylar is based off of - headphones.
##
#
#                                   DO NOT EDIT THIS FILE
#
##
## Edit user configuation in /etc/default/mylar to change
##
## Make sure init script is executable
## sudo chmod +x /opt/mylar/init.ubuntu
##
## Install the init script
## sudo ln -s /opt/mylar/init.ubuntu /etc/init.d/mylar
##
## Create the mylar daemon user:
## sudo adduser --system --no-create-home mylar
##
## Make sure /opt/mylar is owned by the mylar user
## sudo chown mylar:nogroup -R /opt/mylar
##
## Touch the default file to stop the warning message when starting
## sudo touch /etc/default/mylar
##
## To start mylar automatically
## sudo  update-rc.d mylar defaults
##
## To start/stop/restart mylar
## sudo service mylar start
## sudo service mylar stop
## sudo service mylar restart
##
## MYLAR_USER=         #$RUN_AS, username to run mylar under, the default is mylar
## MYLAR_HOME=         #$APP_PATH, the location of mylar.py, the default is /opt/mylar
## MYLAR_DATA=         #$DATA_DIR, the location of mylar.db, cache, logs, the default is /opt/mylar
## MYLAR_PIDFILE=      #$PID_FILE, the location of mylar.pid, the default is /var/run/mylar/mylar.pid
## PYTHON_BIN=         #$DAEMON, the location of the python binary, the default is /usr/bin/python
## MYLAR_OPTS=         #$EXTRA_DAEMON_OPTS, extra cli option for mylar, i.e. " --config=/home/mylar/config.ini"
## SSD_OPTS=           #$EXTRA_SSD_OPTS, extra start-stop-daemon option like " --group=users"
## MYLAR_PORT=         #$PORT_OPTS, hardcoded port for the webserver, overrides value in config.ini
##
## EXAMPLE if want to run as different user
## add MYLAR_USER=username to /etc/default/mylar
## otherwise default mylar is used
#
### BEGIN INIT INFO
# Provides:          mylar
# Required-Start:    $local_fs $network $remote_fs
# Required-Stop:     $local_fs $network $remote_fs
# Should-Start:      $NetworkManager
# Should-Stop:       $NetworkManager
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts instance of mylar
# Description:       starts instance of mylar using start-stop-daemon
### END INIT INFO

# Script name
NAME=mylar

# App name
DESC=mylar

SETTINGS_LOADED=FALSE

. /lib/lsb/init-functions

# Source mylar configuration
if [ -f /etc/default/mylar ]; then
    SETTINGS=/etc/default/mylar
else
    log_warning_msg "/etc/default/mylar not found using default settings.";
fi

check_retval() {
    if [ $? -eq 0 ]; then
        log_end_msg 0
        return 0
    else
        log_end_msg 1
        exit 1
    fi
}

load_settings() {
    if [ $SETTINGS_LOADED != "TRUE" ]; then
        . $SETTINGS

        ## The defaults
        # Run as username
        RUN_AS=${MYLAR_USER-mylar}

        # Path to app MYLAR_HOME=path_to_app_mylar.py
        APP_PATH=${MYLAR_HOME-/opt/mylar}

        # Data directory where mylar.db, cache and logs are stored
        DATA_DIR=${MYLAR_DATA-/opt/mylar}

        # Path to store PID file
        PID_FILE=${MYLAR_PIDFILE-/var/run/mylar/mylar.pid}

        # Path to python bin
        DAEMON=${PYTHON_BIN-/usr/bin/python}

        # Extra daemon option like: MYLAR_OPTS=" --config=/home/mylar/config.ini"
        EXTRA_DAEMON_OPTS=${MYLAR_OPTS-}

        # Extra start-stop-daemon option like START_OPTS=" --group=users"
        EXTRA_SSD_OPTS=${SSD_OPTS-}

        # Hardcoded port to run on, overrides config.ini settings
        [ -n "$MYLAR_PORT" ] && {
            PORT_OPTS=" --port=${MYLAR_PORT} "
        }

        DAEMON_OPTS=" Mylar.py --quiet --daemon --nolaunch --pidfile=${PID_FILE} --datadir=${DATA_DIR} ${PORT_OPTS}${EXTRA_DAEMON_OPTS}"

        SETTINGS_LOADED=TRUE
    fi

    [ -x $DAEMON ] || {
        log_warning_msg "$DESC: Can't execute daemon, aborting. See $DAEMON";
        return 1;}

    return 0
}

load_settings || exit 0

is_running () {
    # returns 1 when running, else 0.
    if [ -e $PID_FILE ]; then
      PID=`cat $PID_FILE`

      RET=$?
      [ $RET -gt 1 ] && exit 1 || return $RET
    else
      return 1
    fi
}

handle_pid () {
    PID_PATH=`dirname $PID_FILE`
    [ -d $PID_PATH ] || mkdir -p $PID_PATH && chown -R $RUN_AS $PID_PATH > /dev/null || {
        log_warning_msg "$DESC: Could not create $PID_FILE, See $SETTINGS, aborting.";
        return 1;}

    if [ -e $PID_FILE ]; then
        PID=`cat $PID_FILE`
        if ! kill -0 $PID > /dev/null 2>&1; then
            log_warning_msg "Removing stale $PID_FILE"
            rm $PID_FILE
        fi
    fi
}

handle_datadir () {
    [ -d $DATA_DIR ] || mkdir -p $DATA_DIR && chown -R $RUN_AS $DATA_DIR > /dev/null || {
        log_warning_msg "$DESC: Could not create $DATA_DIR, See $SETTINGS, aborting.";
        return 1;}
}

handle_updates () {
    chown -R $RUN_AS $APP_PATH > /dev/null || {
        log_warning_msg "$DESC: $APP_PATH not writable by $RUN_AS for web-updates";
        return 0; }
}

start_mylar () {
    handle_pid
    handle_datadir
    handle_updates
    if ! is_running; then
        log_daemon_msg "Starting $DESC"
        start-stop-daemon -o -d $APP_PATH -c $RUN_AS --start $EXTRA_SSD_OPTS --pidfile $PID_FILE --exec $DAEMON -- $DAEMON_OPTS
        check_retval
    else
        log_success_msg "$DESC: already running (pid $PID)"
    fi
}

stop_mylar () {
    if is_running; then
        log_daemon_msg "Stopping $DESC"
        start-stop-daemon -o --stop --pidfile $PID_FILE --retry 15
        check_retval
    else
        log_success_msg "$DESC: not running"
    fi
}

case "$1" in
    start)
        start_mylar
        ;;
    stop)
        stop_mylar
        ;;
    restart|force-reload)
        stop_mylar
        start_mylar
        ;;
    status)
        status_of_proc -p "$PID_FILE" "$DAEMON" "$DESC"
        ;;
    *)
        N=/etc/init.d/$NAME
        echo "Usage: $N {start|stop|restart|force-reload|status}" >&2
        exit 1
        ;;
esac

exit 0