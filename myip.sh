#!/bin/bash

# Specify the filename
FILE="$HOME/useful/scripts/ips.txt"

# Check if file exists
if [ ! -f "$FILE" ]; then
    #echo "File does not exist. Creating $FILE..."
    touch "$FILE"
fi

ip="62.103.146.102"

# Store the last line in a variable
previous_ip=$(tail -n 1 "$FILE" | awk -F' - ' '{print $2}')

#echo "Previous ip was: $last_line"

current_ip=$(external-ip dns)

#echo "Current ip is: $result"

timestamp=$(date +"%Y-%m-%d %H:%M:%S")

#echo "Timestamp is: $timestamp"

max_retries=5
attempt=1

while ! ping -c 1 "$ip" >/dev/null 2>&1; do
    #echo "Ping failed (attempt $attempt/$max_retries)"
    ((attempt++))
    if [ "$attempt" -gt "$max_retries" ]; then
        echo "Ping to $ip failed after $max_retries attempts. Exiting." >> $FILE
        exit 1
    fi
    sleep 120
done

if [[ "$previous_ip" != "$current_ip" ]]; then
       echo "$timestamp - $current_ip" >> $FILE 
fi
