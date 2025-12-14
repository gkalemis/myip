#!/bin/bash

# Specify the filename
FILE="$HOME/scripts/myip/ips.txt"

# Check if file exists
if [ ! -f "$FILE" ]; then
    #echo "File does not exist. Creating $FILE..."
    touch "$FILE"
fi

#echo "Previous ip was: $last_line"
previous_ip=$(tail -n 1 "$FILE" | awk -F' - ' '{print $2}')

#echo "Timestamp is: $timestamp"
timestamp=$(date +"%Y-%m-%d %H:%M:%S")

max_attempts=5
attempt=0

while [[ $attempt -lt $max_attempts ]]; do
    #echo "Current ip is: $result"
    current_ip=$(dig +short txt ch whoami.cloudflare @1.0.0.1 | tr -d '"')
    if [[ $current_ip == *"error"* ]]; then
        current_ip=""
    fi
    if [ -n "$current_ip" ]; then
        echo "Current ip is: $current_ip"
        break  # Exit the loop if the ping is successful
    else
        echo "Current ip cannot be found after $((attempt + 1)) attempts. Retrying in 7 seconds..."
        ((attempt++))
        sleep 7
    fi
done

if [[ $attempt -eq $max_attempts ]]; then
    echo "Current ip cannot be found after $max_attempts attempts."
    exit 1  # Exit the script if all attempts fail
else
        # Write the new ip to the file
        if [[ "$previous_ip" != "$current_ip" ]]; then
                echo "$timestamp - $current_ip" >> $FILE
        fi
fi
