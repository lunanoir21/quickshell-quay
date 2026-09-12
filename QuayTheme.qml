pragma Singleton

import QtQuick
import Quickshell

// Two deliberately monochrome palettes. Quay must render identically without
// any host config, so nothing here reads an external theme source.
Singleton {
    id: root

    readonly property bool light: QuayStore.theme === "white"

    readonly property color base: root.light ? "#ffffff" : "#000000"
    readonly property color mantle: root.light ? "#f2f2f2" : "#0a0a0a"
    readonly property color surface0: root.light ? "#e6e6e6" : "#161616"
    readonly property color surface1: root.light ? "#d4d4d4" : "#262626"
    readonly property color overlay0: root.light ? "#8a8a8a" : "#6e6e6e"
    readonly property color subtext0: root.light ? "#4a4a4a" : "#a8a8a8"
    readonly property color text: root.light ? "#0a0a0a" : "#f5f5f5"

    // Monochrome accents: contrast carries the state, not hue.
    readonly property color accent: root.light ? "#0a0a0a" : "#ffffff"
    readonly property color running: root.light ? "#7a7a7a" : "#8f8f8f"

    readonly property string mono: "JetBrains Mono"

    readonly property int radiusLarge: 22
    readonly property int radiusMedium: 14
    readonly property int radiusSmall: 8

    function alpha(color, a) {
        return Qt.rgba(color.r, color.g, color.b, a);
    }
}
