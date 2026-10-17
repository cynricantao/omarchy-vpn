# VPN Connections — native Omarchy plugin

Compact VPN bar widget for WireGuard and NetworkManager profiles: one row per saved
profile with live status, the config file name (full path on hover) and right-aligned
Enable/Disable buttons. Enable/Disable activates or deactivates the connection; it does
not change autoconnect settings.

- Read-only metadata: the backend runs `nmcli -t -f NAME,UUID,TYPE,STATE,DEVICE,FILENAME connection show` with `LC_ALL=C` and lists only WireGuard/VPN rows. No passwords, private keys or other secrets are read.
- Actions pass the connection UUID as an argv element to `nmcli --wait 30 connection up|down uuid <uuid>` — never through a shell.
- Polls every 3 s and on open; middle-click refreshes. Shows `Status unavailable` when NetworkManager can't be reached.
- IPC: `omarchy-shell cynricantao.vpn status|toggle|open|close`.

## Requirements

NetworkManager (`nmcli`) with WireGuard/VPN profiles configured.

## Install

```sh
omarchy plugin add https://github.com/cynricantao/omarchy-vpn.git
```

## Tests

```sh
python3 test_backend.py
omarchy plugin validate .
```

## Limitations

- Status reflects NetworkManager's view of the connection, not a traffic-level health check — an activated interface does not by itself prove a working handshake.
- Requires NetworkManager; setups that manage VPNs elsewhere are not supported.

This is a community plugin maintained by cynricantao; it is not affiliated with Omarchy,
NetworkManager or WireGuard.
