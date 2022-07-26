#!/bin/sh

# Read form data and translate url symbols
OIFS=$IFS
IFS='&'
for i in $1; do
        (echo "$i" | grep -wq "username") && USERNAME="$(echo "$i" | cut -d "=" -f 2 | sed "s/+/ /g; s/%/\\\x/g")"
        (echo "$i" | grep -wq "password") && PASSWORD="$(echo "$i" | cut -d "=" -f 2 | sed "s/+/ /g; s/%/\\\x/g")"
        (echo "$i" | grep -wq "password_confirm") && PASSWORD_CONFIRM="$(echo "$i" | cut -d "=" -f 2 | sed "s/+/ /g; s/%/\\\x/g")"
        (echo "$i" | grep -wq "password_old") && PASSWORD_OLD="$(echo "$i" | cut -d "=" -f 2 | sed "s/+/ /g; s/%/\\\x/g")"
        (echo "$i" | grep -wq "type") && TYPE="$(echo "$i" | cut -d "=" -f 2 | sed "s/+/ /g; s/%/\\\x/g")"
done

# Expand hex symbols (use GNU printf)
USERNAME="$(/usr/bin/printf "$USERNAME")"
PASSWORD="$(/usr/bin/printf "$PASSWORD")"
PASSWORD_CONFIRM="$(/usr/bin/printf "$PASSWORD_CONFIRM")"
PASSWORD_OLD="$(/usr/bin/printf "$PASSWORD_OLD")"
TYPE="$(/usr/bin/printf "$TYPE")"

IFS=$OIFS

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$TYPE" ]; then
        echo "error: missing parameters!"
        exit 1
fi

# validate username
if ! (echo "$USERNAME" | grep -Eq "^[a-z0-9]+([\.\_\-]?[a-z0-9]+)*$"); then
        echo "error: invalid email user: \"$USERNAME\"!"
        echo "error: valid usernames contain characters  \".-_\", \"a-z\" and \"0-9\"."
        exit 1
fi

# Create user
if [ "$TYPE" = "create" ]; then
        if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                echo "error: passwords do not match!"
                exit 1
        fi
        if ! (email-user-add "$USERNAME" "$PASSWORD"); then
                echo "error: could not create user \"$USERNAME\""
                exit 1
        fi
        echo "info: user \"$USERNAME\" successfully created"
        exit 0

# Change password
elif [ "$TYPE" = "change" ]; then
        if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                echo "error: passwords do not match!"
                exit 1
        fi
        if ! (email-user-change-password "$USERNAME" "$PASSWORD_OLD" "$PASSWORD"); then
                echo "error: could not change password for user \"$USERNAME\""
                exit 1
        fi
        echo "info: successfully changed password for user \"$USERNAME\""
        exit 0

# Remove user
elif [ "$TYPE" = "remove" ]; then
        if ! (email-user-remove "$USERNAME" "$PASSWORD"); then
                echo "error: could not remove user \"$USERNAME\""
                exit 1
        fi
        echo "info: user \"$USERNAME\" successfully removed"
        exit 0
fi
