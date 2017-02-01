# docker-watcher
Keep track of running docker containers and analyze network traffic usage. Logs follow a naming convention *container_interface_date* and will be rotated or not according to a given  parameter.

## Usage

```sh
$ ./docker-watcher.sh -d|--discovery <discovery_time> -t|--t <time_period> -r|--rotate <yes/no>
```

  * **discovery_period** is the interval time for the script to wait to check if new containers have been started.
  * **time_period** is the elapsed time to store new traffic dumps.
  * **rotate** whether or not to rotate logs

## Example

```sh
$ ./docker-watcher.sh -d 5 -t 3 -r yes
```

This will check the running dockers every 5 seconds and create a new pcap file for each container every 3 seconds. The output will be like:

```sh
  pcap/
    interface1/
      container1/
        container1_br-31cc34v_2017-01-31_11:07:08.pcap
        container1_br-31cc34v_2017-01-31_11:07:14.pcap
      container2/
        container2_br-31cc34v_2017-01-31_11:07:10.pcap
    br-31cc34v_2017-01-31_11:07:10.pcap
      ...
```
