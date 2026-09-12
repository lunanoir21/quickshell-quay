import QtQuick
import Quickshell
import Quickshell.Io

// Integration point: one Quay per screen, plus the IPC surface a compositor
// keybind or a host settings app can call into.
Scope {
    id: host

    Variants {
        id: variants
        model: Quickshell.screens
        delegate: Component { Quay {} }
    }

    function each(fn) {
        let instances = variants.instances;
        for (let i = 0; i < instances.length; i++) fn(instances[i]);
    }

    IpcHandler {
        target: "quay"

        function toggle(): void { host.each(surface => surface.toggle()) }
        function show(): void { host.each(surface => surface.show()) }
        function hide(): void { host.each(surface => surface.hide()) }
        function settings(): void { host.each(surface => surface.openSettings()) }
        function refreshApps(): void { QuayApps.refresh() }
    }
}
