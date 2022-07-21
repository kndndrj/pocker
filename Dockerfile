FROM debian:11

# Update/upgrade and install packages
RUN apt-get update -y \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        postfix \
        postfix-pcre \
        dovecot-imapd \
        dovecot-sieve \
        spamassassin \
        spamass-milter \
        spamc \
        opendkim \
        opendkim-tools \
        supervisor \
        rsyslog \
        gettext-base

# make required directories
RUN    mkdir -p \
           /var/log/supervisor \
           /etc/opendkim/keys \
           /var/lib/dovecot/sieve \
    && chown -R opendkim:opendkim /etc/opendkim

# Copy supervisor config
COPY ./supervisor/supervisord.conf /etc/supervisor/supervisord.conf

# Copy scripts
COPY ./entrypoint.sh ./supervisor/wrappers/ ./utils/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# Copy mail services configs (move them to their places in entrypoint.sh)
COPY ./config/ /etc/mailconfigs/

# Create a dmarc user
RUN useradd -m -G mail dmarc

# Install traefik-certs-dumper
ADD https://github.com/ldez/traefik-certs-dumper/releases/download/v2.8.1/traefik-certs-dumper_v2.8.1_linux_amd64.tar.gz /tmp/cert-dumper.tar.gz
RUN    tar -xf /tmp/cert-dumper.tar.gz -C /tmp/ \
    && mv /tmp/traefik-certs-dumper /usr/local/bin/ \
    && chmod +x /usr/local/bin/traefik-certs-dumper

# Make backups and link user files
RUN    mkdir -p /etc/userfiles /etc/userfiles.default \
       # Defaults (userfiles - in case the directory isn't mounted) \
    && cp /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/aliases /etc/userfiles.default \
    && cp /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/aliases /etc/userfiles \
       # Links \
    && ln -sf /etc/userfiles/passwd /etc/passwd \
    && ln -sf /etc/userfiles/shadow /etc/shadow \
    && ln -sf /etc/userfiles/group /etc/group \
    && ln -sf /etc/userfiles/gshadow /etc/gshadow \
    && ln -sf /etc/userfiles/aliases /etc/aliases

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
