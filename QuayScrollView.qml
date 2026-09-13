pragma ComponentBehavior: Bound

import QtQuick

// The scrolling grid. Wheel navigation is vertical by definition: one notch
// moves one row, whichever edge the rail is docked to.
Item {
    id: root

    property bool interactive: true

    readonly property bool vertical: QuayStore.vertical
    readonly property int cell: QuayStore.iconSize + QuayStore.spacing
    readonly property int count: view.count
    // 0 with the first row in view, 1 with the last. Page markers read this
    // rather than an item index: a last page that isn't full can never bring
    // its first item to the top, so an index-based marker never reaches it.
    readonly property real progress: {
        if (root.maxOffset <= 0) return 0;
        let offset = root.vertical ? view.contentY : view.contentX;
        return Math.max(0, Math.min(1, offset / root.maxOffset));
    }

    // The app whose windows are being previewed, and where its tile sits.
    // Placement is decided by whoever reads these: the inside overlay below,
    // or the popout Quay.qml opens beside the rail.
    property string previewId: ""
    property point previewAnchor: Qt.point(0, 0)
    // True while the pointer is on the beside popout, which is a separate
    // surface and so looks to this grid like the pointer has left.
    property bool previewHeld: false

    // A file from another app is over one of the tiles; the rail must not
    // hide under it, and a drag reports no hover to tell it so.
    property bool fileDragActive: false

    signal menuRequested(var entry, point anchor)

    property int dragIndex: -1
    property int dropIndex: -1
    property bool dropAsFolder: false
    property real dragEdgePush: 0

    readonly property real maxOffset: root.vertical
        ? Math.max(0, view.contentHeight - view.height)
        : Math.max(0, view.contentWidth - view.width)

    // QuayModel.entries is a freshly-built array on every change (a focus
    // switch, a pin toggle from elsewhere), so a rebuild mid-drag replaces the
    // dragged delegate outright — Qt destroys it without ever firing
    // dragFinished, which would otherwise leave dragIndex/dragEdgePush stuck
    // (and the edge-autoscroll FrameAnimation running forever). A commitDrop
    // already clears these first, so this is a no-op on the normal path.
    Connections {
        target: QuayModel
        function onEntriesChanged() {
            // The preview's thumbnails follow the app's windows on their own,
            // so closing one from the preview keeps it open; it goes only
            // once the app has no window left to show.
            if (root.previewId !== "" && QuayWindows.windowCount(root.previewId) === 0) root.hidePreview();
            if (root.dragIndex === -1) return;
            root.dragIndex = -1;
            root.dropIndex = -1;
            root.dropAsFolder = false;
            root.dragEdgePush = 0;
        }
    }

    function closeFolder() {
        folderLoader.folderId = "";
    }

    function openFolder(id) {
        root.hidePreview();
        folderLoader.folderId = folderLoader.folderId === id ? "" : id;
    }

    Connections {
        target: QuayStore
        function onPreviewModeChanged() {
            root.hidePreview();
        }
    }

    // Routed through root functions rather than referencing a sibling id
    // directly: a Bound delegate (GridView.delegate below) cannot reliably
    // resolve a sibling id declared elsewhere in this file from inside an
    // imperative signal handler, only from a declarative property binding.
    function showPreview(id, anchor) {
        root.previewAnchor = anchor;
        root.previewId = id;
    }

    function hidePreview() {
        root.previewId = "";
    }

    function holdPreview(held) {
        root.previewHeld = held;
        if (held) previewCloseDelay.stop();
        else if (!viewHover.hovered) previewCloseDelay.restart();
    }

    function scrollBy(rows) {
        // The anchor a preview was opened at scrolls away with its tile.
        root.hidePreview();
        let current = root.vertical ? view.contentY : view.contentX;
        let target = Math.max(0, Math.min(root.maxOffset, current + rows * root.cell));
        if (root.vertical) offsetAnimation.animate(view, "contentY", target);
        else offsetAnimation.animate(view, "contentX", target);
    }

    NumberAnimation {
        id: offsetAnimation
        duration: 170
        easing.type: Easing.OutCubic

        function animate(item, property, to) {
            offsetAnimation.stop();
            offsetAnimation.target = item;
            offsetAnimation.property = property;
            offsetAnimation.to = to;
            offsetAnimation.start();
        }
    }

    GridView {
        id: view
        anchors.fill: parent
        clip: true
        interactive: false
        cacheBuffer: root.cell * 4
        reuseItems: true

        cellWidth: root.cell
        cellHeight: root.cell
        flow: root.vertical ? GridView.FlowLeftToRight : GridView.FlowTopToBottom
        model: QuayModel.entries

        delegate: QuayIconDelegate {
            id: tileDelegate
            required property var modelData
            required property int index

            entry: modelData
            itemIndex: index
            cellSize: root.cell
            dragging: root.dragIndex === index
            dropTarget: root.dropIndex === index
            dropMerges: root.dropAsFolder && root.dropIndex === index
            folderOpen: folderLoader.folderId === modelData.id

            onActivated: id => QuayModel.activate(id)
            onFolderToggled: id => root.openFolder(id)
            onNewWindowRequested: id => QuayModel.launchNew(id)
            onFilesDropped: (id, urls) => QuayModel.openFiles(id, urls)
            onFileHoverChanged: root.fileDragActive = tileDelegate.fileHover
            onMenuRequested: (entry, anchor) => {
                root.closeFolder();
                root.hidePreview();
                root.menuRequested(entry, anchor);
            }

            onDragStarted: index => {
                root.dragIndex = index;
                root.closeFolder();
                root.hidePreview();
            }
            onDragMoved: (index, scenePoint) => root.updateDrop(index, scenePoint)
            onDragFinished: index => root.commitDrop(index)
            onPreviewRequested: (id, anchor) => root.showPreview(id, anchor)
        }
    }

    // Pointer position decides the gesture: the inner half of a tile means
    // "put these two together", anywhere else means "reorder to here".
    function updateDrop(index, scenePoint) {
        let local = view.mapFromItem(null, scenePoint.x, scenePoint.y);
        let target = view.indexAt(local.x + view.contentX, local.y + view.contentY);

        if (target === -1 || target === index) {
            root.dropIndex = -1;
            root.dropAsFolder = false;
        } else {
            let entry = QuayModel.entries[target];
            let centreX = (Math.floor((local.x + view.contentX) / root.cell) + 0.5) * root.cell;
            let centreY = (Math.floor((local.y + view.contentY) / root.cell) + 0.5) * root.cell;
            let distance = Math.hypot(local.x + view.contentX - centreX, local.y + view.contentY - centreY);

            root.dropIndex = target;
            root.dropAsFolder = entry !== undefined
                && QuayModel.entries[index] !== undefined
                && QuayModel.entries[index].type === "app"
                && distance < root.cell * 0.28;
        }

        let along = root.vertical ? local.y : local.x;
        let extent = root.vertical ? view.height : view.width;
        let zone = root.cell * 0.6;
        if (along < zone) root.dragEdgePush = -1;
        else if (along > extent - zone) root.dragEdgePush = 1;
        else root.dragEdgePush = 0;
    }

    function commitDrop(index) {
        let target = root.dropIndex;
        let asFolder = root.dropAsFolder;

        root.dragIndex = -1;
        root.dropIndex = -1;
        root.dropAsFolder = false;
        root.dragEdgePush = 0;

        if (target === -1 || target === index) return;
        if (asFolder) QuayModel.groupInto(target, index);
        else QuayModel.move(index, target);
    }

    // Edge autoscroll is integrated from real frame time, so the speed is the
    // same on a 60Hz panel and a 165Hz one.
    FrameAnimation {
        running: root.dragEdgePush !== 0
        onTriggered: {
            let speed = root.cell * 6;
            let delta = root.dragEdgePush * speed * frameTime;
            if (root.vertical) {
                view.contentY = Math.max(0, Math.min(root.maxOffset, view.contentY + delta));
            } else {
                view.contentX = Math.max(0, Math.min(root.maxOffset, view.contentX + delta));
            }
        }
    }

    // A preview belongs to the pointer: once it has left the grid for longer
    // than a flick across the edge, the preview goes with it.
    HoverHandler {
        id: viewHover
        onHoveredChanged: {
            if (viewHover.hovered) previewCloseDelay.stop();
            else if (!root.previewHeld) previewCloseDelay.restart();
        }
    }

    Timer {
        id: previewCloseDelay
        interval: 350
        onTriggered: root.hidePreview()
    }

    WheelHandler {
        enabled: root.interactive && root.dragIndex === -1
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y === 0) return;
            root.scrollBy(event.angleDelta.y > 0 ? -1 : 1);
        }
    }

    Loader {
        id: folderLoader
        property string folderId: ""

        active: folderLoader.folderId !== ""
        anchors.fill: parent
        asynchronous: true

        sourceComponent: QuayFolderPopover {
            folderId: folderLoader.folderId
            onDismissed: root.closeFolder()
            onLaunched: id => {
                QuayModel.activate(id);
                root.closeFolder();
            }
        }
    }

    Loader {
        active: root.previewId !== "" && QuayStore.previewMode === "inside"
        anchors.fill: parent
        asynchronous: true

        sourceComponent: QuayWindowPreview {
            entryId: root.previewId
            onDismissed: root.hidePreview()
            onSelected: toplevel => {
                toplevel.activate();
                root.hidePreview();
            }
        }
    }
}
