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
	if ! (curl --silent -o /tmp/logo.downloaded "$ROUNDCUBEMAIL_LOGO_URL"); then
		echo "warning: could not download the provided icon"
		exit 1
	fi
	# Determine the type and move to location
	TYPE="$(file -b /tmp/logo.downloaded | cut -d " " -f 1 | tr '[:upper:]' '[:lower:]')"
	mv /tmp/logo.downloaded /icons/logo."$TYPE"
fi

# check here - can also be provided via mountpoint
if [ "$(ls /icons/logo.* 2>/dev/null | wc -l)" -gt "0" ]; then
	echo "info: Configuring logo for all skins"

	# First icon
	ICON="$(basename "$(ls /icons/logo.* | head -n 1)")"

	# Copy icons
	for i in $(ls /var/www/html/skins); do
		cp /icons/"$ICON" /var/www/html/skins/"$i"/images/"$ICON"
	done

	# Change file types in HTML
	for i in $(grep -wrl "roundcube_logo.png\|logo.svg" /var/www/html/*); do
		sed -i "s/roundcube_logo\.png/$ICON/g; s/logo\.svg/$ICON/g" "$i"
	done

	# Configure favicon
	echo "info: Configuring logo for favicon"
	echo "\$config[\"skin_logo\"] = [ \"[favicon]\" => \"/images/$ICON\" ];" >> /var/www/html/config/config.inc.php
fi

# Webpage title
if [ -n "$ROUNDCUBEMAIL_PAGE_TITLE" ]; then
	echo "\$config[\"product_name\"] = \"$ROUNDCUBEMAIL_PAGE_TITLE\";" >> /var/www/html/config/config.inc.php
else
	echo "\$config[\"product_name\"] = \"Pocker Mail\";" >> /var/www/html/config/config.inc.php
fi

exec "$@"
