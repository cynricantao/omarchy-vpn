"""Read only non-secret NetworkManager profile metadata."""
import json
import os
import subprocess


def parse_profiles(raw):
    profiles = []
    for line in raw.splitlines():
        fields, value, escaped = [], '', False
        for char in line:
            if escaped:
                value += char
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == ':':
                fields.append(value)
                value = ''
            else:
                value += char
        fields.append(value)
        if len(fields) != 6 or fields[2] not in ('wireguard', 'vpn'):
            continue
        name, uuid, kind, state, device, filename = fields
        profiles.append(dict(name=name, uuid=uuid, type=kind,
                             state=state or 'disconnected', active=state == 'activated',
                             device=device, file=filename or 'No persistent file reported'))
    return profiles


def snapshot():
    result = subprocess.run(
        ['nmcli', '-t', '-f', 'NAME,UUID,TYPE,STATE,DEVICE,FILENAME', 'connection', 'show'],
        capture_output=True, text=True, timeout=10, env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'NetworkManager is unavailable')
    return {'ok': True, 'profiles': parse_profiles(result.stdout)}


if __name__ == '__main__':
    try:
        print(json.dumps(snapshot()))
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
        print(json.dumps({'ok': False, 'profiles': [], 'error': str(error)}))
