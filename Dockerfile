FROM debian:11

EXPOSE 25 587 143 465 993 110 995 4190

ENV DEBIAN_FRONTEND="noninteractive"

# Update and upgrade
RUN apt-get -y update && apt-get install apt-utils && apt-get -y dist-upgrade

# Install packages:
RUN apt-get -y install \
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


# Copy supervisor config and make it's log directory
COPY ./supervisor/supervisord.conf /etc/supervisor/supervisord.conf
RUN mkdir -p /var/log/supervisor

# Copy init and util scripts
COPY ./supervisor/scripts/ ./utils/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# Copy postfix configs
COPY ./config/postfix/ /etc/postfix/

# Copy dovecot configs
COPY ./config/dovecot/dovecot.conf /etc/dovecot/dovecot.conf
COPY ./config/dovecot/pamd /etc/pam.d/dovecot

# Copy opendkim configs and make keys persistent (generate them in init.sh)
RUN mkdir -p /etc/opendkim/keys && chown -R opendkim:opendkim /etc/opendkim
COPY ./config/opendkim/opendkim.conf /etc/opendkim.conf
COPY ./config/opendkim/keytable ./config/opendkim/signingtable ./config/opendkim/trustedhosts /etc/opendkim/

# Copy and compile sieve scripts
RUN mkdir -p /var/lib/dovecot/sieve
COPY ./config/sieve/ /var/lib/dovecot/sieve/
RUN sievec /var/lib/dovecot/sieve/*

# link user files
RUN mkdir -p /etc/userfiles
RUN ln -sf /etc/userfiles/passwd /etc/passwd
RUN ln -sf /etc/userfiles/shadow /etc/shadow
RUN ln -sf /etc/userfiles/group /etc/group
RUN ln -sf /etc/userfiles/gshadow /etc/gshadow

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
