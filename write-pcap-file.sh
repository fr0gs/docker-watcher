#!/bin/bash

# Check whether or not tcpdump is installed.
if [ ! -f /usr/sbin/tcpdump ]; then
    echo "error: tcpdump not installed, please install it"
    exit -1
fi

# Check the number of arguments.
if [ "$#" -ne 6 ]; then
    echo "usage: ./write-pcap-file.sh -c|--container <container-name> -i|--interface <network-interface> -t|--timeperiod <period>"
    exit 1
fi

BASE_DIR=$PWD"/pcap/"

# Loop through arguments and assign variables.
while [ "$#" -gt 1 ];
  do
  key="$1"

  case $key in
      -c|--container)
      CONTAINER="$2"
      shift
      ;;

      -i|--interface)
      INTERFACE="$2"
      shift
      ;;

      -t|--timeperiod)
      PERIOD="$2"
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

# Check if pcap log directory exists before creating it.
mkdir -p $BASE_DIR$CONTAINER

# Start capturing traffic in the given interface.
# (-s 0) captures full packets. This is slower but there will be no incomplete packets.
tcpdump -s 0 -i $INTERFACE -G $PERIOD -w $BASE_DIR$CONTAINER"/"$CONTAINER"_"$INTERFACE"_%Y-%m-%d_%H:%M:%S.pcap"
