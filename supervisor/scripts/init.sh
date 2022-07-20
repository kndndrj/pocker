#!/bin/sh

echo "info: Running Init script"

if [ -z "$DOMAIN$SUBDOMAIN" ]; then
    echo "error: No domain specified. Please set \$DOMAIN and \$SUBDOMAIN env variables and restart the container."
    exit 1
fi


###################################
## FILES (IF NOT PROVIDED)       ##
###################################
if [ ! -s /etc/passwd ] && [ ! -s /etc/shadow ] && [ ! -s /etc/group ] && [ ! -s /etc/gshadow ]; then
    cat /etc/userfiles.default/passwd > /etc/passwd
    cat /etc/userfiles.default/shadow > /etc/shadow
    cat /etc/userfiles.default/group > /etc/group
    cat /etc/userfiles.default/gshadow > /etc/gshadow
    cat /etc/userfiles.default/aliases > /etc/aliases
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
# chown user's mail to the user
EXISTING_MAIL_USERS="$(ls /var/mail)"

for u in $EXISTING_MAIL_USERS; do
    echo "info: configuring mail permissions for user: \"$u\""
    chown -R "$u:$u" "/var/mail/$u"
    mkdir -p "home/$u"
    chown -R "$u:$u" "/home/$u"
done

# chown mail directory to mail
echo "info: Changing ownership of /var/mail"

chgrp mail /var/mail
chmod 2775 /var/mail
if [ $? -ne 0 ]; then
    echo "error: Could not change ownership/permissions of /var/mail. Make sure you don't have \":ro\" mount option set!"
    exit 1
fi

# chown dkim keys to opendkim
echo "info: Changing ownership of dkim keys"

chown -R opendkim:opendkim /etc/opendkim/keys
chmod 640 /etc/opendkim/keys/*
if [ $? -ne 0 ]; then
    echo "error: Could not change ownership/permissions of dkim keys. Make sure you don't have \":ro\" mount option set!"
    exit 1
fi

# chown password files to root
echo "info: Changing ownership of passwd files"

chown root:root /etc/passwd /etc/group
chown root:shadow /etc/shadow /etc/gshadow
chmod 644 /etc/passwd /etc/group
chmod 640 /etc/shadow /etc/gshadow
if [ $? -ne 0 ]; then
    echo "error: Could not change ownership/permissions of user passwd files. Make sure you don't have \":ro\" mount option set!"
    exit 1
fi

# chown aliases to root
echo "info: Changing ownership of alias files"

chown root:root /etc/aliases
chmod 644 /etc/aliases
if [ $? -ne 0 ]; then
    echo "error: Could not change ownership/permissions of /etc/aliases. Make sure you don't have \":ro\" mount option set!"
    exit 1
fi

###################################
## TEMPLATING                    ##
###################################
echo "info: Templating config files"

export POCKER_DOMAIN="$DOMAIN"
export POCKER_SUBDOMAIN="$SUBDOMAIN"
export POCKER_MAIL_DOMAIN="$SUBDOMAIN.$DOMAIN"
export POCKER_PROXY_IP="$(getent hosts traefik | cut -d ' ' -f 1)"

# All files are already at it's place (moved in Dockerfile) we just need to handle the templated ones

# Postfix
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < /etc/mailconfigs/postfix/main.cf        > /etc/postfix/main.cf
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < /etc/mailconfigs/postfix/master.cf      > /etc/postfix/master.cf

# Dovecot
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < /etc/mailconfigs/dovecot/dovecot.conf   > /etc/dovecot/dovecot.conf

# Opendkim
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < /etc/mailconfigs/opendkim/opendkim.conf > /etc/opendkim.conf
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < /etc/mailconfigs/opendkim/keytable      > /etc/opendkim/keytable
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < /etc/mailconfigs/opendkim/signingtable  > /etc/opendkim/signingtable
envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < /etc/mailconfigs/opendkim/trustedhosts  > /etc/opendkim/trustedhosts

###################################
## CLEARING PID FILES            ##
###################################
echo "info: Clearing process PIDs"
rm -f /run/supervisord.pid \
   /run/rsyslogd.pid \
   /run/dovecot/master.pid \
   /run/opendkim/opendkim.pid \
   /run/spamass/spamass.pid \
   /var/run/spamd.pid

###################################
## GENERATING ALIAS MAPS         ##
###################################
echo "info: Generating alias maps"
newaliases -f /etc/aliases
