#!/bin/bash
# It is important to note that if any of the structure of the docker inspect output changes, this
# script will need to be adapted.
# Also, it will need to be changed if the prefix name for each network interface that a docker container
# creates is modified.

red='\033[1;31m'
green='\033[1;32m'
nc='\033[0m' # No Color
containers=() # Containers already observed
interfaces=() # Interfaces already observed
base_dir=$PWD"/pcap/"
time_period=5
discovery_period=10
rotate_logs="no"

# Ask for sudo permissions to execute (needed for tcpdump)
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"


if [ ! -f /usr/sbin/tcpdump ]; then
    echo "error: tcpdump not installed, please install it"
    exit -1
fi


if [ "$#" -lt 4 ]; then
    echo "usage: ./docker-watcher.sh -r|--rotate <yes/no> (default: no) -t|--timeperiod <period> (default: 5) -d|--discovery <discovery_period> (default: 10)"
    exit 1
fi


while [ "$#" -gt 1 ];
  do
  key="$1"

  case $key in
      -d|--discovery)
      discovery_period="$2" # Time in seconds for the script to wait before looking for new containers
      shift
      ;;

      -t|--timeperiod)
      time_period="$2" # Time in seconds for each logging process to start rotating logs. (i.e. 1 pcap/each 10 seconds)
      shift
      ;;

      -r|--rotate)
      rotate_logs="$2" # Whether or not rotate logs.
      shift
      ;;

      --default)
      default=YES
      ;;
    *)
    ;;
  esac
  shift
done


function cleanup {
  echo "docker-watcher: cleaning up logging processes"
  kill -2 $(jobs -p | awk 'NR>0 { print $1 }') 2>/dev/null
  exit 0
}


# Search a string in an array. The search string is the first argument and the rest are the array elements:
function containsElement {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# Call the cleanup function when the script is stopped via any of those two signals
# C-c == SIGINT.
trap cleanup SIGINT SIGKILL


function analyzeTraffic {
  # container, interface, base_dir, time_period, rotate_logs, container_ip
  local cont="$1"
  local iface="$2"
  local bdir="$3"
  local tperiod="$4"
  local rlogs="$5"
  local cip="$6"

  # echo "cont: $cont"
  # echo "iface: $iface"
  # echo "bdir: $bdir"
  # echo "tperiod: $tperiod"
  # echo "rlogs: $rlogs"
  # echo "cip: $cip"
  # echo "++++++++++++++++++++++++"

  # Start watching for all traffic on the interface as well.
  containsElement $iface "${interfaces[@]}"
  if [ $? != 0 ]; then
    echo -e "${red}[+] ${green}Network interface: ${iface} not being observed, adding it.${nc}"
    interfaces+=($iface)
    tcpdump -s 0 -i $iface -w $bdir$iface"/"$iface"_"$(date +'%Y-%m-%d_%H:%M:%S')".pcap" 2>/dev/null &
  fi


  containsElement $container "${containers[@]}"

  if [ $? != 0 ]; then
    cname=$(docker inspect -f '{{ .Name }}' ${cont} | sed "s/\\///g")
    echo -e "${red}[+] ${green}Container ${cname} using network interface: ${iface} not being observed, adding it.${nc}"
    containers+=($cont)

    # Check if pcap log directory exists before creating it.
    mkdir -p $bdir$iface"/"$cname

    # Start capturing traffic in the given interface.
    # (-s 0) captures full packets. This is slower but there will be no incomplete packets.
    if [[ $rlogs == "yes" ]]; then
      tcpdump -s 0 -i $iface -G $tperiod -w $bdir$iface"/"$cname"/"$cname"_"$iface"_%Y-%m-%d_%H:%M:%S.pcap" host $cip 2>/dev/null &
    else
      tcpdump -s 0 -i $iface -w $bdir$iface"/"$cname"/"$cname"_"$iface"_"$(date +'%Y-%m-%d_%H:%M:%S')".pcap" host $cip 2>/dev/null &
    fi
  fi
}


# Gather information about each running docker container and start logging network traffic.
while :
do
  sleep $discovery_period

  # Use the container id instead of the name because it is not sure the format of the fields
  # won't change. Like this the id is the first
  for container in `docker ps | awk 'NR>1{ print $1 }'`; do
    sleep 1
    network_name=$(docker inspect -f '{{ range $key, $value := .NetworkSettings.Networks }}{{ $key }}{{end}}' $container) # Assuming there is only one network.
    container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{ .IPAddress }}{{end}}' $container)

    # This can be confusing. When the container is running in the bridge network, we can directly know the host_iface
    # interface by inspecting the network, otherwise we will need to get the Network Id and check which interface matches.
    host_iface_id=$(docker network inspect -f '{{ if index .Options "com.docker.network.bridge.name" }}{{ index .Options "com.docker.network.bridge.name" }}{{else}}{{ .Id }}{{end}}' ${network_name})

    if [ $host_iface_id == "docker0" ]; then
      analyzeTraffic $container $host_iface_id $base_dir $time_period $rotate_logs $container_ip
    else
      # Find the host interface that connects to the network the docker is running in.
      for host_iface in `netstat -i | grep br | awk '{ print $1 }'`; do
        if [[ "$host_iface_id" == *$(echo $host_iface | awk -F'-' '{ print $2 }')* ]]; then
          analyzeTraffic $container $host_iface $base_dir $time_period $rotate_logs $container_ip
        fi
      done
    fi
  done
done
