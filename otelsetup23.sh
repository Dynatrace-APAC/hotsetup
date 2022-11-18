#!/bin/bash

# ==================================================
#      ----- Variables Definitions -----           #
# ==================================================
LOGFILE='/tmp/install.log'
touch $LOGFILE
chmod 775 $LOGFILE
pipe_log=true

USER="ubuntu"
NEWUSER="dynatrace"
NEWPWD="dynatrace"

if [ "$pipe_log" = true ]; then
  echo "Piping all output to logfile $LOGFILE"
  exec 3>&1 4>&2
  trap 'exec 2>&4 1>&3' 0 1 2 3
  # Redirect stdout to file log.out then redirect stderr to stdout
  exec 1>$LOGFILE 2>&1
else
  echo "Not piping stdout stderr to the logfile, writing the installation to the console"
fi

echo "whoami"
echo $(whoami)
echo "uservar"
echo $USER
echo "newuservar"
echo $NEWUSER
echo "newpwd"
echo $NEWPWD
