# Public IP tracker

`myip.sh` checks the external IPv4 address and records changes in `ips.txt`.

It uses `dig` and `flock`. On Debian/Ubuntu, install them with:

```sh
sudo apt install dnsutils util-linux
```

The script tries Cloudflare DNS first and OpenDNS as a fallback. It is safe to
run from cron because overlapping executions are ignored. Unchanged checks are
silent; address changes are recorded in `ips.txt`.
The history file is restricted to its owner (`0600`).

Run it every minute with:

```cron
* * * * * /home/george/homelab/git_scripts/myip/myip.sh >/dev/null
```

Informational output is discarded, so no ever-growing log file is created.
Final failures remain on standard error for cron to report through its configured
mail mechanism. `ips.txt` contains only timestamps at which the address changed.

The defaults can be overridden with environment variables:

- `MYIP_FILE`: history file path
- `MYIP_MAX_ATTEMPTS`: positive number of lookup attempts
- `MYIP_RETRY_DELAY`: non-negative delay between attempts, in seconds
- `MYIP_CLOUDFLARE_DNS`: Cloudflare resolver address
- `MYIP_OPENDNS_DNS`: OpenDNS resolver address
