#
# Base Image
#
FROM alpine:latest as base
ARG S6_OVERLAY_VERSION=3.1.4.1
ARG TARGETPLATFORM=linux/amd64

# Update/upgrade and install packages
RUN apk add --update-cache --no-cache \
        postfix \
        postfix-pcre \
        dovecot \
        dovecot-pigeonhole-plugin \
        spamassassin \
        spamassassin-client \
        opendkim \
        opendkim-utils \
        opendmarc \
        gettext \
        inotify-tools \
        libmilter-dev \
	gpg-agent \
        curl

# Compile spamass-milter
RUN apk --no-cache add --virtual .fetch-deps \
        libstdc++ \
	libgcc \
        autoconf \
        automake \
        build-base \
 && curl -sfLo master.tar.gz https://github.com/andybalholm/spamass-milter/archive/master.tar.gz \
 && tar -xvf master.tar.gz \
 && cd spamass-milter-master \
 && ./autogen.sh \
 && make \
 && make install \
 && cd .. \
 && rm -rf spamass-milter-master master.tar.gz \
 && apk del .fetch-deps \
 && adduser -D spamass-milter

# Install s6-overlay
RUN case ${TARGETPLATFORM} in \
        "linux/amd64")   S6_OVERLAY_ARCH=x86_64  ;; \
        "linux/arm64")   S6_OVERLAY_ARCH=aarch64 ;; \
        "linux/arm/v7")  S6_OVERLAY_ARCH=arm     ;; \
        "linux/arm/v6")  S6_OVERLAY_ARCH=armhf   ;; \
        "linux/386")     S6_OVERLAY_ARCH=i686    ;; \
    esac \
 && curl -sfLo /tmp/s6-overlay-noarch.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
 && curl -sfLo /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz \
 && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
 && tar -C / -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# Copy s6 service scripts
COPY ./s6/ /etc/s6-overlay/s6-rc.d/

# make required directories
RUN mkdir -p \
        /etc/opendkim/keys \
        /var/lib/dovecot/sieve \
 && chown -R opendkim:opendkim /etc/opendkim

RUN mkdir -p /usr/share/publicsuffix \
 && curl -sfLo /usr/share/publicsuffix/public_suffix_list.dat https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat

# Copy mail services configs (move them to their places with init service)
COPY ./config/ /etc/mailconfigs/

# Run s6
ENTRYPOINT ["/init"]


#
# Image With Dashboard
#
FROM base AS dashboard
ARG SHELL2HTTP_VERSION=1.15.0
ARG TARGETPLATFORM=linux/amd64

# Create a user for auth
RUN adduser -D auth_checker

# Make icons directory
RUN mkdir -p /icons

# Install shell2html
RUN case ${TARGETPLATFORM} in \
        "linux/amd64")   SHELL2HTTP_ARCH=amd64   ;; \
        "linux/arm64")   SHELL2HTTP_ARCH=arm64   ;; \
        "linux/arm/v7")  SHELL2HTTP_ARCH=arm     ;; \
        "linux/arm/v6")  SHELL2HTTP_ARCH=armv6   ;; \
        "linux/386")     SHELL2HTTP_ARCH=386     ;; \
    esac \
 && curl -sfLo /tmp/shell2http.tar.gz https://github.com/msoap/shell2http/releases/download/v${SHELL2HTTP_VERSION}/shell2http_${SHELL2HTTP_VERSION}_linux_${SHELL2HTTP_ARCH}.tar.gz \
 && tar -xf /tmp/shell2http.tar.gz -C /tmp/ \
 && mv /tmp/shell2http /usr/local/bin/ \
 && chmod +x /usr/local/bin/shell2http

# Copy dashboard files
COPY ./dashboard/scripts /opt/dashboard
COPY ./dashboard/s6/ /etc/s6-overlay/s6-rc.d/
