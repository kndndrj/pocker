#!/command/with-contenv sh

echo "info: Running Dashboard Init script"


###################################
## LOGO                          ##
###################################

# Handle logo image
# if link provided, download the image
if [ -n "$POCKER_LOGO_URL" ]; then
        echo "info: trying to download provided logo"
        if ! (curl --silent -o /icons/logo "$POCKER_LOGO_URL"); then
                echo "warning: could not download the provided icon"
        fi
fi

###################################
## TEMPLATING                    ##
###################################
echo "info: Templating html files"

[ -z "$POCKER_PAGE_TITLE" ] && POCKER_PAGE_TITLE="Pocker Mail"

export POCKER_PAGE_TITLE

# shellcheck disable=SC2016 # we don't want these variables to expand
TEMP="$(mktemp)"
envsubst '$POCKER_PAGE_TITLE' < /opt/dashboard/index.html > "$TEMP"
cat "$TEMP" > /opt/dashboard/index.html
envsubst '$POCKER_PAGE_TITLE' < /opt/dashboard/response.html > "$TEMP"
cat "$TEMP" > /opt/dashboard/response.html
