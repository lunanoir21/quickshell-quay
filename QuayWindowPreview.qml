pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

// Shown on hover for an app with more than one window: a live thumbnail per
// window so the user can pick one directly instead of cycling blind.
Item {
    id: root

    property string entryId: ""

    signal dismissed()
    signal selected(var toplevel)
    // Hovering this card is, to the grid beneath it, indistinguishable from
    // the pointer having left — this is the only way to tell it otherwise.
    signal holdChanged(bool held)

    readonly property var group: QuayWindows.groupFor(root.entryId)
    readonly property var windowList: root.group ? root.group.windows : []

    opacity: 0
    scale: 0.96
    Component.onCompleted: enterAnimation.start()

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: QuayTheme.radiusMedium
        color: QuayTheme.mantle
        border.width: 1
        border.color: QuayTheme.alpha(QuayTheme.text, 0.08)

        TapHandler { onTapped: root.dismissed() }

        // This overlay sits on top of the grid it opened from, so hovering
        // it reads to that grid's own HoverHandler as the pointer having
        // left. Without this, the close timer underneath fires while the
        // pointer is sitting right on the preview it's about to close.
        HoverHandler {
            id: cardHover
            onHoveredChanged: root.holdChanged(cardHover.hovered)
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: 6

            Text {
                width: parent.width
                text: QuayApps.nameFor(root.entryId)
                textFormat: Text.PlainText
                color: QuayTheme.subtext0
                font.family: QuayTheme.mono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: root.windowList

                Rectangle {
                    id: card
                    required property var modelData

                    width: column.width
                    height: 60
                    radius: QuayTheme.radiusSmall
                    clip: true
                    color: cardHover.hovered
                        ? QuayTheme.alpha(QuayTheme.surface1, 0.85)
                        : QuayTheme.alpha(QuayTheme.surface0, 0.55)
                    border.width: card.modelData.activated ? 1 : 0
                    border.color: QuayTheme.accent

                    Behavior on color { ColorAnimation { duration: 120 } }

                    ScreencopyView {
                        anchors.fill: parent
                        anchors.margins: 4
                        captureSource: card.modelData
                        live: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: label.implicitHeight + 4
                        color: QuayTheme.alpha(QuayTheme.mantle, 0.75)

                        Text {
                            id: label
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: QuayWindows.titleFor(card.modelData)
                            // A window title is the owning app's to set, not
                            // trusted content — plain text keeps a title that
                            // looks like markup from being rendered as any.
                            textFormat: Text.PlainText
                            color: QuayTheme.text
                            font.family: QuayTheme.mono
                            font.pixelSize: 8
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 16
                        height: 16
                        radius: 8
                        visible: cardHover.hovered
                        color: closeHover.hovered ? QuayTheme.text : QuayTheme.alpha(QuayTheme.mantle, 0.9)

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: closeHover.hovered ? QuayTheme.base : QuayTheme.text
                            font.family: QuayTheme.mono
                            font.pixelSize: 9
                        }

                        HoverHandler { id: closeHover }
                        // WithinBounds grabs the press, so the card's own tap
                        // (focus this window) doesn't also fire.
                        TapHandler {
                            gesturePolicy: TapHandler.WithinBounds
                            onTapped: card.modelData.close()
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Close window")
                    }

                    HoverHandler { id: cardHover }
                    TapHandler { onTapped: root.selected(card.modelData) }

                    Accessible.role: Accessible.Button
                    Accessible.name: card.modelData.title
                }
            }
        }
    }
}
