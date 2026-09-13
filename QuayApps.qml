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

    function nameFor(id) {
        let entry = root.entryFor(id);
        return entry ? entry.name : id;
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
        Quickshell.execDetached(["sh", "-c", entry.exec]);
    }

    // One of the entry's own [Desktop Action] shortcuts, e.g. a private window.
    function launchAction(id, actionId) {
        let entry = root.entryFor(id);
        if (!entry || !entry.actions) return;
        let action = entry.actions.find(candidate => candidate.id === actionId);
        if (action) Quickshell.execDetached(["sh", "-c", action.exec]);
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
                Quickshell.execDetached(["sh", "-c", expand([paths[i]], [links[i]])]);
        } else {
            Quickshell.execDetached(["sh", "-c", expand(paths, links)]);
        }
        return true;
    }

    function refresh() {
        fetcher.running = true;
    }

    Process {
        id: fetcher
        running: true
        command: ["python3", QuayStore.moduleDir + "scripts/quay_app_fetcher.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = String(this.text || "").trim();
                    if (!text) return;
                    root.entries = JSON.parse(text);
                } catch (e) {
                    console.warn("Quay: could not parse desktop entry index:", e);
                }
            }
        }
    }
}
