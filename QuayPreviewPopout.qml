pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// Window previews placed beside the rail rather than over it. A surface of its
// own, so thumbnails can be larger than a rail tile allows; it spans the whole
// edge and the mask keeps everything but the card click-through.
PanelWindow {
    id: root

    required property var quayScreen
    required property int railThickness
    // Length of the rail surface along the edge; the rail may sit anywhere
    // inside it, which the tile anchor already accounts for.
    required property int surfaceLength
    property string entryId: ""
    // Tile centre in the rail surface's coordinates.
    property point anchorPoint: Qt.point(0, 0)
    property bool open: false

    signal holdChanged(bool held)
    signal selected(var toplevel)

    screen: root.quayScreen

    readonly property string edge: QuayStore.triggerEdge
    readonly property bool vertical: QuayStore.vertical
    // Room between rail and card; the card slides in across it.
    readonly property int slack: 12
    readonly property int screenMargin: 12
    readonly property int pad: 10
    readonly property int headerHeight: 22
    readonly property int thumbWidth: 232
    readonly property int thumbHeight: 130
    readonly property int titleHeight: 18
    readonly property int cardGap: 8

    // Held at the last app while the card fades out, so it doesn't empty
    // itself on the way out.
    property string shownId: ""
    onEntryIdChanged: if (root.entryId !== "") root.shownId = root.entryId

    readonly property var group: QuayWindows.groupFor(root.shownId)
    readonly property var windowList: root.group ? root.group.windows : []

    readonly property int cellAlong: root.vertical ? root.thumbHeight + root.titleHeight : root.thumbWidth
    readonly property int roomAlong: (root.vertical ? root.height : root.width) - root.screenMargin * 2
        - root.pad * 2 - (root.vertical ? root.headerHeight : 0)
    readonly property int visibleCount: Math.max(1, Math.min(root.windowList.length,
        Math.floor((root.roomAlong + root.cardGap) / (root.cellAlong + root.cardGap))))

    // 0 hidden, 1 shown; drives both the fade and the slide off the rail.
    property real progress: 0
    Behavior on progress { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Component.onCompleted: {
        root.shownId = root.entryId;
        root.progress = Qt.binding(() => root.open ? 1 : 0);
    }

    // Losing the card while the pointer is on it sends no leave event.
    onOpenChanged: if (!root.open) root.holdChanged(false)

    WlrLayershell.namespace: "quay-preview"
    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"
    exclusiveZone: 0

    anchors {
        left: root.edge === "left" || !root.vertical
        right: root.edge === "right" || !root.vertical
        top: root.edge === "top" || root.vertical
        bottom: root.edge === "bottom" || root.vertical
    }

    margins {
        left: root.edge === "left" ? root.railThickness : 0
        right: root.edge === "right" ? root.railThickness : 0
        top: root.edge === "top" ? root.railThickness : 0
        bottom: root.edge === "bottom" ? root.railThickness : 0
    }

    // The span along the edge is stretched by the anchors, but a zero implicit
    // size there keeps the window from being created at all.
    implicitWidth: root.vertical ? card.width + root.slack : root.quayScreen.width
    implicitHeight: root.vertical ? root.quayScreen.height : card.height + root.slack

    mask: Region { item: root.open ? card : nothing }

    Item { id: nothing }

    Rectangle {
        id: card

        readonly property real railStart: ((root.vertical ? root.height : root.width) - root.surfaceLength) / 2
        readonly property real hiddenShift: (root.edge === "right" || root.edge === "bottom" ? 1 : -1) * root.slack

        width: root.vertical
            ? root.thumbWidth + root.pad * 2
            : root.visibleCount * (root.thumbWidth + root.cardGap) - root.cardGap + root.pad * 2
        height: root.vertical
            ? root.headerHeight + root.visibleCount * (root.cellAlong + root.cardGap) - root.cardGap + root.pad * 2
            : root.headerHeight + root.thumbHeight + root.titleHeight + root.pad * 2

        x: root.vertical
            ? (root.edge === "left" ? root.slack : 0)
            : Math.max(root.screenMargin, Math.min(root.width - card.width - root.screenMargin,
                card.railStart + root.anchorPoint.x - card.width / 2))
        y: root.vertical
            ? Math.max(root.screenMargin, Math.min(root.height - card.height - root.screenMargin,
                card.railStart + root.anchorPoint.y - card.height / 2))
            : (root.edge === "top" ? root.slack : 0)

        // Following the pointer from tile to tile, but not flying in from the
        // placeholder position the card had before the surface was sized.
        Behavior on x { enabled: root.progress === 1; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: root.progress === 1; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        opacity: root.progress
        transform: Translate {
            x: root.vertical ? card.hiddenShift * (1 - root.progress) : 0
            y: root.vertical ? 0 : card.hiddenShift * (1 - root.progress)
        }

        radius: QuayTheme.radiusMedium
        color: QuayTheme.mantle
        border.width: 1
        border.color: QuayTheme.alpha(QuayTheme.text, 0.10)

        HoverHandler {
            id: cardHover
            onHoveredChanged: root.holdChanged(cardHover.hovered)
        }

        Text {
            x: root.pad
            y: root.pad
            width: card.width - root.pad * 2
            height: root.headerHeight
            text: QuayApps.nameFor(root.shownId)
            textFormat: Text.PlainText
            color: QuayTheme.subtext0
            font.family: QuayTheme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            verticalAlignment: Text.AlignTop
        }

        Flickable {
            x: root.pad
            y: root.pad + root.headerHeight
            width: card.width - root.pad * 2
            height: card.height - root.pad * 2 - root.headerHeight
            contentWidth: windowGrid.implicitWidth
            contentHeight: windowGrid.implicitHeight
            clip: root.windowList.length > root.visibleCount
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: windowGrid
                columns: root.vertical ? 1 : root.windowList.length
                spacing: root.cardGap

                Repeater {
                    model: root.windowList

                    Rectangle {
                        id: windowCard
                        required property var modelData

                        width: root.thumbWidth
                        height: root.thumbHeight + root.titleHeight
                        radius: QuayTheme.radiusSmall
                        color: windowHover.hovered
                            ? QuayTheme.alpha(QuayTheme.surface1, 0.9)
                            : QuayTheme.alpha(QuayTheme.surface0, 0.6)
                        border.width: windowCard.modelData.activated ? 1 : 0
                        border.color: QuayTheme.accent
                        scale: windowTap.pressed ? 0.97 : 1.0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        ScreencopyView {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 5 + (root.thumbHeight - 8 - height) / 2
                            width: implicitWidth
                            height: implicitHeight
                            constraintSize: Qt.size(root.thumbWidth - 10, root.thumbHeight - 8)
                            captureSource: windowCard.modelData
                            live: root.open
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            anchors.bottomMargin: 3
                            text: QuayWindows.titleFor(windowCard.modelData)
                            // A window title is the owning app's to set, not
                            // trusted content — plain text keeps a title that
                            // looks like markup from being rendered as any.
                            textFormat: Text.PlainText
                            color: windowHover.hovered ? QuayTheme.text : QuayTheme.subtext0
                            font.family: QuayTheme.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 20
                            height: 20
                            radius: 10
                            visible: windowHover.hovered
                            color: closeHover.hovered ? QuayTheme.text : QuayTheme.alpha(QuayTheme.mantle, 0.9)
                            border.width: 1
                            border.color: QuayTheme.alpha(QuayTheme.text, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: closeHover.hovered ? QuayTheme.base : QuayTheme.text
                                font.family: QuayTheme.mono
                                font.pixelSize: 10
                            }

                            HoverHandler { id: closeHover }
                            // WithinBounds grabs the press, so the card's own
                            // tap (focus this window) doesn't also fire.
                            TapHandler {
                                gesturePolicy: TapHandler.WithinBounds
                                onTapped: windowCard.modelData.close()
                            }

                            Accessible.role: Accessible.Button
                            Accessible.name: qsTr("Close window")
                        }

                        HoverHandler { id: windowHover }
                        TapHandler {
                            id: windowTap
                            onTapped: root.selected(windowCard.modelData)
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: windowCard.modelData.title
                    }
                }
            }
        }
    }
}
