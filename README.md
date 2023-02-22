# Pocker
Mailserver in Docker

## Overview
The server part is a docker image made of multiple services supervized by s6. It includes:
- Postfix
- Dovecot
- SpamAssassin
- OpenDKIM
- OpenDMARC
- UI dashboard (optionally)

## Quick Start
Check the complete [docker-compose.yml](./examples/docker-compose-complete.yml) for a complete example behind Traefik reverse proxy.

## Configuration

### Environment Variables
- `POCKER_SUBDOMAIN` - your mail subdomain - example: `mail`
- `POCKER_DOMAIN` - your mail domain - example: `example.com`
- `POCKER_TRUSTED_PROXIES` - space separated list of trusted proxy ips or hostnames (usually a container name of proxy container on the same docker network) - example: `192.168.0.123 traefik haproxy`
`-dashboard` only:
- `POCKER_PAGE_TITLE` - title of the optional dashboard - example: `Pocker Dashboard`
- `POCKER_LOGO_URL` - link to the logo image of your choice - example: `https://some.website.com/image.png`

### Persistent Data
Bind mount the following directories to your host or use a named volume if you preffer:
- `/etc/letsencrypt/live` - letsencrypt directory (expects certbot-like format)
- `/var/mail` - location of actual mail
- `/etc/userfiles` - for persistent users (mount and don't touch)
- `/etc/opendkim/keys` - it makes sense to keep opendkim keys persistent across container restarts

For more information refer to the example [`docker-compose.yml`](examples/docker-compose.yml).

## Management
If you chose to use the `-dashboard` variant the image, there is a web-UI running on `localhost:8080/dashboard`.

If you don't want a dashboard, just use the basic tools to do the job. e.g.:
```sh
# Make sure the user is in the mail group
docker exec -it useradd -m -G mail john
# add password to the user
docker exec -it passwd john
```

## Versioning
- `latest` - for the latest version
- `branch` - for the latest version on that branch
- `sha-1-short` - short commit hash
- `v1.2.3` - exact release version (stable)
For a variant with dashboard append `-dashboard` to one of the above.
