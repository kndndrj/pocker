FROM debian:11

# Update/upgrade and install packages
RUN apt-get update -y \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        postfix \
        postfix-pcre \
        dovecot-imapd \
        dovecot-sieve \
        spamassassin \
        spamc \
        opendkim \
        opendkim-tools \
        dumb-init \
        supervisor \
        rsyslog \
        gettext-base


# make required directories
RUN    mkdir -p /var/log/supervisor \
    && mkdir -p /etc/opendkim/keys \
    && chown -R opendkim:opendkim /etc/opendkim \
    && mkdir -p /var/lib/dovecot/sieve

# Copy supervisor config and make it's log directory
COPY ./supervisor/supervisord.conf /etc/supervisor/supervisord.conf

# Copy init and util scripts
COPY ./supervisor/scripts/ ./utils/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# Copy postfix configs
COPY ./config/postfix/ /etc/postfix/

# Copy dovecot configs
COPY ./config/dovecot/dovecot.conf /etc/dovecot/dovecot.conf
COPY ./config/dovecot/pamd /etc/pam.d/dovecot

# Copy opendkim configs and make keys persistent (generate them in init.sh)
COPY ./config/opendkim/opendkim.conf /etc/opendkim.conf
COPY ./config/opendkim/keytable ./config/opendkim/signingtable ./config/opendkim/trustedhosts /etc/opendkim/

# Copy and compile sieve scripts
COPY ./config/sieve/ /var/lib/dovecot/sieve/
RUN sievec /var/lib/dovecot/sieve/*

# link user files
RUN mkdir -p /etc/userfiles \
    && ln -sf /etc/userfiles/passwd /etc/passwd \
    && ln -sf /etc/userfiles/shadow /etc/shadow \
    && ln -sf /etc/userfiles/group /etc/group \
    && ln -sf /etc/userfiles/gshadow /etc/gshadow

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
