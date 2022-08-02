FROM roundcube/roundcubemail:latest

# "apache2" must be in the name, otherwise docker-entrypoint.sh (default ENTRYPOINT) won't do anything
COPY ./startup.sh /usr/local/bin/apache2-startup-script.sh
RUN chmod +x /usr/local/bin/apache2-startup-script.sh

# Make icon directory
RUN mkdir -p /icons

CMD ["apache2-startup-script.sh", "apache2-foreground"]
