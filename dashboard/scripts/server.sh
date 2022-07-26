#!/bin/sh

STDIN="$(cat /dev/stdin)"

# Parse response
dir="$(dirname "$0")"

RESPONSE="$($dir/parser.sh "$STDIN" 2>&1)"

# Add list tags (<li>) to every line
# and add colors to "warning", "error" and "info" tags
FORMATTED_RESPONSE="$(echo "$RESPONSE" | sed 's/^/<li>/g; s/$/<\/li>/g; s/info:/<b style="color:#4287f5">info:<\/b>/g; s/warning:/<b style="color:#f5bc42">warning:<\/b>/g; s/error:/<b style="color:#f55742">error:<\/b>/g;')"

# Replace the HTML contents with response message
awk -v old="{{ contents }}" -v new="$FORMATTED_RESPONSE" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' "$dir"/server_response.html
