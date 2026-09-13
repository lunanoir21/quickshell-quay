pragma Singleton

import QtQuick
import Quickshell

// Merges the persisted layout with live window state into the single list the
// views render, and owns every mutation of that layout.
Singleton {
    id: root

    readonly property var pinnedItems: {
        let items = (QuayStore.items || []).slice();
        items.sort((a, b) => (a.position || 0) - (b.position || 0));
        return items;
    }

    readonly property var pinnedIds: {
        let ids = [];
        let items = root.pinnedItems;
        for (let i = 0; i < items.length; i++) {
            let item = items[i];
            if (item.type === "folder") {
                let children = item.children || [];
                for (let c = 0; c < children.length; c++) ids.push(children[c].id);
            } else {
                ids.push(item.id);
            }
        }
        return ids;
    }

    // Pinned entries first, in the user's order. What follows them is the
    // user's choice: nothing, whatever else is open, or whatever was used last.
    readonly property var entries: {
        let out = [];
        let items = root.pinnedItems;

        for (let i = 0; i < items.length; i++) {
            let item = items[i];
            if (item.type === "folder") {
                out.push(root.describeFolder(item));
            } else {
                out.push(root.describeApp(item.id, true));
            }
        }

        let pinned = root.pinnedIds.map(id => String(id).toLowerCase());
        let candidates = [];

        if (QuayStore.extras === "running") {
            candidates = QuayWindows.runningIds;
        } else if (QuayStore.extras === "recent") {
            candidates = (QuayStore.recent || []).slice(0, QuayStore.recentLimit);
        }

        for (let c = 0; c < candidates.length; c++) {
            let entry = QuayApps.entryFor(candidates[c]);
            let id = entry ? entry.desktopId : String(candidates[c]);
            if (pinned.indexOf(String(id).toLowerCase()) !== -1) continue;
            if (out.some(existing => existing.type === "app" && existing.id === id)) continue;
            out.push(root.describeApp(id, false));
        }

        return out;
    }

    function describeApp(id, isPinned) {
        let entry = QuayApps.entryFor(id);
        return {
            "key": "app:" + id,
            "type": "app",
            "id": id,
            "name": entry ? entry.name : id,
            "iconSource": entry ? QuayApps.iconSource(entry.icon) : "",
            "isPinned": isPinned,
            "isRunning": QuayWindows.isRunning(id),
            "isActive": QuayWindows.isActive(id),
            "windowCount": QuayWindows.windowCount(id),
            "isLaunching": root.isLaunching(id),
            "children": []
        };
    }

    function describeFolder(item) {
        let children = (item.children || []).map(child => root.describeApp(child.id, true));
        let running = children.some(child => child.isRunning);
        return {
            "key": "folder:" + item.id,
            "type": "folder",
            "id": item.id,
            "name": item.name || qsTr("Folder"),
            "iconSource": "",
            "isPinned": true,
            "isRunning": running,
            "isActive": children.some(child => child.isActive),
            "windowCount": children.reduce((sum, child) => sum + child.windowCount, 0),
            "isLaunching": children.some(child => child.isLaunching),
            "children": children
        };
    }

    // --- launching --------------------------------------------------------

    // A launch stays pending until the app shows one more window than it had,
    // or gives up after a while. That drives the tile's pulse and swallows the
    // second click of an impatient double click.
    property var launching: ({})
    readonly property int launchTimeoutMs: 8000

    function launchKey(id) {
        return String(id).toLowerCase();
    }

    function isLaunching(id) {
        return root.launching[root.launchKey(id)] !== undefined;
    }

    function markLaunching(id) {
        // A terminal app's window belongs to the terminal, never to this id,
        // so its pulse could only ever time out.
        let entry = QuayApps.entryFor(id);
        if (entry && entry.terminal) return;
        let next = Object.assign({}, root.launching);
        next[root.launchKey(id)] = { "id": id, "windows": QuayWindows.windowCount(id), "at": Date.now() };
        root.launching = next;
    }

    function settleLaunches() {
        let keys = Object.keys(root.launching);
        if (keys.length === 0) return;
        let now = Date.now();
        let next = {};
        let changed = false;
        for (let i = 0; i < keys.length; i++) {
            let pending = root.launching[keys[i]];
            if (QuayWindows.windowCount(pending.id) > pending.windows || now - pending.at > root.launchTimeoutMs)
                changed = true;
            else
                next[keys[i]] = pending;
        }
        if (changed) root.launching = next;
    }

    Connections {
        target: QuayWindows
        function onGroupsChanged() {
            root.settleLaunches();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: Object.keys(root.launching).length > 0
        onTriggered: root.settleLaunches()
    }

    function activate(id) {
        if (QuayWindows.focus(id)) return;
        if (root.isLaunching(id)) return;
        root.launchNew(id);
    }

    // Always a new instance, even when the app already has windows.
    function launchNew(id) {
        if (!QuayApps.entryFor(id)) return;
        root.markLaunching(id);
        QuayApps.launch(id);
    }

    // Shortcuts and file drops only pulse for an app that isn't open yet: an
    // open one may well answer them without a new window (a new tab, say).
    function runAction(id, actionId) {
        if (!QuayWindows.isRunning(id)) root.markLaunching(id);
        QuayApps.launchAction(id, actionId);
    }

    function openFiles(id, urls) {
        let running = QuayWindows.isRunning(id);
        if (QuayApps.openWith(id, urls) && !running) root.markLaunching(id);
    }

    // --- layout mutations -------------------------------------------------

    function commit(items) {
        for (let i = 0; i < items.length; i++) items[i].position = i;
        QuayStore.setItems(items);
    }

    function isPinned(id) {
        return root.pinnedIds.map(p => String(p).toLowerCase()).indexOf(String(id).toLowerCase()) !== -1;
    }

    function pin(id) {
        if (root.isPinned(id)) return;
        let items = root.pinnedItems.slice();
        items.push({ "type": "app", "id": id, "position": items.length });
        root.commit(items);
    }

    function insertAt(id, index) {
        if (root.isPinned(id)) {
            let from = root.pinnedItems.findIndex(item => item.type === "app"
                && String(item.id).toLowerCase() === String(id).toLowerCase());
            if (from !== -1) root.move(from, index);
            return;
        }
        let items = root.pinnedItems.slice();
        let target = Math.max(0, Math.min(items.length, index));
        items.splice(target, 0, { "type": "app", "id": id });
        root.commit(items);
    }

    function unpin(id) {
        let wanted = String(id).toLowerCase();
        let items = [];
        let source = root.pinnedItems;

        for (let i = 0; i < source.length; i++) {
            let item = source[i];
            if (item.type === "folder") {
                let kept = (item.children || []).filter(child => String(child.id).toLowerCase() !== wanted);
                if (kept.length > 0) {
                    items.push({ "type": "folder", "id": item.id, "name": item.name, "children": kept });
                }
            } else if (String(item.id).toLowerCase() !== wanted) {
                items.push(item);
            }
        }
        root.commit(items);
    }

    function togglePin(id) {
        if (root.isPinned(id)) root.unpin(id);
        else root.pin(id);
    }

    function move(fromIndex, toIndex) {
        let items = root.pinnedItems.slice();
        if (fromIndex < 0 || fromIndex >= items.length) return;
        let clamped = Math.max(0, Math.min(items.length - 1, toIndex));
        if (clamped === fromIndex) return;
        items.splice(clamped, 0, items.splice(fromIndex, 1)[0]);
        root.commit(items);
    }

    function newFolderId() {
        return "folder-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1e6).toString(36);
    }

    // Dropping one icon onto another is the gesture that makes a folder, so
    // the two apps involved are removed from the top level and become its
    // first members.
    function groupInto(targetIndex, sourceIndex) {
        let items = root.pinnedItems.slice();
        if (targetIndex === sourceIndex) return;
        if (targetIndex < 0 || targetIndex >= items.length) return;
        if (sourceIndex < 0 || sourceIndex >= items.length) return;

        let target = items[targetIndex];
        let source = items[sourceIndex];
        if (source.type === "folder") return;

        if (target.type === "folder") {
            let children = (target.children || []).slice();
            children.push({ "type": "app", "id": source.id });
            items[targetIndex] = { "type": "folder", "id": target.id, "name": target.name, "children": children };
            items.splice(sourceIndex, 1);
        } else {
            items[targetIndex] = {
                "type": "folder",
                "id": root.newFolderId(),
                "name": qsTr("New folder"),
                "children": [{ "type": "app", "id": target.id }, { "type": "app", "id": source.id }]
            };
            items.splice(sourceIndex, 1);
        }
        root.commit(items);
    }

    readonly property var folders: root.pinnedItems.filter(item => item.type === "folder")

    function folderOf(id) {
        let wanted = String(id).toLowerCase();
        let found = root.folders.find(folder => (folder.children || [])
            .some(child => String(child.id).toLowerCase() === wanted));
        return found ? found.id : "";
    }

    // Moves an app into a folder from wherever it is: the top level, another
    // folder, or not pinned at all. An empty folderId makes a new folder in
    // the app's place (or at the end, if it had no place of its own).
    function moveToFolder(id, folderId) {
        let wanted = String(id).toLowerCase();
        let member = { "type": "app", "id": id };
        let items = [];
        let placed = false;
        let source = root.pinnedItems;

        for (let i = 0; i < source.length; i++) {
            let item = source[i];
            if (item.type === "folder") {
                let kept = (item.children || []).filter(child => String(child.id).toLowerCase() !== wanted);
                if (folderId && item.id === folderId) {
                    kept.push(member);
                    placed = true;
                }
                if (kept.length > 0) items.push({ "type": "folder", "id": item.id, "name": item.name, "children": kept });
            } else if (String(item.id).toLowerCase() === wanted) {
                if (!folderId) {
                    items.push({ "type": "folder", "id": root.newFolderId(), "name": qsTr("New folder"), "children": [member] });
                    placed = true;
                }
            } else {
                items.push(item);
            }
        }

        if (!placed) {
            if (folderId) return;
            items.push({ "type": "folder", "id": root.newFolderId(), "name": qsTr("New folder"), "children": [member] });
        }
        root.commit(items);
    }

    function renameFolder(folderId, name) {
        let items = root.pinnedItems.map(item => {
            if (item.type !== "folder" || item.id !== folderId) return item;
            return { "type": "folder", "id": item.id, "name": name, "children": item.children || [] };
        });
        root.commit(items);
    }

    function dissolveFolder(folderId) {
        let items = [];
        let source = root.pinnedItems;
        for (let i = 0; i < source.length; i++) {
            let item = source[i];
            if (item.type === "folder" && item.id === folderId) {
                let children = item.children || [];
                for (let c = 0; c < children.length; c++) items.push({ "type": "app", "id": children[c].id });
            } else {
                items.push(item);
            }
        }
        root.commit(items);
    }

    function removeFromFolder(folderId, id) {
        let wanted = String(id).toLowerCase();
        let items = [];
        let source = root.pinnedItems;

        for (let i = 0; i < source.length; i++) {
            let item = source[i];
            if (item.type === "folder" && item.id === folderId) {
                let kept = (item.children || []).filter(child => String(child.id).toLowerCase() !== wanted);
                if (kept.length > 0) items.push({ "type": "folder", "id": item.id, "name": item.name, "children": kept });
                items.push({ "type": "app", "id": id });
            } else {
                items.push(item);
            }
        }
        root.commit(items);
    }
}
