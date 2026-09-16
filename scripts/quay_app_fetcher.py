#!/usr/bin/env python3
"""Scans freedesktop .desktop entries and prints them as JSON keyed by desktop id.

The application directories in DIRS are not Quay's own: a Flatpak or Nix
profile, or a hand-edited ~/.local/share/applications, can be arbitrarily
large or contain a symlink cycle. Every step here is bounded so a hostile
or merely huge tree can't make this run forever or exhaust memory: symlinked
subdirectories are never entered, only regular files are opened (never a
FIFO or socket, which a blocking read on could hang indefinitely), and file
count, path depth, per-line length and total bytes read are all capped.
"""
import json
import os
import re
import stat
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

# Ceilings on the scan as a whole: how many .desktop files to look at, how
# deep to recurse into any one directory, and how many bytes to read across
# every file combined.
MAX_FILES = 20000
MAX_DEPTH = 20
MAX_TOTAL_BYTES = 32 * 1024 * 1024

# Ceilings on a single file: how many bytes of it to read, how long a single
# line may be before it's cut off, and how long a single field or how many
# actions to keep from it.
MAX_FILE_BYTES = 256 * 1024
MAX_LINE_BYTES = 8192
MAX_FIELD_LEN = 1024
MAX_LIST_LEN = 32
MAX_ACTIONS = 16


def _truncate(value):
    return value[:MAX_FIELD_LEN]


def _open_regular(path):
    """Opens `path` for reading and returns the file descriptor, or None.

    Follows a file symlink — Flatpak's exports directory is one big farm of
    them — but never blocks on, or reads from, anything but a regular file.
    O_NONBLOCK makes opening a FIFO return immediately instead of waiting for
    a writer that may never come; the type is then checked with fstat on the
    descriptor actually opened, not a separate stat() of the path beforehand,
    which would leave a race between the check and the open.
    """
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        return None
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            os.close(fd)
            return None
    except OSError:
        os.close(fd)
        return None
    return fd


def parse_entry(path, total_budget):
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
    file_bytes = 0

    fd = _open_regular(path)
    if fd is None:
        return None

    with os.fdopen(fd, 'r', encoding='utf-8', errors='replace') as handle:
        while file_bytes < MAX_FILE_BYTES and total_budget[0] > 0:
            # A size-bounded readline, not `for raw in handle`: a file with
            # no newline at all would otherwise be read into memory as one
            # unbounded line before the loop body ever runs.
            raw = handle.readline(MAX_LINE_BYTES)
            if not raw:
                break
            file_bytes += len(raw)
            total_budget[0] -= len(raw)
            line = raw.strip()
            if line.startswith('['):
                section = line
                continue
            if '=' not in line:
                continue

            key, _, value = line.partition('=')
            value = _truncate(value)
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
                    entry['categories'] = [c for c in value.split(';') if c][:MAX_LIST_LEN]
                elif key == 'Terminal':
                    entry['terminal'] = value.strip().lower() in ('true', '1')
                elif key == 'Actions':
                    action_ids = [a for a in value.split(';') if a][:MAX_LIST_LEN]
                elif key in ('NoDisplay', 'Hidden') and value.strip().lower() in ('true', '1'):
                    hidden = True
            elif (section.startswith(ACTION_PREFIX) and section.endswith(']')
                    and len(actions) < MAX_ACTIONS):
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


def _desktop_files(directory):
    """Yields candidate .desktop paths under `directory`, without ever
    descending into a symlinked subdirectory or past MAX_DEPTH. Whether a
    path is actually safe to open is decided later, by _open_regular — a
    stat() here would only duplicate that check racily."""
    base_depth = directory.rstrip(os.sep).count(os.sep)
    for root, dirs, files in os.walk(directory, followlinks=False):
        if root.rstrip(os.sep).count(os.sep) - base_depth >= MAX_DEPTH:
            dirs[:] = []
            continue
        for name in files:
            if name.endswith('.desktop'):
                yield os.path.join(root, name)


def fetch():
    apps = {}
    files_left = MAX_FILES
    total_budget = [MAX_TOTAL_BYTES]

    for directory in DIRS:
        directory = os.path.expanduser(directory)
        if not os.path.isdir(directory):
            continue
        for path in _desktop_files(directory):
            if files_left <= 0 or total_budget[0] <= 0:
                return apps
            files_left -= 1
            try:
                entry = parse_entry(path, total_budget)
            except OSError:
                continue
            # DIRS is ordered so user-level entries overwrite the system ones.
            if entry:
                apps[entry['desktopId']] = entry
    return apps


if __name__ == '__main__':
    json.dump(fetch(), sys.stdout)
    sys.stdout.write('\n')
