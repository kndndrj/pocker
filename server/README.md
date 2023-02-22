# Pocker Server

Mail server docker image made of multiple services supervized by s6:
- Postfix
- Dovecot
- SpamAssassin
- OpenDKIM
- OpenDMARC
- UI dashboard (optionally)
All longrun, oneshot and bundle services can be found in s6 directory.

## Configuration

### Environment Variables
- `POCKER_SUBDOMAIN` - your mail subdomain - example: `mail`
- `POCKER_DOMAIN` - your mail domain - example: `example.com`
- `POCKER_PAGE_TITLE` - title of the optional dashboard - example: `Pocker Dashboard`
- `POCKER_LOGO_URL` - link to the logo image of your choice - example: `https://some.website.com/image.png`
- `POCKER_TRUSTED_PROXIES` - space separated list of trusted proxy ips or hostnames (usually a container name of proxy container on the same docker network) - example: `192.168.0.123 traefik haproxy`

### Volumes
###### Certificates
Pocker expects certs in the same location and same location that certbot provides:
- `/etc/letsencrypt/live` - letsencrypt directory - mount this directory if you are using certbot (or similar) to provide certs with on the host.

###### Mail
- `/var/mail` - mount this if you want persistent mail (you probably do)

###### User Data
- `/etc/userfiles` - mount this if you want persistent users (you probably do)

###### OpenDKIM Keys
- `/etc/opendkim/keys` - mount this if you want persistent DKIM keys (you probably do)


For more information refer to the example `docker-compose.yml` file(s).

## Management
If you chose to use the "-dashboard" variant of server image, you can use *it* to create new users. Otherwise, you can use basic linux utils to do the job. e.g.:
```sh
# Make sure the user is in the mail group
docker exec -it useradd -m -G mail john
# add password to the user
docker exec -it passwd john
```
