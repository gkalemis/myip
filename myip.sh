#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly FILE="${MYIP_FILE:-$SCRIPT_DIR/ips.txt}"
readonly MAX_ATTEMPTS="${MYIP_MAX_ATTEMPTS:-5}"
readonly RETRY_DELAY="${MYIP_RETRY_DELAY:-7}"
readonly CLOUDFLARE_DNS="${MYIP_CLOUDFLARE_DNS:-1.0.0.1}"
readonly OPENDNS_DNS="${MYIP_OPENDNS_DNS:-208.67.222.222}"

if [[ ! $MAX_ATTEMPTS =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: MYIP_MAX_ATTEMPTS must be a positive integer." >&2
    exit 2
fi

if [[ ! $RETRY_DELAY =~ ^[0-9]+$ ]]; then
    echo "Error: MYIP_RETRY_DELAY must be a non-negative integer." >&2
    exit 2
fi

if ! command -v dig >/dev/null 2>&1; then
    echo "Error: dig is required but was not found in PATH." >&2
    exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
    echo "Error: flock is required but was not found in PATH." >&2
    exit 1
fi

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

first_valid_ipv4() {
    local candidate

    while IFS= read -r candidate; do
        candidate=${candidate//\"/}
        if is_valid_ipv4 "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

get_public_ip() {
    local output

    # Capture all output so an early-exiting filter cannot trigger SIGPIPE under pipefail.
    output=$(dig \
        +short \
        +time=5 \
        +tries=1 \
        TXT \
        CH \
        whoami.cloudflare \
        "@$CLOUDFLARE_DNS" 2>/dev/null) || output=""

    if first_valid_ipv4 <<< "$output"; then
        return 0
    fi

    output=$(dig \
        +short \
        +time=5 \
        +tries=1 \
        A \
        myip.opendns.com \
        "@$OPENDNS_DNS" 2>/dev/null) || output=""

    first_valid_ipv4 <<< "$output"
}

# Lock the history file itself, avoiding predictable shared lock files in /tmp.
exec 9>>"$FILE"
flock -n 9 || exit 0
chmod 600 "$FILE"

previous_ip=$(
    awk -F' - ' '
        NF >= 2 {
            ip = $NF
            gsub(/[[:space:]]/, "", ip)
        }
        END { print ip }
    ' "$FILE"
)

if [[ -n $previous_ip ]] && ! is_valid_ipv4 "$previous_ip"; then
    echo "Warning: ignoring invalid previous IP in $FILE." >&2
    previous_ip=""
fi

current_ip=""

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    if current_ip=$(get_public_ip); then
        :
    else
        current_ip=""
    fi

    if is_valid_ipv4 "$current_ip"; then
        break
    fi

    current_ip=""

    if ((attempt < MAX_ATTEMPTS)); then
        sleep "$RETRY_DELAY"
    fi
done

if [[ -z $current_ip ]]; then
    echo "Error: could not determine the current IP after $MAX_ATTEMPTS attempts." >&2
    exit 1
fi

if [[ $previous_ip == "$current_ip" ]]; then
    exit 0
fi

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
printf '%s - %s\n' "$timestamp" "$current_ip" >> "$FILE"

if [[ -n $previous_ip ]]; then
    echo "IP changed from $previous_ip to $current_ip."
else
    echo "Initial IP address recorded."
fi
