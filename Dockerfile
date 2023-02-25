#
# Base Image
#
FROM alpine:latest as base
ARG S6_OVERLAY_VERSION=3.1.4.1
ARG TARGETPLATFORM=linux/amd64

# Install packages
RUN apk add --no-cache \
        postfix \
        postfix-pcre \
        dovecot \
        dovecot-pigeonhole-plugin \
        spamassassin \
        spamassassin-client \
        gpg-agent \
        opendkim \
        opendkim-utils \
        opendmarc \
        gettext

# Compile spamass-milter
RUN apk --no-cache add --virtual .fetch-deps \
        libmilter-dev \
        libstdc++ \
        libgcc \
        autoconf \
        automake \
        build-base \
 && wget -q https://github.com/andybalholm/spamass-milter/archive/master.tar.gz -O master.tar.gz \
 && tar -xvf master.tar.gz \
 && cd spamass-milter-master \
 && ./autogen.sh \
 && make \
 && make install \
 && cd .. \
 && rm -rf spamass-milter-master master.tar.gz \
 && apk del .fetch-deps \
 && adduser -u 111 -D spamass-milter

# Install s6-overlay
RUN case ${TARGETPLATFORM} in \
        "linux/amd64")   S6_OVERLAY_ARCH=x86_64  ;; \
        "linux/arm64")   S6_OVERLAY_ARCH=aarch64 ;; \
        "linux/arm/v7")  S6_OVERLAY_ARCH=arm     ;; \
        "linux/arm/v6")  S6_OVERLAY_ARCH=armhf   ;; \
        "linux/386")     S6_OVERLAY_ARCH=i686    ;; \
    esac \
 && wget -q https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -O /tmp/s6-overlay-noarch.tar.xz \
 && wget -q https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz -O /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz \
 && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
 && tar -C / -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# Install the public suffix list
RUN mkdir -p /usr/share/publicsuffix \
 && wget -q https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat -O /usr/share/publicsuffix/public_suffix_list.dat

# Copy s6 service scripts
COPY ./s6/ /etc/s6-overlay/s6-rc.d/

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

# Install extra packages
RUN apk add --no-cache \
        util-linux-login

# Create a user for auth
RUN adduser -u 112 -D auth_checker

# Make icons directory
RUN mkdir -p /icons

# Install shell2html
RUN case ${TARGETPLATFORM} in \
        "linux/amd64")   SHELL2HTTP_ARCH=amd64   ;; \
        "linux/arm64")   SHELL2HTTP_ARCH=arm64   ;; \
        "linux/arm/v7")  SHELL2HTTP_ARCH=armv6   ;; \
        "linux/arm/v6")  SHELL2HTTP_ARCH=armv6   ;; \
        "linux/386")     SHELL2HTTP_ARCH=386     ;; \
    esac \
 && wget -q https://github.com/msoap/shell2http/releases/download/v${SHELL2HTTP_VERSION}/shell2http_${SHELL2HTTP_VERSION}_linux_${SHELL2HTTP_ARCH}.tar.gz -O /tmp/shell2http.tar.gz \
 && tar -xf /tmp/shell2http.tar.gz -C /tmp/ \
 && mv /tmp/shell2http /usr/local/bin/ \
 && chmod +x /usr/local/bin/shell2http

# Copy dashboard files
COPY ./dashboard/scripts /opt/dashboard
COPY ./dashboard/s6/ /etc/s6-overlay/s6-rc.d/
