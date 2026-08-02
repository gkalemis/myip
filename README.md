# Public IP tracker

`myip.sh` checks the external IPv4 address and records changes in `ips.txt`.

It uses `dig` and `flock`. On Debian/Ubuntu, install them with:

```sh
sudo apt install dnsutils util-linux
```

The script tries Cloudflare DNS first and OpenDNS as a fallback. It is safe to
run from cron because overlapping executions are ignored.

Run it every minute with:

```cron
* * * * * /home/george/scripts/myip/myip.sh >> /home/george/scripts/myip/myip.log 2>&1
```

The log file contains status messages and errors from cron. `ips.txt` contains
only timestamps at which the address changed.
