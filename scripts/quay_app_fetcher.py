#!/usr/bin/env python3
"""Scans freedesktop .desktop entries and prints them as JSON keyed by desktop id."""
import glob
import json
import os
import re
import sys

FIELD_CODES = re.compile(r'\s%[fFuUdDnNickvm]')

DIRS = [
    '/usr/share/applications',
    '/usr/local/share/applications',
    '~/.local/share/applications',
    '/var/lib/flatpak/exports/share/applications',
    '~/.local/share/flatpak/exports/share/applications',
    '~/.nix-profile/share/applications',
    '/run/current-system/sw/share/applications',
]


def parse_entry(path):
    entry = {
        'desktopId': os.path.splitext(os.path.basename(path))[0],
        'name': '',
        'exec': '',
        'icon': '',
        'wmClass': '',
        'categories': [],
        'terminal': False,
    }
    in_desktop_entry = False
    hidden = False

    with open(path, 'r', encoding='utf-8', errors='replace') as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith('['):
                in_desktop_entry = line == '[Desktop Entry]'
                continue
            if not in_desktop_entry or '=' not in line:
                continue

            key, _, value = line.partition('=')
            if key == 'Name' and not entry['name']:
                entry['name'] = value
            elif key == 'Exec' and not entry['exec']:
                entry['exec'] = FIELD_CODES.sub('', value).strip()
            elif key == 'Icon' and not entry['icon']:
                entry['icon'] = value
            elif key == 'StartupWMClass' and not entry['wmClass']:
                entry['wmClass'] = value
            elif key == 'Categories' and not entry['categories']:
                entry['categories'] = [c for c in value.split(';') if c]
            elif key == 'Terminal':
                entry['terminal'] = value.strip().lower() in ('true', '1')
            elif key in ('NoDisplay', 'Hidden') and value.strip().lower() in ('true', '1'):
                hidden = True

    if hidden or not entry['name'] or not entry['exec']:
        return None
    return entry


def fetch():
    apps = {}
    for directory in DIRS:
        directory = os.path.expanduser(directory)
        if not os.path.isdir(directory):
            continue
        for path in glob.glob(os.path.join(directory, '**/*.desktop'), recursive=True):
            try:
                entry = parse_entry(path)
            except OSError:
                continue
            # DIRS is ordered so user-level entries overwrite the system ones.
            if entry:
                apps[entry['desktopId']] = entry
    return apps


if __name__ == '__main__':
    json.dump(fetch(), sys.stdout)
    sys.stdout.write('\n')
