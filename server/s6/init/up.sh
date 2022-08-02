#!/command/with-contenv sh

echo "info: Running Init script"

if [ -z "$DOMAIN$SUBDOMAIN" ]; then
    echo "error: No domain specified. Please set \$DOMAIN and \$SUBDOMAIN env variables and restart the container."
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
if [ ! -f /etc/opendkim/keys/"$SUBDOMAIN".private ]; then
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

PROXY_IP="$(getent hosts traefik | cut -d ' ' -f 1)"

export POCKER_DOMAIN="$DOMAIN"
export POCKER_SUBDOMAIN="$SUBDOMAIN"
export POCKER_MAIL_DOMAIN="$SUBDOMAIN.$DOMAIN"
export POCKER_PROXY_IP="$PROXY_IP"

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
    envsubst '$POCKER_DOMAIN $POCKER_SUBDOMAIN $POCKER_MAIL_DOMAIN $POCKER_PROXY_IP' < "$source" > "$destination"
done


###################################
## MISC                          ##
###################################
echo "info: Compiling sieve scripts"
sievec /var/lib/dovecot/sieve/*

echo "info: Generating alias maps"
newaliases -f /etc/aliases
