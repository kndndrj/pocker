#!/bin/sh

trap "service spamass-milter stop" 2 # SIGINT
trap "service spamass-milter stop" 15 # SIGTERM
trap "service spamass-milter force-reload" 1 # SIGHUP

service spamass-milter start

# Wait for pid to become available
sleep 3

# wait until spamass-milter is dead (triggered by trap)
while kill -0 "$(cat /var/run/spamass/spamass.pid)"; do
    sleep 5
done
