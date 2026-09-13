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

ACTION_PREFIX = '[Desktop Action '


def parse_entry(path):
    entry = {
        'desktopId': os.path.splitext(os.path.basename(path))[0],
        'name': '',
        'exec': '',
        # Exec= with its field codes kept, for opening dropped files.
        'execRaw': '',
        'icon': '',
        'wmClass': '',
        'categories': [],
        'terminal': False,
        'actions': [],
    }
    section = ''
    hidden = False
    action_ids = []
    actions = {}

    with open(path, 'r', encoding='utf-8', errors='replace') as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith('['):
                section = line
                continue
            if '=' not in line:
                continue

            key, _, value = line.partition('=')
            if section == '[Desktop Entry]':
                if key == 'Name' and not entry['name']:
                    entry['name'] = value
                elif key == 'Exec' and not entry['exec']:
                    entry['execRaw'] = value.strip()
                    entry['exec'] = FIELD_CODES.sub('', value).strip()
                elif key == 'Icon' and not entry['icon']:
                    entry['icon'] = value
                elif key == 'StartupWMClass' and not entry['wmClass']:
                    entry['wmClass'] = value
                elif key == 'Categories' and not entry['categories']:
                    entry['categories'] = [c for c in value.split(';') if c]
                elif key == 'Terminal':
                    entry['terminal'] = value.strip().lower() in ('true', '1')
                elif key == 'Actions':
                    action_ids = [a for a in value.split(';') if a]
                elif key in ('NoDisplay', 'Hidden') and value.strip().lower() in ('true', '1'):
                    hidden = True
            elif section.startswith(ACTION_PREFIX) and section.endswith(']'):
                action_id = section[len(ACTION_PREFIX):-1]
                action = actions.setdefault(action_id, {'id': action_id, 'name': '', 'exec': ''})
                if key == 'Name' and not action['name']:
                    action['name'] = value
                elif key == 'Exec' and not action['exec']:
                    action['exec'] = FIELD_CODES.sub('', value).strip()

    if hidden or not entry['name'] or not entry['exec']:
        return None

    # Only actions the entry lists in Actions=, in that order, and complete.
    entry['actions'] = [
        actions[a] for a in action_ids
        if a in actions and actions[a]['name'] and actions[a]['exec']
    ]
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
