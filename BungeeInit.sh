#!/bin/sh

### BEGIN INIT INFO
# Provides:   bungeecordinit
# Required-Start: $local_fs $remote_fs
# Required-Stop:  $local_fs $remote_fs
# Should-Start:   $network
# Should-Stop:    $network
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:    BungeeCord Server Wrapper
# Description:    Starts the BungeeCord Server
### END INIT INFO


# Global Variables
#
# - Keep GLOBAL variables uppercase
#

SERVERUSER="minecraft"
SCREENNAME="BungeeCord"
INVOCATION="java -Xmx256M -jar BungeeCord.jar --log-strip-color"
SERVERIP="192.168.3.195"
SERVERPORT="25560"
SERVERPATH="/home/minecraft/bukkit/BungeeCord"
LOGPATH="proxy.log.0"
UPDATEPATH="http://ci.md-5.net/job/Spigot/rssAll"
WARNINGTIME="5"

# Turn Debug Mode "ON/OFF"
DEBUG="OFF"


# Utility Scripts
#
# - Keep utilityScripts camelCased with the first word lowercase
#


# Get the PID of a screen session
getScreenPID() {
  pgrep -f "$SCREENNAME $INVOCATION"
}

# Simple check to see if the server is running
serverIsRunning() {
  if $(getScreenPID) > /dev/null
  then
    return 0
  else
    return 1
  fi
}

# Determine if the screen session is attached or not
# ***** BUG *****
# Need to get LAST argument, not $5
getLastArg() {
  for last
    do
      true
    done
  echo $last
}
getScreenState() {
  screenID="$(getScreenPID).$SCREENNAME"
  asUser "screen -ls | grep "$screenID" | awk '{print \$5}'"
#  local screenLine="$(asUser 'screen -ls | grep \$screenID')"
#  eval last=\${$#}
#  echo "$last"
  
}
# Get the PID of the server process based on the PID of the screen session
getServerPID() {
  screenPID="$(getScreenPID)"
  if [ -z "$screenPID" ] ; then
    echo ""
  else
   pgrep -P "$(getScreenPID)"
 fi
}

# Get the PID of the process running on $SERVERPORT
getNetworkPID() {
#  netstat -ant --all --program | grep $SERVERPORT | awk '{print $7}' | awk 'BEGIN { FS = "/" } ; { print $1 }'
  fuser "$SERVERPORT/tcp" 2>/dev/null | awk 'BEGIN { FS = " " } ; { print $1 }'
}

# Gets the command line of the process running on $SERVERPORT
getNetworkCmdline() {
  pid=$(getNetworkPID)
  pgrep -lf [a-zA-Z] | grep "$pid" | sed -n "s/"$pid" //p" | grep -v sed
#  pgrep -lf $SCREENNAME | grep -v SCREEN | sed -n "s/$pid //p"
}

# Simple "open" "closed" check on the $serverPort. Should only return "open" after the server started.
# ***** BUG *****
# Need to get LAST argument, not $5
portCheck() {
  nc -vz $SERVERIP $SERVERPORT 2>&1 | grep $SERVERPORT | awk '{print $5}'
}

# Returns a list of links. Will need to filter the results to get latest file.
downloadUpdate() {
  wget -q -O- "http://ci.md-5.net/job/Spigot/rssAll" | grep -o '<link type="text/html" href="[^"]*' | grep -o '[^"]*$'
}

# Warning messages. Sends time out messages to server for shutdowns and restarts.
sendWarning() {
  echo "Server $(shutdownType) in $WARNINGTIME!"
}

# Executes the command $1 as user $SERVERUSER
asUser() {
#  command="$1"
  local user="$(whoami)"
  if [ "$DEBUG" = "ON" ] ; then
    echo "\$user: $user"
    echo "\$SERVERUSER: $SERVERUSER"
    echo "Command sent asUser: $1"
  fi
  if [ "$user" = "$SERVERUSER" ]; then
    bash -c "$1"
  else
    if [ "$user" = "root" ]; then
      if [ "$DEBUG" = "ON" ] ; then
        echo "Switching users: su -l $SERVERUSER -s /bin/bash -c \"$1\""
      fi
      su -l "$SERVERUSER" -s /bin/bash -c "$1"
    else
      if [ "$SERVERUSER" = "root" ]; then
        echo "This command must be executed as the user \"$SERVERUSER\"."
      else
        echo "This command must be executed as the user \"$SERVERUSER\" or \"root\"."
      fi
    fi
  fi
}

# Send a command to the server.
sendCommand() {
  local screenID="$(getScreenPID).$SCREENNAME"
  if [ "$DEBUG" = "ON" ] ; then
    echo "\$screenID: '$screenID'"
  fi
  asUser "screen -p 0 -S "$screenID" -X eval 'stuff \"$*\"\\015'"
}

testArgs() {
  echo "$*"
  echo "$0"
  echo "$1"
  echo "$2"
  echo "$3"
  for arg in "$@" ; do
    echo "$arg"
    echo ""
  done
#  echo "$*"
}



# Main Functions
#
# - Keep main_functions lowercased and with underscores
#

bungee_start() {
  local pid="$(getServerPID)"
  listening="$(portCheck)"
  if [ -z "$pid" ] && [ "$(portCheck)" = ":" ] ; then
    asUser "cd \"$SERVERPATH\" && screen -dmS $SCREENNAME $INVOCATION"
    echo "----------------------------------------" ;
    echo "Starting $SCREENNAME server..." ;
    echo "----------------------------------------" ;
    echo "The process ID is $(getServerPID)" ;
    echo "----------------------------------------" ;
    sleep 1 ;
    local listening="$(portCheck)"
    echo "Port: $SERVERPORT is $listening"
    echo "----------------------------------------" ;
  else
      bungee_status
  fi
}

bungee_status() {
  local pid="$(getServerPID)"
  listening="$(portCheck)"
  echo "----------------------------------------" ;
  echo "----------------------------------------" ;
  echo "" ;
  if [ -n "$pid" ] ; then
    echo "The $SCREENNAME server is already running" ;
    if [ "$listening" = "open" ] ; then
      echo "Port $SERVERPORT is $listening"
    elif [ "$listening" = ":" ] ; then
      echo "Port $SERVERPORT is closed"
    else
      echo "Something is wrong with syntax"
    fi
    echo "" ;
    echo "----------------------------------------" ;
    echo "The process ID is $pid"
    echo "" ;
    echo "----------------------------------------" ;
    if [ $(whoami) = "$SERVERUSER" ] || [ $(whoami) = "root" ] ; then
      echo "The screen session is currently $(getScreenState)"
    fi
    echo "Reconnect with:"
    local screenID="$(getScreenPID).$SCREENNAME"
    echo "screen -dr $screenID"
  elif [ -z "$pid" ] ; then
    echo "The $SCREENNAME server is not running" ;
    if [ "$listening" = "open" ] ; then
      echo "Port $SERVERPORT is currently in use!"
      echo "Process ID: $(getNetworkPID)"
      echo "Command Line: $(getNetworkCmdline)"
    elif [ "$listening" = ":" ] ; then
      echo "Port $SERVERPORT is available for $SCREENNAME"
    else
      echo "Something is wrong with syntax"
    fi
  else
      echo "Something went wrong!"
  fi
  echo "" ;
  echo "----------------------------------------" ;
  echo "----------------------------------------" ;
}

# Checks if the server is running and if it is, connect and send the end command
# then wait for the confirmation message before sending confirmation to user.
bungee_stop() {
  local pid="$(getServerPID)"
  if [ "$DEBUG" = "ON" ] ; then
    echo "ServerPID: $pid"
    echo "Arguments passed: $1"
  fi
  if [ -n "$pid" ] ; then
    sendCommand "end" ;
    echo -n "Stoping $SCREENNAME Server..." ;
    # Wait for process to end
    while [ "$(getServerPID)" = "$pid" ] ; do
      echo -n "." ;
      sleep 0.5 ;
    done
    echo "$SCREENNAME server stopped."
  else
    echo "The $SCREENNAME server is not running."
  fi
}


# Watch the server console
bungee_cmdlog() {
  local pid="$(getServerPID)"
  if [ -n "$pid" ] && [ "$(portCheck)" = "open" ] ; then
    if [ $(whoami) = "$SERVERUSER" ] || [ $(whoami) = "root" ] ; then
      serverLogPath="$SERVERPATH/$LOGPATH"
      echo "Now watching logs (press Ctrl+C to exit):"
      echo "..."
      asUser "tail --pid=$$ --follow --lines=5 --sleep-interval=0.1 $serverLogPath"
    fi
  else
    bungee_status
  fi
}


# Main script input
#
# - Command line arguments for the bungeecord script
#

case "$1" in
  start)
    bungee_start
    ;;
  stop)
    bungee_stop
    ;;
  restart)
    bungee_stop
    bungee_start
    ;;
#  update)
#    bungee_stop
#    bungee_update
#    bungee_start
#    ;;
  status)
    bungee_status
    ;;
  command)
    if [ "$1" = 'end' ]; then
      bungee_stop
    elif [ $# -gt 1 ]; then
      shift
      sendCommand "$@"
    else
      echo "Usage: $0 $1 <string: commands arguments>"
    fi
    ;;
  cmdlog)
    bungee_cmdlog
    ;;
  *)
  echo "Usage: $0 {start|stop|restart|status|command \"server command\"}"
  exit 1
  ;;
esac

exit 0

[[Category:Guides]]
