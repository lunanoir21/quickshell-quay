#!/usr/bin/env bash
# Quay's settings store. Every write goes through here so that the whole
# read-modify-write cycle sits inside one cross-process lock: two callers
# (the in-widget panel and a drag that just finished, say) would otherwise
# each write a complete file containing only their own change, and the second
# mv would silently discard the first.
set -euo pipefail

settings_file="${QUAY_SETTINGS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/quay/settings.json}"
action="${1:-get}"

defaults() {
    cat <<'JSON'
{
  "schemaVersion": 1,
  "appearance": {
    "theme": "black"
  },
  "trigger": {
    "mode": "hover",
    "edge": "right",
    "hoverRevealDelayMs": 90,
    "hoverHideDelayMs": 400,
    "hideOnFullscreen": true
  },
  "layout": {
    "columns": 1,
    "rows": 6,
    "iconSize": 52,
    "spacing": 10
  },
  "content": {
    "extras": "running",
    "recentLimit": 4
  },
  "previews": {
    "mode": "beside",
    "delayMs": 400
  },
  "items": [],
  "recent": []
}
JSON
}

option_paths='["appearance.theme","trigger.mode","trigger.edge","trigger.hoverRevealDelayMs","trigger.hoverHideDelayMs","trigger.hideOnFullscreen","layout.columns","layout.rows","layout.iconSize","layout.spacing","content.extras","content.recentLimit","previews.mode","previews.delayMs"]'

_lock_held=0
with_lock() {
    [[ "$_lock_held" == "1" ]] && return 0
    mkdir -p "$(dirname "$settings_file")"
    exec 200>"$settings_file.lock"
    flock -w 5 200 || {
        printf 'quay_store: could not lock %s.lock\n' "$settings_file" >&2
        exit 3
    }
    _lock_held=1
}

# Reads always go through the defaults so a missing file or a half-written
# key still yields a complete, renderable document.
read_all() {
    if [[ -f "$settings_file" ]]; then
        jq -c --argjson d "$(defaults)" '$d * .' "$settings_file" 2>/dev/null || defaults | jq -c .
    else
        defaults | jq -c .
    fi
}

write_all() {
    local document="$1"
    local temp_file
    with_lock
    temp_file="$(mktemp "$settings_file.quay.XXXXXX")"
    printf '%s' "$document" | jq . > "$temp_file"
    [[ -f "$settings_file" ]] && chmod --reference="$settings_file" "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$settings_file"
}

require_arg() {
    [[ -n "${1:-}" ]] || {
        printf 'quay_store: missing argument for %s\n' "$action" >&2
        exit 2
    }
}

case "$action" in
    get)
        # First run materialises the file, so the settings watcher has
        # something real to watch from then on.
        if [[ ! -f "$settings_file" ]]; then
            with_lock
            write_all "$(defaults | jq -c .)"
        fi
        read_all
        ;;

    get-items)
        read_all | jq -c '.items'
        ;;

    set-items)
        items="${2:-}"
        require_arg "$items"
        with_lock
        write_all "$(read_all | jq -c --argjson items "$items" '.items = $items')"
        read_all | jq -c '.items'
        ;;

    set-recent)
        recent="${2:-}"
        require_arg "$recent"
        with_lock
        write_all "$(read_all | jq -c --argjson recent "$recent" '.recent = $recent')"
        ;;

    get-option)
        path="${2:-}"
        require_arg "$path"
        read_all | jq -c --arg p "$path" 'getpath($p | split("."))'
        ;;

    set-option)
        path="${2:-}"
        value="${3:-}"
        require_arg "$path"
        require_arg "$value"
        # Allowlisted paths only: a buggy caller must not be able to graft
        # arbitrary keys into the document.
        if ! jq -ne --arg p "$path" --argjson allowed "$option_paths" \
                 '$allowed | index($p) != null' >/dev/null; then
            printf 'quay_store: unknown option path: %s\n' "$path" >&2
            exit 2
        fi
        with_lock
        write_all "$(read_all | jq -c --arg p "$path" --argjson v "$value" \
            'setpath($p | split("."); $v)')"
        read_all | jq -c --arg p "$path" 'getpath($p | split("."))'
        ;;

    reset)
        with_lock
        write_all "$(defaults | jq -c .)"
        ;;

    *)
        printf 'quay_store: unknown action: %s\n' "$action" >&2
        printf 'usage: quay_store.sh [get|get-items|set-items <json>|get-option <path>|set-option <path> <json>|reset]\n' >&2
        exit 2
        ;;
esac
