#!/bin/sh

# Add a "create account" to the login page
echo "info: Configuring \"create account\" button for all skins"
for i in $(ls /var/www/html/skins); do

	sed -i 's/.*product_*name\" condition.*/<a style="border-radius: 6px; text-decoration: none; background-color: #aabbcc; color: white; padding: 14px 20px; margin: 30px 0; border: none;" href="..\/..\/dashboard">Create Account<\/a>/' /var/www/html/skins/"$i"/templates/login.html

done

# Handle logo image
# if link provided, download the image
if [ -n "$ROUNDCUBEMAIL_LOGO_URL" ]; then
	echo "info: trying to download provided logo"
	if [ "${ROUNDCUBEMAIL_LOGO_URL##*.}" != "svg" ]; then
		echo "warning: provided icon is not in svg format"
	fi
	mkdir -p /icons
	if ! (curl --silent -o /icons/logo.svg "$ROUNDCUBEMAIL_LOGO_URL"); then
		echo "warning: could not download the provided icon"
	fi
fi

# check here - can also be provided via mountpoint
if [ -f /icons/logo.svg ]; then
	echo "info: Configuring logo for all skins"
	# Copy icons
	for i in $(ls /var/www/html/skins); do
		cp /icons/logo.svg /var/www/html/skins/"$i"/images/logo.svg
		cp /icons/logo.svg /var/www/html/skins/"$i"/images/roundcube_logo.svg
	done

	# Some skins point to png image... point them to svg
	for i in $(grep -rl "roundcube_logo.png" /var/www/html/*); do
		sed -i 's/roundcube_logo\.png/roundcube_logo\.svg/g' $i
	done

	echo "info: Configuring logo for favicon"
	echo '$config["skin_logo"] = [ "[favicon]" => "/images/logo.svg" ];' >> /var/www/html/config/config.inc.php
fi

exec "$@"
