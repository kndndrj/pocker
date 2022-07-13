#!/bin/sh

echo "info: Running Init script"

if [ -z "$DOMAIN$SUBDOMAIN" ]; then
    echo "error: No domain specified. Please set \$DOMAIN and \$SUBDOMAIN env variables and restart the container."
    exit 1
fi

###################################
## KEY GENERATION                ##
###################################
if [ ! -f /etc/opendkim/keys/$SUBDOMAIN.private ]; then
    echo "info: Opendkim keys for $SUBDOMAIN not found. Generating new ones."
    opendkim-genkey -D /etc/opendkim/keys -d "$DOMAIN" -s "$SUBDOMAIN"
fi

###################################
## OWNERSHIP / PERMISSIONS       ##
###################################
# chown mail directory to mail
if [ "$(stat --format '%G:%a' /var/mail)" != "mail:2775" ]; then
    echo "info: Changing ownership of /var/mail"

    chgrp mail /var/mail
    chmod 2775 /var/mail
    if [ $? -ne 0 ]; then
        echo "error: Could not change ownership/permissions of /var/mail. Make sure you don't have \":ro\" mount option set!"
        exit 1
    fi
fi

# chown dkim keys to opendkim
if [ "$(stat --format '%U:%G:%a' /etc/opendkim/keys/$SUBDOMAIN.private)" != "opendkim:opendkim:640" ]; then
    echo "info: Changing ownership of dkim keys"

    chown -R opendkim:opendkim /etc/opendkim/keys
    chmod 640 /etc/opendkim/keys/*
    if [ $? -ne 0 ]; then
        echo "error: Could not change ownership/permissions of dkim keys. Make sure you don't have \":ro\" mount option set!"
        exit 1
    fi
fi

# chown password files to root
if [ "$(stat --format '%U:%G:%a' /etc/passwd)" != "root:root:644" ] || [ "$(stat --format '%U:%G:%a' "$(readlink /etc/shadow)")" != "root:shadow:640" ]; then
    echo "info: Changing ownership of passwd files"

    chown root:root /etc/passwd /etc/group
    chown root:shadow /etc/shadow /etc/gshadow
    chmod 644 /etc/passwd /etc/group
    chmod 640 /etc/shadow /etc/gshadow
    if [ $? -ne 0 ]; then
        echo "error: Could not change ownership/permissions of user passwd files. Make sure you don't have \":ro\" mount option set!"
        exit 1
    fi
        
fi

###################################
## TEMPLATING                    ##
###################################
echo "info: Templating config files"

export POCKER_DOMAIN="$DOMAIN"
export POCKER_SUBDOMAIN="$SUBDOMAIN"
export POCKER_MAIL_DOMAIN="$SUBDOMAIN.$DOMAIN"

TEMP="$(mktemp)"
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN' < /etc/dovecot/dovecot.conf  > "$TEMP"
cat "$TEMP" > /etc/dovecot/dovecot.conf
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN' < /etc/postfix/main.cf       > "$TEMP"
cat "$TEMP" > /etc/postfix/main.cf
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN' < /etc/postfix/master.cf     > "$TEMP"
cat "$TEMP" > /etc/postfix/master.cf
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN' < /etc/opendkim.conf         > "$TEMP"
cat "$TEMP" > /etc/opendkim.conf
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN' < /etc/opendkim/keytable     > "$TEMP"
cat "$TEMP" > /etc/opendkim/keytable
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN' < /etc/opendkim/signingtable > "$TEMP"
cat "$TEMP" > /etc/opendkim/signingtable
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN' < /etc/opendkim/trustedhosts > "$TEMP"
cat "$TEMP" > /etc/opendkim/trustedhosts
