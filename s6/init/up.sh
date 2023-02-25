#!/command/with-contenv sh
# shellcheck shell=sh

echo "info: Running Init script"

if [ -z "$POCKER_DOMAIN" ] || [ -z "$POCKER_SUBDOMAIN" ]; then
    echo "error: No domain specified. Please set \$POCKER_DOMAIN and \$POCKER_SUBDOMAIN env variables and restart the container."
    exit 1
fi


###################################
## PRESETS                       ##
###################################
USERFILE_DIR="/etc/userfiles"
KEYS_DIR="/etc/opendkim/keys"
SIEVE_DIR="/var/lib/dovecot/sieve"
MAIL_DIR="/var/mail"

mkdir -p "$USERFILE_DIR"
mkdir -p "$KEYS_DIR"
mkdir -p "$SIEVE_DIR"
mkdir -p "$MAIL_DIR"

###################################
## USER FILES (IF PROVIDED)      ##
###################################
echo "info: configuring mounted userfiles"

for i in \
"$USERFILE_DIR/passwd:/etc/passwd" \
"$USERFILE_DIR/shadow:/etc/shadow" \
"$USERFILE_DIR/group:/etc/group" \
"$USERFILE_DIR/aliases:/etc/aliases" \
; do
    source="${i%%:*}"
    destination="${i#*:}"

    touch "$destination"
    cp "$destination" "$destination".old
    rm "$destination"

    [ ! -s "$source" ] && cat "$destination".old > "$source"

    ln -s "$source" "$destination"
done


###################################
## KEY GENERATION                ##
###################################
if [ ! -f "$KEYS_DIR"/"$POCKER_SUBDOMAIN".private ]; then
    echo "info: Opendkim keys for $POCKER_SUBDOMAIN not found. Generating new ones."
    opendkim-genkey -D "$KEYS_DIR" -d "$POCKER_DOMAIN" -s "$POCKER_SUBDOMAIN"
fi


###################################
## OWNERSHIP / PERMISSIONS       ##
###################################
# chown user's mail to the user
EXISTING_MAIL_USERS="$(ls "$MAIL_DIR")"

for u in $EXISTING_MAIL_USERS; do
    echo "info: configuring mail permissions for user: \"$u\""
    chown -R "$u:$u" "$MAIL_DIR/$u"
    mkdir -p "/home/$u"
    chown -R "$u:$u" "/home/$u"
done

# chown mail directory to mail
echo "info: Changing ownership of $MAIL_DIR"

if ! ( \
chgrp mail "$MAIL_DIR" && \
chmod 2775 "$MAIL_DIR" \
); then
    echo "error: Could not change ownership/permissions of $MAIL_DIR. Make sure you don't have \":ro\" mount option set!"
    exit 1
fi

# chown dkim keys to opendkim
echo "info: Changing ownership of dkim keys"

if ! ( \
chown -R opendkim:opendkim "$KEYS_DIR" && \
chmod 640 "$KEYS_DIR"/* \
); then
    echo "error: Could not change ownership/permissions of dkim keys. Make sure you don't have \":ro\" mount option set!"
    exit 1
fi

###################################
## TEMPLATING                    ##
###################################
echo "info: Templating config files"

# Translate any hostnames to ips
for i in $POCKER_TRUSTED_PROXIES; do
    IP="$i"
    # If not ip address, try to translate it to hostname
    if ! (echo "$IP" | grep -Eq "^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,3})?$"); then
        IP="$(getent hosts "$IP" | cut -d ' ' -f 1)"
    fi
    TRUSTED_PROXIES="$TRUSTED_PROXIES $IP"
done

export POCKER_DOMAIN
export POCKER_SUBDOMAIN
export POCKER_MAIL_DOMAIN="$POCKER_SUBDOMAIN.$POCKER_DOMAIN"
export POCKER_TRUSTED_PROXIES="$TRUSTED_PROXIES"
export POCKER_USERFILE_DIR="$USERFILE_DIR"
export POCKER_KEYS_DIR="$KEYS_DIR"
export POCKER_SIEVE_DIR="$SIEVE_DIR"
export POCKER_MAIL_DIR="$MAIL_DIR"

# Template the list of files
for i in \
"/etc/mailconfigs/postfix/main.cf:/etc/postfix/main.cf" \
"/etc/mailconfigs/postfix/master.cf:/etc/postfix/master.cf" \
"/etc/mailconfigs/postfix/header_checks:/etc/postfix/header_checks" \
\
"/etc/mailconfigs/dovecot/dovecot.conf:/etc/dovecot/dovecot.conf" \
"/etc/mailconfigs/dovecot/default.sieve:"$SIEVE_DIR"/default.sieve" \
\
"/etc/mailconfigs/opendkim/opendkim.conf:/etc/opendkim.conf" \
"/etc/mailconfigs/opendkim/keytable:/etc/opendkim/keytable" \
"/etc/mailconfigs/opendkim/signingtable:/etc/opendkim/signingtable" \
"/etc/mailconfigs/opendkim/trustedhosts:/etc/opendkim/trustedhosts" \
\
"/etc/mailconfigs/opendmarc/opendmarc.conf:/etc/opendmarc.conf" \
; do
    source="${i%%:*}"
    destination="${i#*:}"

    mkdir -p "$(dirname "$destination")"
    # shellcheck disable=SC2016 # we don't want these variables to expand
    envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_TRUSTED_PROXIES $POCKER_USERFILE_DIR $POCKER_KEYS_DIR $POCKER_SIEVE_DIR $POCKER_MAIL_DIR' < "$source" > "$destination"
done


###################################
## MISC                          ##
###################################
echo "info: Compiling sieve scripts"
sievec "$SIEVE_DIR"/*

echo "info: Generating alias maps"
newaliases -f /etc/aliases

# write environment to file
echo "\
POCKER_DOMAIN=\"$POCKER_DOMAIN\"
POCKER_SUBDOMAIN=\"$POCKER_SUBDOMAIN\"
POCKER_MAIL_DOMAIN=\"$POCKER_MAIL_DOMAIN\"
POCKER_TRUSTED_PROXIES=\"$POCKER_TRUSTED_PROXIES\"
POCKER_USERFILE_DIR=\"$POCKER_USERFILE_DIR\"
POCKER_KEYS_DIR=\"$POCKER_KEYS_DIR\"
POCKER_SIEVE_DIR=\"$POCKER_SIEVE_DIR\"
POCKER_MAIL_DIR=\"$POCKER_MAIL_DIR\"
" > /env
