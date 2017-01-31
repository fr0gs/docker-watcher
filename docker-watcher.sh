#!/bin/bash
# It is important to note that if any of the structure of the docker inspect output changes, this
# script will need to be adapted.
# Also, it will need to be changed if the prefix name for each network interface that a docker container
# creates is modified.

CONTAINERS=()
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color


# Ask for sudo permissions to execute (needed for tcpdump)
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"


# Check the number of arguments.
if [ "$#" -ne 4 ]; then
    echo "usage: ./docker-watcher.sh -d|--discovery <discovery_period> -t|--timeperiod <period>"
    exit 1
fi


# Loop through arguments and assign variables.
while [ "$#" -gt 1 ];
  do
  key="$1"

  case $key in
      -d|--discovery)
      DISCOVERY_PERIOD="$2" # Time in seconds for the script to wait before looking for new containers
      shift
      ;;

      -t|--timeperiod)
      TIME_PERIOD="$2" # Time in seconds for each logging process to start rotating logs. (i.e. 1 pcap/each 10 seconds)
      shift
      ;;
      --default)
      DEFAULT=YES
      ;;
    *)
    ;;
  esac
  shift
done


# Remove all tcpdump logging processes. There is no need of looking for tcpdump as
# there will be the only child processes this script will fork.
function cleanup {
  echo "docker-watcher: cleaning up logging processes"
  kill -2 $(jobs -p | awk 'NR>0 { print $1 }') 2>/dev/null
  exit 0
}


# Search a string in an array. The search string is the first argument and the rest are the array elements:
containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# Call the cleanup function when the script is stopped via any of those two signals
# C-c == SIGINT.
trap cleanup SIGINT SIGKILL

# Gather information about each running docker container and start logging network traffic.
while :
do
  sleep $DISCOVERY_PERIOD
  for container in `docker ps | awk 'NR>1{ print $1 }'`; do
    sleep 1
    networkmode=$(docker inspect -f '{{ .HostConfig.NetworkMode }}' $container)
    networkid=$(docker inspect -f "{{ .NetworkSettings.Networks.${networkmode}.NetworkID }}" $container)
  	for i in `netstat -i | grep br | awk '{ print $1 }'`; do
      if [[ "$networkid" == *$(echo $i | awk -F'-' '{ print $2 }')* ]]; then
        containsElement $i "${CONTAINERS[@]}"
        if [ $? != 0 ]; then
          cname=$(docker inspect -f '{{ .Name }}' ${container} | sed "s/\\///g")
          echo -e "${RED}[+] ${GREEN}Container ${cname} using network interface: ${i} not being observed, adding it.${NC}"
          CONTAINERS+=($i)
          ./write-pcap-file.sh -c $cname -i $i -t $TIME_PERIOD &
        fi
      fi
  	done
  done
done
