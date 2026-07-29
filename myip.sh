#!/usr/bin/env bash

set -u
set -o pipefail

readonly FILE="$HOME/scripts/myip/ips.txt"
readonly MAX_ATTEMPTS=5
readonly RETRY_DELAY=7
readonly DNS_SERVER=1.0.0.1

# Ensure the destination directory and file exist.
mkdir -p "$(dirname "$FILE")"
touch "$FILE"

previous_ip=$(awk -F' - ' 'NF >= 2 {ip=$NF} END {print ip}' "$FILE")

get_public_ip() {
    dig \
        +short \
        +time=5 \
        +tries=1 \
        TXT \
        CH \
        whoami.cloudflare \
        "@$DNS_SERVER" 2>/dev/null |
        tr -d '"' |
        head -n 1
}

is_valid_ipv4() {
    local ip=$1
    local octet
    local -a octets

    IFS=. read -r -a octets <<< "$ip"

    [[ ${#octets[@]} -eq 4 ]] || return 1

    for octet in "${octets[@]}"; do
        [[ $octet =~ ^[0-9]{1,3}$ ]] || return 1
        ((10#$octet >= 0 && 10#$octet <= 255)) || return 1
    done
}

current_ip=""

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    current_ip=$(get_public_ip)

    if is_valid_ipv4 "$current_ip"; then
        echo "Current IP is: $current_ip"
        break
    fi

    current_ip=""

    if ((attempt < MAX_ATTEMPTS)); then
        echo "Could not determine the current IP on attempt $attempt/$MAX_ATTEMPTS."
        echo "Retrying in $RETRY_DELAY seconds..."
        sleep "$RETRY_DELAY"
    fi
done

if [[ -z $current_ip ]]; then
    echo "Error: could not determine the current IP after $MAX_ATTEMPTS attempts." >&2
    exit 1
fi

if [[ $previous_ip == "$current_ip" ]]; then
    echo "IP address has not changed."
    exit 0
fi

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
printf '%s - %s\n' "$timestamp" "$current_ip" >> "$FILE"

if [[ -n $previous_ip ]]; then
    echo "IP changed from $previous_ip to $current_ip."
else
    echo "Initial IP address recorded."
fi
