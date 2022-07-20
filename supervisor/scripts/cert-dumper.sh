#!/bin/sh

# If direcotry not mounted, exit and don't restart
if [ ! -d /letsencrypt ]; then
    sleep 5
    if [ ! -d /letsencrypt ]; then
        echo "info: acme.json not found - exiting."
        exit 0
    fi
fi

# Watch the changes and dump certs if needed
traefik-certs-dumper file --version v2 --watch --source /letsencrypt/acme.json --dest /etc/letsencrypt/live/ --domain-subdir --crt-name=fullchain --key-name=privkey --crt-ext=.pem --key-ext=.pem
