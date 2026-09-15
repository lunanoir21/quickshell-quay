pragma ComponentBehavior: Bound

import QtQuick

// The rail's chrome: translucent panel plus the page markers that give the
// grid its home-screen reading.
Item {
    id: root

    property int thickness: 0
    property bool vertical: true
    property string edge: "right"
    property string style: "floating"
    property int edgeGap: 0
    property var gridView: null

    signal settingsRequested()

    // What the rail spends besides its tiles, so the surface can be sized to
    // show every row it promises: the panel's gap from the screen edge, and
    // along the rail the gear with its gap. Only a floating panel keeps off the
    // edge; the other styles draw their background with QuayRailShape.
    readonly property int panelInset: 4
    readonly property int edgeInset: root.style === "floating" ? root.edgeGap : 0
    readonly property int chromeLength: gearButton.height + 8 + root.panelInset * 2

    default property alias content: contentArea.data

    readonly property int pageCount: {
        if (!root.gridView || root.gridView.count === 0) return 0;
        let perPage = Math.max(1, QuayStore.columns * QuayStore.rows);
        return Math.ceil(root.gridView.count / perPage);
    }

    readonly property int currentPage: {
        if (!root.gridView || root.pageCount <= 1) return 0;
        return Math.round(root.gridView.progress * (root.pageCount - 1));
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        anchors.leftMargin: root.edge === "left" ? root.edgeInset : (root.edge === "right" ? 0 : root.panelInset)
        anchors.rightMargin: root.edge === "right" ? root.edgeInset : (root.edge === "left" ? 0 : root.panelInset)
        anchors.topMargin: root.edge === "top" ? root.edgeInset : (root.edge === "bottom" ? 0 : root.panelInset)
        anchors.bottomMargin: root.edge === "bottom" ? root.edgeInset : (root.edge === "top" ? 0 : root.panelInset)

        radius: QuayTheme.radiusLarge
        color: root.style === "floating" ? QuayTheme.alpha(QuayTheme.base, 0.88) : "transparent"
        border.width: root.style === "floating" ? 1 : 0
        border.color: QuayTheme.alpha(QuayTheme.text, 0.07)
    }

    Item {
        id: contentArea
        anchors.fill: panel
        anchors.topMargin: root.vertical ? gearButton.height + 8 : 0
        anchors.leftMargin: root.vertical ? 0 : gearButton.width + 8
    }

    // The only in-widget way to reach Quay's own settings panel besides the
    // compositor keybind — without this there is no visible affordance at all.
    Rectangle {
        id: gearButton
        width: 30
        height: 30
        radius: QuayTheme.radiusSmall
        color: gearHover.hovered ? QuayTheme.alpha(QuayTheme.surface1, 0.85) : QuayTheme.alpha(QuayTheme.surface0, 0.55)
        scale: gearHover.hovered ? 1.08 : 1.0

        // Centred on the panel, not the rail, so an edge gap doesn't push it
        // off the tile column.
        x: root.vertical ? panel.x + (panel.width - width) / 2 : 8
        y: root.vertical ? 8 : panel.y + (panel.height - height) / 2

        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "󰒓"
            color: gearHover.hovered ? QuayTheme.text : QuayTheme.subtext0
            font.family: QuayTheme.mono
            font.pixelSize: 16
        }

        HoverHandler { id: gearHover }
        TapHandler { onTapped: root.settingsRequested() }

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Quay settings")
    }

    Grid {
        id: pageMarkers
        visible: root.pageCount > 1
        spacing: 4
        rows: root.vertical ? root.pageCount : 1
        columns: root.vertical ? 1 : root.pageCount

        // Just outside the panel, in the strip the surface keeps free on the
        // desktop side: inside it the markers read as one more running mark.
        x: root.vertical
            ? (root.edge === "right" ? -pageMarkers.width - 2 : root.width + 2)
            : (root.width - pageMarkers.width) / 2
        y: root.vertical
            ? (root.height - pageMarkers.height) / 2
            : (root.edge === "bottom" ? -pageMarkers.height - 2 : root.height + 2)

        Repeater {
            model: root.pageCount

            // The marker grows along the axis the pages scroll on.
            Rectangle {
                required property int index
                readonly property bool current: index === root.currentPage
                readonly property int extent: current ? 12 : 3

                width: root.vertical ? 3 : extent
                height: root.vertical ? extent : 3
                radius: 1.5
                color: current ? QuayTheme.accent : QuayTheme.alpha(QuayTheme.overlay0, 0.6)

                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }
    }
}
