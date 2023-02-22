# Pocker - Mail Docker Images

The complete mail server consists of server and client parts.

## Server
The server part is a docker image made of multiple services supervized by s6. It includes:
- Postfix
- Dovecot
- SpamAssassin
- OpenDKIM
- OpenDMARC
- UI dashboard (optionally)

More information can be found in the [server's](./server/) README.md.

## Client
Client part is basically just a roundcube docker image with a few extra features.

Check [client's](./client/) README.md for more.

## Quick Start
Check the complete [docker-compose.yml](./examples/docker-compose-complete.yml) for a complete example behind Traefik reverse proxy.

## Packages
- Basic server: `ghcr.io/kndndrj/pocker-server`
- Server with user management dashboard: `ghcr.io/kndndrj/pocker-server-dashboard`
- Roundcube client: `ghcr.io/kndndrj/pocker-client`

#### Versioning
- `latest` - for the latest version
- `branch` - for the latest version on that branch
- `v1.2.3` - exact release version (stable)
