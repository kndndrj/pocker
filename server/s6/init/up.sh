#!/command/with-contenv sh
# shellcheck shell=sh

echo "info: Running Init script"

if [ -z "$POCKER_DOMAIN" ] || [ -z "$POCKER_SUBDOMAIN" ]; then
    echo "error: No domain specified. Please set \$POCKER_DOMAIN and \$POCKER_SUBDOMAIN env variables and restart the container."
    exit 1
fi


###################################
## USER FILES (IF PROVIDED)      ##
###################################
echo "info: configuring mounted userfiles"
[ -f /etc/userfiles/passwd ]  && [ -s /etc/userfiles/passwd ]  && cat /etc/userfiles/passwd > /etc/passwd
[ -f /etc/userfiles/shadow ]  && [ -s /etc/userfiles/shadow ]  && cat /etc/userfiles/shadow > /etc/shadow
[ -f /etc/userfiles/group ]   && [ -s /etc/userfiles/group ]   && cat /etc/userfiles/group > /etc/group
[ -f /etc/userfiles/gshadow ] && [ -s /etc/userfiles/gshadow ] && cat /etc/userfiles/gshadow > /etc/gshadow
[ -f /etc/userfiles/aliases ] && [ -s /etc/userfiles/aliases ] && cat /etc/userfiles/aliases > /etc/aliases


###################################
## KEY GENERATION                ##
###################################
if [ ! -f /etc/opendkim/keys/"$POCKER_SUBDOMAIN".private ]; then
    echo "info: Opendkim keys for $POCKER_SUBDOMAIN not found. Generating new ones."
    opendkim-genkey -D /etc/opendkim/keys -d "$POCKER_DOMAIN" -s "$POCKER_SUBDOMAIN"
fi


###################################
## OWNERSHIP / PERMISSIONS       ##
###################################
# chown user's mail to the user
EXISTING_MAIL_USERS="$(ls /var/mail)"

for u in $EXISTING_MAIL_USERS; do
    echo "info: configuring mail permissions for user: \"$u\""
    chown -R "$u:$u" "/var/mail/$u"
    mkdir -p "/home/$u"
    chown -R "$u:$u" "/home/$u"
done

# chown mail directory to mail
echo "info: Changing ownership of /var/mail"

if ! ( \
chgrp mail /var/mail && \
chmod 2775 /var/mail \
); then
    echo "error: Could not change ownership/permissions of /var/mail. Make sure you don't have \":ro\" mount option set!"
    exit 1
fi

# chown dkim keys to opendkim
echo "info: Changing ownership of dkim keys"

if ! ( \
chown -R opendkim:opendkim /etc/opendkim/keys && \
chmod 640 /etc/opendkim/keys/* \
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
# Strip whitespace
TRUSTED_PROXIES="$(echo "$TRUSTED_PROXIES" | sed 's/^\s*//g; s/\s*$//g; s/\s\s*/ /g' )"

export POCKER_DOMAIN
export POCKER_SUBDOMAIN
export POCKER_MAIL_DOMAIN="$POCKER_SUBDOMAIN.$POCKER_DOMAIN"
export POCKER_TRUSTED_PROXIES="$TRUSTED_PROXIES"

# Template the list of files
for i in \
"/etc/mailconfigs/postfix/main.cf:/etc/postfix/main.cf" \
"/etc/mailconfigs/postfix/master.cf:/etc/postfix/master.cf" \
"/etc/mailconfigs/postfix/header_checks:/etc/postfix/header_checks" \
\
"/etc/mailconfigs/dovecot/dovecot.conf:/etc/dovecot/dovecot.conf" \
"/etc/mailconfigs/dovecot/pamd:/etc/pam.d/dovecot" \
\
"/etc/mailconfigs/opendkim/opendkim.conf:/etc/opendkim.conf" \
"/etc/mailconfigs/opendkim/keytable:/etc/opendkim/keytable" \
"/etc/mailconfigs/opendkim/signingtable:/etc/opendkim/signingtable" \
"/etc/mailconfigs/opendkim/trustedhosts:/etc/opendkim/trustedhosts" \
\
"/etc/mailconfigs/sieve/default.sieve:/var/lib/dovecot/sieve/default.sieve" \
; do
    source="${i%%:*}"
    destination="${i#*:}"
    # shellcheck disable=SC2016 # we don't want these variables to expand
    envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_TRUSTED_PROXIES' < "$source" > "$destination"
done


###################################
## MISC                          ##
###################################
echo "info: Compiling sieve scripts"
sievec /var/lib/dovecot/sieve/*

echo "info: Generating alias maps"
newaliases -f /etc/aliases
