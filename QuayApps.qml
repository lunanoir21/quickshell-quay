pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Desktop-entry index, keyed by desktop id.
Singleton {
    id: root

    property var entries: ({})

    readonly property var sortedEntries: {
        let list = [];
        for (let id in root.entries) list.push(root.entries[id]);
        list.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        return list;
    }

    function entryFor(id) {
        if (!id) return null;
        let direct = root.entries[id];
        if (direct) return direct;

        let wanted = String(id).toLowerCase();
        for (let key in root.entries) {
            let entry = root.entries[key];
            if (key.toLowerCase() === wanted) return entry;
            if (entry.wmClass && entry.wmClass.toLowerCase() === wanted) return entry;
        }
        return null;
    }

    // Falls back to the raw id (a compositor app-id, say) when no desktop
    // entry matches — that id is as externally controlled as a window title,
    // so it gets the same length bound before it reaches a Text element.
    function nameFor(id) {
        let entry = root.entryFor(id);
        if (entry) return entry.name;
        return String(id || "").slice(0, 200);
    }

    // Absolute paths come straight off disk; bare names are resolved against
    // the icon theme with a check, because the unchecked provider hands back a
    // placeholder checkerboard for names it cannot find.
    function iconSource(icon) {
        if (!icon) return "";
        if (String(icon).startsWith("/")) return "file://" + icon;
        return Quickshell.iconPath(icon, true) || "";
    }

    function iconSourceFor(id) {
        let entry = root.entryFor(id);
        return entry ? root.iconSource(entry.icon) : "";
    }

    // Runs the desktop entry's own Exec= line through a shell rather than a
    // compositor-specific dispatcher, so launching works under any wlr-layer-
    // shell compositor Quay runs on, not just Hyprland.
    function launch(id) {
        let entry = root.entryFor(id);
        if (!entry) return;
        root.run(entry, entry.exec);
    }

    // One of the entry's own [Desktop Action] shortcuts, e.g. a private window.
    function launchAction(id, actionId) {
        let entry = root.entryFor(id);
        if (!entry || !entry.actions) return;
        let action = entry.actions.find(candidate => candidate.id === actionId);
        if (action) root.run(entry, action.exec);
    }

    // A Terminal=true entry (btop, Vim) has no window of its own and needs a
    // terminal to run in: $TERMINAL if set, then xdg-terminal-exec, then the
    // first common terminal installed. The command arrives as $1, unquoted by
    // nothing, so it survives any quoting of its own.
    readonly property string terminalScript: [
        'cmd=$1',
        'term=',
        'if [ -n "${TERMINAL:-}" ] && command -v "${TERMINAL%% *}" >/dev/null 2>&1; then',
        '  term=$TERMINAL',
        'elif command -v xdg-terminal-exec >/dev/null 2>&1; then',
        '  exec xdg-terminal-exec sh -c "$cmd"',
        'else',
        '  for t in kitty foot alacritty wezterm ghostty konsole gnome-terminal xfce4-terminal xterm; do',
        '    if command -v "$t" >/dev/null 2>&1; then term=$t; break; fi',
        '  done',
        'fi',
        '[ -n "$term" ] || { echo "quay: no terminal found for a Terminal=true entry" >&2; exit 127; }',
        'case "${term%% *}" in',
        '  kitty|foot) exec $term sh -c "$cmd" ;;',
        '  wezterm) exec $term start -- sh -c "$cmd" ;;',
        '  gnome-terminal) exec $term -- sh -c "$cmd" ;;',
        '  xfce4-terminal) exec $term -x sh -c "$cmd" ;;',
        '  *) exec $term -e sh -c "$cmd" ;;',
        'esac'
    ].join("\n")

    function run(entry, command) {
        if (entry.terminal) Quickshell.execDetached(["sh", "-c", root.terminalScript, "quay-launch", command]);
        else Quickshell.execDetached(["sh", "-c", command]);
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    // Opens dropped files with the entry by expanding its Exec= field codes.
    // An entry that takes a single %f or %u is started once per file, as the
    // desktop entry spec asks; one with no file field code gets the paths
    // appended, which is what a drop is expected to do.
    function openWith(id, urls) {
        let entry = root.entryFor(id);
        if (!entry || !urls || urls.length === 0) return false;

        let raw = entry.execRaw || entry.exec;
        let links = [];
        for (let i = 0; i < urls.length; i++) links.push(String(urls[i]));
        let paths = links.map(link => link.startsWith("file://") ? decodeURIComponent(link.slice(7)) : link);

        let expand = (files, uris) => {
            let used = false;
            let command = raw.replace(/%[fFuUdDnNickvm%]/g, code => {
                if (code === "%%") return "%";
                if (code === "%f" || code === "%F") {
                    used = true;
                    return files.map(file => root.shellQuote(file)).join(" ");
                }
                if (code === "%u" || code === "%U") {
                    used = true;
                    return uris.map(uri => root.shellQuote(uri)).join(" ");
                }
                return "";
            });
            return used ? command : command + " " + files.map(file => root.shellQuote(file)).join(" ");
        };

        if (/%[fu]/.test(raw) && paths.length > 1) {
            for (let i = 0; i < paths.length; i++)
                root.run(entry, expand([paths[i]], [links[i]]));
        } else {
            root.run(entry, expand(paths, links));
        }
        return true;
    }

    function refresh() {
        fetcher.running = true;
    }

    // The fetcher script bounds what it reads, but not everything that could
    // go wrong is on its side of the pipe — a stuck network mount, say. This
    // is the backstop: kill a scan that runs too long, and refuse to parse
    // one that somehow still produced more text than a real system would.
    readonly property int fetchTimeoutMs: 8000
    readonly property int maxStdoutBytes: 16 * 1024 * 1024

    Timer {
        id: fetchDeadline
        interval: root.fetchTimeoutMs
        onTriggered: {
            console.warn("Quay: desktop entry scan did not finish in time, stopping it");
            fetcher.running = false;
        }
    }

    Process {
        id: fetcher
        running: true
        command: ["python3", QuayStore.moduleDir + "scripts/quay_app_fetcher.py"]

        onRunningChanged: {
            if (fetcher.running) fetchDeadline.restart();
            else fetchDeadline.stop();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = String(this.text || "").trim();
                    if (!text) return;
                    if (text.length > root.maxStdoutBytes) {
                        console.warn("Quay: desktop entry scan produced too much output, ignoring it");
                        return;
                    }
                    root.entries = JSON.parse(text);
                } catch (e) {
                    console.warn("Quay: could not parse desktop entry index:", e);
                }
            }
        }
    }
}
