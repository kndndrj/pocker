#!/bin/sh

# fn_create <user> <password>
fn_create () {
    user="$1"
    pass="$2"

    # Validate username
    if ! (echo "$user" | grep -Eq "^[a-z0-9]+([\.\_\-]?[a-z0-9]+)*$"); then
        echo "error: invalid email user: \"$user\"!"
        echo "error: valid usernames contain characters  \".-_\", \"a-z\" and \"0-9\"."
        return 1
    fi
    # Add user
    if ! (adduser -D "$user"); then
        echo "error: could not create user \"$user\""
        return 1
    fi
    # Add password
    if ! (echo "$user:$pass" | chpasswd > /dev/null 2&>1); then
        echo "error: could not create user \"$user\""
        return 1
    fi
    # Add user to "mail" group
    if ! (adduser "$user" mail); then
        echo "error: could not create user \"$user\""
        return 1
    fi
    echo "info: user \"$user\" successfully created"
}

# fn_remove <user> <old_password> <new_password>
fn_change_pw () {
    user="$1"
    pass_old="$2"
    pass_new="$3"

    # Authenticate user - auth_checker
    temp="$(mktemp)"
    echo "$pass_old" > "$temp"
    chmod +r "$temp"
    if ! (su auth_checker -c "cat $temp | su $user" 2>/dev/null);then
        rm -rf "$temp"
        echo "error: wrong password or the user doesn't exist!"
        return 1
    fi
    rm -rf "$temp"

    # Change password
    if ! (echo "$user:$pass_new" | chpasswd > /dev/null 2&>1); then
        echo "error: could not create user \"$user\""
        return 1
    fi
    echo "info: successfully changed password for user \"$user\""
}

# fn_remove <user> <password>
fn_remove () {
    user="$1"
    pass="$2"

    # Authenticate user - auth_checker
    temp="$(mktemp)"
    echo "$pass" > "$temp"
    chmod +r "$temp"
    if ! (su auth_checker -c "cat $temp | su $user" 2>/dev/null);then
        rm -rf "$temp"
        echo "error: wrong password or the user doesn't exist!"
        return 1
    fi
    rm -rf "$temp"

    # Remove user
    rm -rf /var/mail/"${user:?}" /home/"${user:?}"
    if ! (deluser "$user"); then
        echo "error: could not remove user \"$user\""
        return 1
    fi
    echo "info: user \"$user\" successfully removed"
}

# fn_parse_response
fn_parse_response () {

    # Capture stdin
    STDIN="$(cat /dev/stdin)"

    # Read form data and translate url symbols
    OIFS=$IFS
    IFS='&'
    for i in $STDIN; do
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
        return 1
    fi

    case "$TYPE" in
      create)
          if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
              echo "error: passwords do not match!"
              return 1
          fi
          fn_create "$USERNAME" "$PASSWORD"
      ;;

      change)
          if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
              echo "error: passwords do not match!"
              return 1
          fi
          fn_change_pw "$USERNAME" "$PASSWORD_OLD" "$PASSWORD"
      ;;

      remove)
          fn_remove "$USERNAME" "$PASSWORD"
      ;;

      *)
          echo "error: invalid action type"
      ;;
    esac

}

# fn_format <message_to_format>
# Add list tags (<li>) to every line
# and add colors to "warning", "error" and "info" tags
fn_format () {
    formatted="$(echo "$1" | sed '
        s/^/<li>/g;
        s/$/<\/li>/g;
        s/info:/<b style="color:#4287f5">info:<\/b>/g;
        s/warning:/<b style="color:#f5bc42">warning:<\/b>/g;
        s/error:/<b style="color:#f55742">error:<\/b>/g;
        ')"

    # Replace the HTML contents with response message
    awk -v old="{{ contents }}" -v new="$formatted" \
        's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' \
        "$(dirname "$0")"/response.html
}


# Parse response
RESPONSE="$(fn_parse_response 2>&1)"

# Format response and print the output
fn_format "$RESPONSE"

