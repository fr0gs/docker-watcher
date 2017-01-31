#!/bin/bash

# Check whether or not tcpdump is installed.
if [ ! -f /usr/sbin/tcpdump ]; then
    echo "error: tcpdump not installed, please install it"
    exit -1
fi


BASE_DIR=$PWD"/pcap/"
ROTATE="no"

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

      -r|--rotate)
      ROTATE="$2"
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

if [ $ROTATE == "yes" ]; then
  tcpdump -s 0 -i $INTERFACE -G $PERIOD -w $BASE_DIR$CONTAINER"/"$CONTAINER"_"$INTERFACE"_%Y-%m-%d_%H:%M:%S.pcap"
else
  tcpdump -s 0 -i $INTERFACE -w $BASE_DIR$CONTAINER"/"$CONTAINER"_"$INTERFACE"_"$(date +'%Y-%m-%d_%H:%M:%S')".pcap"
fi
