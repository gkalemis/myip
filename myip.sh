#!/bin/bash

# Specify the filename
FILE="$HOME/useful/scripts/myip/ips2.txt"
COMMAND="$(external-ip dns)"
ip="194.63.236.15"
max_retries=5
attempt=1
previous_ip=$(tail -n 1 "$FILE" | awk -F' - ' '{print $2}')

# Check if file exists
if [ ! -f "$FILE" ]; then
    #echo "File does not exist. Creating $FILE..."
    touch "$FILE"
fi


while ! $COMMAND >/dev/null 2>&1; do
    ((attempt++))
    if [ "$attempt" -gt "$max_retries" ]; then
    	exit 1
    fi
    sleep 9 
done

if $COMMAND >/dev/null 2>&1; then
	if [[ "$previous_ip" != "$COMMAND" ]]; then
       		echo "$timestamp - $current_ip"  
	fi
fi
