#
# Base Image
#
FROM debian:11-slim as base

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
        opendmarc \
        gettext-base \
        xz-utils \
        inotify-tools

# Install s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v3.1.0.1/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v3.1.0.1/s6-overlay-x86_64.tar.xz /tmp
RUN    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# Copy s6 service scripts
COPY ./s6/ /etc/s6-overlay/s6-rc.d/

# make required directories
RUN    mkdir -p \
           /etc/opendkim/keys \
           /var/lib/dovecot/sieve \
    && chown -R opendkim:opendkim /etc/opendkim

# Copy mail services configs (move them to their places with init service)
COPY ./config/ /etc/mailconfigs/

# Run s6
ENTRYPOINT ["/init"]


#
# Image With Dashboard
#
FROM base AS dashboard

# Install Extra packages
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        curl

# Create a user for auth
RUN useradd auth_checker

# Make icons directory
RUN mkdir -p /icons

# Install shell2html
ADD https://github.com/msoap/shell2http/releases/download/v1.14.1/shell2http_1.14.1_linux_amd64.tar.gz /tmp
RUN    tar -xf /tmp/shell2http_1.14.1_linux_amd64.tar.gz -C /tmp/ \
    && mv /tmp/shell2http /usr/local/bin/ \
    && chmod +x /usr/local/bin/shell2http

# Copy dashboard files
COPY ./dashboard/scripts /opt/dashboard
COPY ./dashboard/s6/ /etc/s6-overlay/s6-rc.d/
