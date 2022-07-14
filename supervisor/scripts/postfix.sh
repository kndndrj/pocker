#!/bin/sh

trap "service postfix stop" 2 # SIGINT
trap "service postfix stop" 15 # SIGTERM
trap "service postfix reload" 1 # SIGHUP

service postfix start

# Wait for pid to become available
sleep 2

# wait until postfix is dead (triggered by trap)
while kill -0 "$(cat /var/spool/postfix/pid/master.pid)"; do
  sleep 5
done
