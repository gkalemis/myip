#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly FILE="$SCRIPT_DIR/ips.txt"
readonly MAX_ATTEMPTS=5
readonly RETRY_DELAY=7
readonly LOCK_FILE="/tmp/myip.lock"
readonly CLOUDFLARE_DNS=1.0.0.1
readonly OPENDNS_DNS=208.67.222.222

if ! command -v dig >/dev/null 2>&1; then
    echo "Error: dig is required but was not found in PATH." >&2
    exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
    echo "Error: flock is required but was not found in PATH." >&2
    exit 1
fi

# Prevent overlapping cron invocations from writing duplicate entries.
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# Ensure the destination directory and file exist.
mkdir -p "$(dirname "$FILE")"
touch "$FILE"

previous_ip=$(
    awk -F' - ' '
        NF >= 2 {
            ip = $NF
            gsub(/[[:space:]]/, "", ip)
        }
        END { print ip }
    ' "$FILE"
)

get_public_ip() {
    local ip

    # Cloudflare TXT lookup.
    ip=$(dig \
        +short \
        +time=5 \
        +tries=1 \
        TXT \
        CH \
        whoami.cloudflare \
        "@$CLOUDFLARE_DNS" 2>/dev/null |
        tr -d '"' |
        head -n 1) || ip=""

    if is_valid_ipv4 "$ip"; then
        printf '%s\n' "$ip"
        return 0
    fi

    # OpenDNS A-record fallback.
    ip=$(dig \
        +short \
        +time=5 \
        +tries=1 \
        A \
        myip.opendns.com \
        "@$OPENDNS_DNS" 2>/dev/null |
        head -n 1) || ip=""

    if is_valid_ipv4 "$ip"; then
        printf '%s\n' "$ip"
        return 0
    fi

    return 1
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
    if current_ip=$(get_public_ip); then
        :
    else
        current_ip=""
    fi

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
