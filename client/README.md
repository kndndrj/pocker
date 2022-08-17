# Pocker CLient

Roundcube docker image with a few extra features

### Configuration
Configure the image exactly the same as [roundcube](https://github.com/roundcube/roundcubemail) docker image. The only exception are these 2 environment variables:

- `ROUNDCUBEMAIL_PAGE_TITLE` - website title - example: `Pocker Mail`
- `ROUNDCUBEMAIL_LOGO_URL` - link to the logo image of your choice - example: `https://some.website.com/image.png`
- `ROUNDCUBEMAIL_DEFAULT_MAIL_DOMAIN` - default mail domain to set up for new users - example: `%d` for `example.com` instead of `mail.example.com`

For more information refer to the example `docker-compose.yml` file(s).
