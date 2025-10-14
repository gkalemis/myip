#!/bin/bash

# Specify the filename
FILE="/home/george/useful/scripts/ips.txt"

# Check if file exists
if [ ! -f "$FILE" ]; then
    #echo "File does not exist. Creating $FILE..."
    touch "$FILE"
fi

# Store the last line in a variable
previous_ip=$(tail -n 1 "$FILE" | awk -F' - ' '{print $2}')

#echo "Previous ip was: $last_line"

current_ip=$(external-ip dns)

#echo "Current ip is: $result"

current_date=`date`

#echo "Current date is: $current_date"

timestamp=$(date +"%Y%m%d_%H%M%S")

#echo "Timestamp is: $timestamp"

if [[ "$previous_ip" != "$current_ip" ]]; then
       echo "$timestamp - $result" >> $FILE 
fi

