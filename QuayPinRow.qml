import QtQuick

// One row in the pin board, on either side of it.
Item {
    id: root

    property string label: ""
    property string iconSource: ""
    property string glyph: ""
    property string trailing: ""
    property bool dimmed: false
    property bool draggable: true

    signal activated()
    signal trailingActivated()
    signal dragBegan(point scenePoint)
    signal dragMoved(point scenePoint)
    signal dragEnded()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: QuayTheme.radiusSmall
        color: hover.hovered ? QuayTheme.alpha(QuayTheme.surface1, 0.55) : "transparent"
    }

    Image {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: root.glyph === "" && icon.status === Image.Ready
        source: root.iconSource
        asynchronous: true
        opacity: root.dimmed ? 0.45 : 1.0
        width: 18
        height: 18
        sourceSize.width: 18
        sourceSize.height: 18
        fillMode: Image.PreserveAspectFit
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        horizontalAlignment: Text.AlignHCenter
        visible: root.glyph !== "" || icon.status !== Image.Ready
        text: root.glyph !== "" ? root.glyph
            : (root.label.length > 0 ? root.label.charAt(0).toUpperCase() : "?")
        color: QuayTheme.subtext0
        font.family: QuayTheme.mono
        font.pixelSize: 12
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 34
        anchors.right: trailingButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        // root.label is an app or folder name off disk or user data, not
        // trusted content — plain text keeps it from being read as markup.
        textFormat: Text.PlainText
        color: root.dimmed ? QuayTheme.overlay0 : QuayTheme.text
        font.family: QuayTheme.mono
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Item {
        id: trailingButton
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        visible: root.trailing !== "" && (hover.hovered || root.dimmed)

        Text {
            anchors.centerIn: parent
            text: root.trailing
            color: trailingHover.hovered ? QuayTheme.accent : QuayTheme.overlay0
            font.family: QuayTheme.mono
            font.pixelSize: 11
        }

        HoverHandler { id: trailingHover }
        TapHandler { onTapped: root.trailingActivated() }
    }

    HoverHandler { id: hover }

    TapHandler {
        onTapped: root.activated()
    }

    DragHandler {
        id: drag
        target: null
        enabled: root.draggable

        onActiveChanged: {
            if (drag.active) root.dragBegan(drag.centroid.scenePosition);
            else root.dragEnded();
        }
        onCentroidChanged: if (drag.active) root.dragMoved(drag.centroid.scenePosition)
    }

    Accessible.role: Accessible.ListItem
    Accessible.name: root.label
}
