pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Quay's own settings surface: a section list on the left, one focused pane on
// the right. Everything configurable lives here, so a standalone install needs
// no host settings app.
PanelWindow {
    id: root

    required property var quayScreen
    screen: root.quayScreen

    property string section: "appearance"

    signal dismissed()

    readonly property var sections: [
        { key: "appearance", glyph: "󰸌", label: qsTr("Appearance"), hint: qsTr("Theme") },
        { key: "trigger", glyph: "󰊫", label: qsTr("Trigger"), hint: qsTr("How it appears") },
        { key: "grid", glyph: "󰕰", label: qsTr("Grid"), hint: qsTr("Size and layout") },
        { key: "windows", glyph: "󰖯", label: qsTr("Windows"), hint: qsTr("Live previews") },
        { key: "apps", glyph: "󰀻", label: qsTr("Applications"), hint: qsTr("Pins and folders") }
    ]

    readonly property int sectionIndex: root.sections.findIndex(s => s.key === root.section)

    // The pane slides in from the direction of travel through the list.
    function switchSection(key) {
        if (key === root.section) return;
        let target = root.sections.findIndex(s => s.key === key);
        paneEnter.stop();
        paneShift.y = (target > root.sectionIndex ? 1 : -1) * 14;
        sectionLoader.opacity = 0;
        root.section = key;
        paneEnter.start();
    }

    // Plays the closing animation, then asks the owner to unload the panel.
    property bool closing: false

    function requestClose() {
        if (root.closing) return;
        root.closing = true;
        openAnimation.stop();
        closeAnimation.start();
    }

    Component.onCompleted: openAnimation.start()

    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }

    ParallelAnimation {
        id: closeAnimation
        onFinished: root.dismissed()
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale"; to: 0.96; duration: 140; easing.type: Easing.InCubic }
    }

    ParallelAnimation {
        id: paneEnter
        NumberAnimation { target: sectionLoader; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: paneShift; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }

    WlrLayershell.namespace: "quay-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    color: "transparent"
    focusable: true

    implicitWidth: 760
    implicitHeight: 580

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: 8
        radius: QuayTheme.radiusLarge
        color: QuayTheme.base
        border.width: 1
        border.color: QuayTheme.alpha(QuayTheme.text, 0.10)
        opacity: 0
        scale: 0.95

        Behavior on color { ColorAnimation { duration: 220 } }

        focus: true
        Keys.onEscapePressed: root.requestClose()

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Fixed, so the column doesn't give up width to whichever pane
            // happens to be wider and jump as sections change.
            ColumnLayout {
                Layout.preferredWidth: 196
                Layout.minimumWidth: 196
                Layout.maximumWidth: 196
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 2

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 14
                    spacing: 1

                    Text {
                        text: "Quay"
                        color: QuayTheme.text
                        font.family: QuayTheme.mono
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: qsTr("Vertical application launcher")
                        color: QuayTheme.overlay0
                        font.family: QuayTheme.mono
                        font.pixelSize: 9
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: navColumn.implicitHeight

                    Rectangle {
                        id: navHighlight
                        width: parent.width
                        height: 38
                        y: Math.max(0, root.sectionIndex) * (navHighlight.height + navColumn.spacing)
                        radius: QuayTheme.radiusSmall
                        color: QuayTheme.alpha(QuayTheme.accent, 0.14)

                        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 220 } }

                        Rectangle {
                            x: 2
                            width: 2
                            height: 16
                            radius: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: QuayTheme.accent
                        }
                    }

                    Column {
                        id: navColumn
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: root.sections

                            QuayNavRow {
                                required property var modelData
                                width: navColumn.width
                                glyph: modelData.glyph
                                label: modelData.label
                                hint: modelData.hint
                                current: root.section === modelData.key
                                onActivated: root.switchSection(modelData.key)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Esc closes this panel")
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 8
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 14
                Layout.bottomMargin: 14
                color: QuayTheme.alpha(QuayTheme.text, 0.07)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.sections.find(s => s.key === root.section).label.toUpperCase()
                        color: QuayTheme.subtext0
                        font.family: QuayTheme.mono
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.7
                    }

                    Item {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22

                        Rectangle {
                            anchors.fill: parent
                            radius: QuayTheme.radiusSmall
                            color: closeHover.hovered ? QuayTheme.alpha(QuayTheme.surface1, 0.8) : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: closeHover.hovered ? QuayTheme.text : QuayTheme.subtext0
                            font.family: QuayTheme.mono
                            font.pixelSize: 11
                        }

                        HoverHandler { id: closeHover }
                        TapHandler { onTapped: root.requestClose() }

                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Close settings")
                    }
                }

                Loader {
                    id: sectionLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    transform: Translate { id: paneShift }
                    sourceComponent: {
                        if (root.section === "appearance") return appearancePane;
                        if (root.section === "trigger") return triggerPane;
                        if (root.section === "grid") return gridPane;
                        if (root.section === "windows") return windowsPane;
                        return appsPane;
                    }
                }
            }
        }
    }

    Component {
        id: appearancePane

        ColumnLayout {
            spacing: 12

            QuaySettingRow {
                label: qsTr("Theme")
                hint: qsTr("Pure monochrome, or whichever the system prefers")

                QuaySegmented {
                    options: [
                        { value: "black", label: qsTr("Black") },
                        { value: "white", label: qsTr("White") },
                        { value: "auto", label: qsTr("System") }
                    ]
                    currentValue: QuayStore.theme
                    onPicked: value => QuayStore.setOption("appearance.theme", value)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: QuayTheme.radiusMedium
                color: QuayTheme.alpha(QuayTheme.surface0, 0.35)
                border.width: 1
                border.color: QuayTheme.alpha(QuayTheme.text, 0.06)

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Repeater {
                        model: QuayModel.entries.filter(entry => entry.type === "app").slice(0, 5)

                        Rectangle {
                            id: previewTile
                            required property var modelData
                            width: 44
                            height: 44
                            radius: QuayTheme.radiusMedium
                            color: QuayTheme.alpha(QuayTheme.surface1, 0.6)

                            Image {
                                anchors.centerIn: parent
                                source: previewTile.modelData.iconSource
                                asynchronous: true
                                width: 26
                                height: 26
                                sourceSize.width: 26
                                sourceSize.height: 26
                                fillMode: Image.PreserveAspectFit
                            }

                            Rectangle {
                                visible: previewTile.modelData.isRunning
                                width: 3
                                height: previewTile.modelData.isActive ? 16 : 4
                                radius: 1.5
                                color: previewTile.modelData.isActive ? QuayTheme.accent : QuayTheme.running
                                x: 2
                                y: (parent.height - height) / 2
                            }
                        }
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 8
                    text: qsTr("Preview")
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 8
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: triggerPane

        ColumnLayout {
            spacing: 12

            QuaySettingRow {
                label: qsTr("Mode")
                hint: qsTr("How the rail comes on screen")

                QuaySegmented {
                    options: [
                        { value: "always", label: qsTr("Always") },
                        { value: "hover", label: qsTr("Hover") },
                        { value: "shortcut", label: qsTr("Shortcut") }
                    ]
                    currentValue: QuayStore.triggerMode
                    onPicked: value => QuayStore.setOption("trigger.mode", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Edge")

                QuaySegmented {
                    options: [
                        { value: "left", label: qsTr("Left") },
                        { value: "right", label: qsTr("Right") },
                        { value: "top", label: qsTr("Top") },
                        { value: "bottom", label: qsTr("Bottom") }
                    ]
                    currentValue: QuayStore.triggerEdge
                    onPicked: value => QuayStore.setOption("trigger.edge", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Over fullscreen")
                hint: qsTr("Keeps the rail out of games and videos")

                QuaySegmented {
                    options: [
                        { value: true, label: qsTr("Hide") },
                        { value: false, label: qsTr("Stay") }
                    ]
                    currentValue: QuayStore.hideOnFullscreen
                    onPicked: value => QuayStore.setOption("trigger.hideOnFullscreen", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Reveal delay")
                hint: qsTr("Pointer dwell before it slides in")
                enabled: QuayStore.triggerMode === "hover"

                QuayStepper {
                    from: 0
                    to: 600
                    stepSize: 10
                    suffix: "ms"
                    value: QuayStore.hoverRevealDelayMs
                    onMoved: value => QuayStore.hoverRevealDelayMs = value
                    onCommitted: value => QuayStore.setOption("trigger.hoverRevealDelayMs", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Hide delay")
                hint: qsTr("Grace period after the pointer leaves")
                enabled: QuayStore.triggerMode === "hover"

                QuayStepper {
                    from: 0
                    to: 1500
                    stepSize: 20
                    suffix: "ms"
                    value: QuayStore.hoverHideDelayMs
                    onMoved: value => QuayStore.hoverHideDelayMs = value
                    onCommitted: value => QuayStore.setOption("trigger.hoverHideDelayMs", value)
                }
            }

            ColumnLayout {
                id: shortcutHelp
                Layout.fillWidth: true
                visible: QuayStore.triggerMode === "shortcut"
                spacing: 6

                // IPC only reaches this instance through the same selector it was
                // launched with (-p .../Shell.qml, -p .../Main.qml, -c name, or
                // none), and QML cannot see that, so the process asks its own
                // command line.
                property string instanceSelector: ""
                readonly property string toggleCommand: "qs " + (shortcutHelp.instanceSelector ? shortcutHelp.instanceSelector + " " : "") + "ipc call quay toggle"
                readonly property string hyprBind: "bind = SUPER SHIFT, D, exec, " + shortcutHelp.toggleCommand
                property bool justCopied: false

                function selectorFrom(args) {
                    for (let i = 1; i < args.length; i++) {
                        let arg = args[i];
                        let path = "";
                        if ((arg === "-p" || arg === "--path") && i + 1 < args.length) path = args[i + 1];
                        else if (arg.startsWith("--path=")) path = arg.slice(7);
                        if (path) {
                            let absolute = path.startsWith("/") ? path
                                : (path.endsWith(".qml") ? Quickshell.shellDir + "/" + path.split("/").pop() : Quickshell.shellDir);
                            return "-p " + (absolute.indexOf(" ") !== -1 ? "'" + absolute + "'" : absolute);
                        }
                        if ((arg === "-c" || arg === "--config") && i + 1 < args.length) return "-c " + args[i + 1];
                        if (arg.startsWith("--config=")) return "-c " + arg.slice(9);
                    }
                    return "";
                }

                Process {
                    running: true
                    command: ["sh", "-c", "tr '\\0' '\\n' < /proc/$PPID/cmdline"]
                    stdout: StdioCollector {
                        onStreamFinished: shortcutHelp.instanceSelector = shortcutHelp.selectorFrom(String(this.text || "").split("\n"))
                    }
                }

                Timer {
                    id: copiedResetTimer
                    interval: 1400
                    onTriggered: shortcutHelp.justCopied = false
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Quay has no global hotkey of its own — bind one in your compositor. On Hyprland, add this to your config:")
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: bindText.implicitHeight + 14
                        radius: QuayTheme.radiusSmall
                        color: QuayTheme.alpha(QuayTheme.surface0, 0.6)
                        border.width: 1
                        border.color: QuayTheme.alpha(QuayTheme.text, 0.07)

                        Text {
                            id: bindText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            text: shortcutHelp.hyprBind
                            color: QuayTheme.text
                            font.family: QuayTheme.mono
                            font.pixelSize: 9
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 26
                        radius: QuayTheme.radiusSmall
                        color: copyHover.hovered ? QuayTheme.alpha(QuayTheme.accent, 0.22) : QuayTheme.alpha(QuayTheme.surface1, 0.6)

                        Text {
                            anchors.centerIn: parent
                            text: shortcutHelp.justCopied ? "✓" : qsTr("Copy")
                            color: QuayTheme.text
                            font.family: QuayTheme.mono
                            font.pixelSize: 9
                        }

                        HoverHandler { id: copyHover }
                        TapHandler {
                            onTapped: {
                                Quickshell.execDetached(["sh", "-c",
                                    "printf %s " + JSON.stringify(shortcutHelp.hyprBind) + " | wl-copy"]);
                                shortcutHelp.justCopied = true;
                                copiedResetTimer.restart();
                            }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Copy Hyprland bind line")
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Other compositors: bind any key to the command above (drop the leading \"bind = SUPER SHIFT, D, exec, \").")
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: gridPane

        ColumnLayout {
            spacing: 12

            QuaySettingRow {
                label: qsTr("Columns")
                hint: qsTr("Tiles across the rail")

                QuayStepper {
                    from: 1
                    to: 6
                    value: QuayStore.columns
                    onMoved: value => QuayStore.columns = value
                    onCommitted: value => QuayStore.setOption("layout.columns", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Rows per page")
                hint: qsTr("One wheel notch moves one row")

                QuayStepper {
                    from: 2
                    to: 16
                    value: QuayStore.rows
                    onMoved: value => QuayStore.rows = value
                    onCommitted: value => QuayStore.setOption("layout.rows", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Icon size")

                QuayStepper {
                    from: 28
                    to: 96
                    stepSize: 2
                    suffix: "px"
                    value: QuayStore.iconSize
                    onMoved: value => QuayStore.iconSize = value
                    onCommitted: value => QuayStore.setOption("layout.iconSize", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Spacing")

                QuayStepper {
                    from: 0
                    to: 32
                    stepSize: 2
                    suffix: "px"
                    value: QuayStore.spacing
                    onMoved: value => QuayStore.spacing = value
                    onCommitted: value => QuayStore.setOption("layout.spacing", value)
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: windowsPane

        ColumnLayout {
            spacing: 12

            QuaySettingRow {
                label: qsTr("Window previews")
                hint: qsTr("For apps with more than one window open")

                QuaySegmented {
                    options: [
                        { value: "off", label: qsTr("Off") },
                        { value: "inside", label: qsTr("In the rail") },
                        { value: "beside", label: qsTr("Beside the rail") }
                    ]
                    currentValue: QuayStore.previewMode
                    onPicked: value => QuayStore.setOption("previews.mode", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Preview delay")
                hint: qsTr("Pointer dwell on a tile before previews open")
                enabled: QuayStore.previewMode !== "off"

                QuayStepper {
                    from: 0
                    to: 1500
                    stepSize: 50
                    suffix: "ms"
                    value: QuayStore.previewDelayMs
                    onMoved: value => QuayStore.previewDelayMs = value
                    onCommitted: value => QuayStore.setOption("previews.delayMs", value)
                }
            }

            // A small picture of the choice: where the preview lands relative
            // to the rail, animated as the setting changes.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 168
                radius: QuayTheme.radiusMedium
                color: QuayTheme.alpha(QuayTheme.surface0, 0.35)
                border.width: 1
                border.color: QuayTheme.alpha(QuayTheme.text, 0.06)

                Item {
                    id: stage
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: 280
                    height: 116

                    readonly property string mode: QuayStore.previewMode

                    Rectangle {
                        anchors.fill: parent
                        radius: QuayTheme.radiusSmall
                        color: QuayTheme.alpha(QuayTheme.surface1, 0.22)
                    }

                    Rectangle {
                        id: miniRail
                        width: 26
                        height: 100
                        x: stage.width - miniRail.width - 6
                        y: (stage.height - miniRail.height) / 2
                        radius: 8
                        color: QuayTheme.mantle
                        border.width: 1
                        border.color: QuayTheme.alpha(QuayTheme.text, 0.10)

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Repeater {
                                model: 4

                                Rectangle {
                                    required property int index
                                    width: 14
                                    height: 14
                                    radius: 4
                                    color: index === 1
                                        ? QuayTheme.alpha(QuayTheme.accent, 0.45)
                                        : QuayTheme.alpha(QuayTheme.surface1, 0.8)
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: miniPreview

                        readonly property bool beside: stage.mode === "beside"
                        // Second tile's centre: column top + one tile and gap + half a tile.
                        readonly property real tileCentre: miniRail.y + (miniRail.height - 74) / 2 + 27

                        width: miniPreview.beside ? 104 : miniRail.width - 4
                        height: miniPreview.beside ? 78 : miniRail.height - 4
                        x: miniPreview.beside ? miniRail.x - miniPreview.width - 8 : miniRail.x + 2
                        y: miniPreview.beside ? miniPreview.tileCentre - miniPreview.height / 2 : miniRail.y + 2
                        opacity: stage.mode === "off" ? 0 : 1
                        radius: miniPreview.beside ? 7 : 6
                        color: QuayTheme.mantle
                        border.width: 1
                        border.color: QuayTheme.alpha(QuayTheme.text, 0.20)

                        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 3

                            Repeater {
                                model: 2

                                Rectangle {
                                    width: parent.width
                                    height: (parent.height - 3) / 2
                                    radius: 3
                                    color: QuayTheme.alpha(QuayTheme.surface1, 0.9)
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: {
                        if (QuayStore.previewMode === "inside") return qsTr("Opens over the rail, in place of the grid");
                        if (QuayStore.previewMode === "beside") return qsTr("Opens next to the rail, with larger live thumbnails");
                        return qsTr("No previews — clicking an app still cycles its windows");
                    }
                    color: QuayTheme.overlay0
                    font.family: QuayTheme.mono
                    font.pixelSize: 9
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: appsPane

        ColumnLayout {
            spacing: 12

            QuaySettingRow {
                label: qsTr("Besides pinned apps")
                hint: qsTr("What else the rail lists")

                QuaySegmented {
                    options: [
                        { value: "pinned", label: qsTr("Nothing") },
                        { value: "running", label: qsTr("Open windows") },
                        { value: "recent", label: qsTr("Recently used") }
                    ]
                    currentValue: QuayStore.extras
                    onPicked: value => QuayStore.setOption("content.extras", value)
                }
            }

            QuaySettingRow {
                label: qsTr("Recent entries")
                enabled: QuayStore.extras === "recent"

                QuayStepper {
                    from: 1
                    to: 10
                    value: QuayStore.recentLimit
                    onMoved: value => QuayStore.recentLimit = value
                    onCommitted: value => QuayStore.setOption("content.recentLimit", value)
                }
            }

            QuayPinBoard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 240
            }
        }
    }
}
