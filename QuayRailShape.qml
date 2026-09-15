import QtQuick
import QtQuick.Shapes

// The rail's background for the two styles that meet the screen edge instead
// of floating off it. Drawn across the whole surface; everything outside the
// path stays transparent, and the surface mask keeps it click-through.
//
// The path is built in edge space — u runs from the screen edge into the
// screen, v along the edge — then mapped onto the surface. Right and top are
// mirror images of that space, so their arcs sweep the other way.
Shape {
    id: root

    property string style: "bridge"            // flush | bridge
    property string edge: "right"
    // How far the rail currently reaches in from the edge; follows the slide.
    property real depth: 0
    // Along the edge: where the body starts and ends.
    property real bodyStart: 0
    property real bodyEnd: 0
    property real fillet: 18
    property real corner: QuayTheme.radiusLarge

    readonly property bool vertical: root.edge === "left" || root.edge === "right"
    readonly property bool mirrored: root.edge === "right" || root.edge === "top"

    visible: root.depth > 0.5
    preferredRendererType: Shape.CurveRenderer

    function point(u, v) {
        if (root.edge === "left") return u + "," + v;
        if (root.edge === "right") return (root.width - u) + "," + v;
        if (root.edge === "top") return v + "," + u;
        return v + "," + (root.height - u);
    }

    // A radius too small to draw is just a corner; PathSvg would otherwise
    // get a degenerate arc.
    function arc(r, sweep, u, v) {
        if (r < 0.5) return " L" + root.point(u, v);
        let flag = root.mirrored ? 1 - sweep : sweep;
        return " A" + r + "," + r + " 0 0 " + flag + " " + root.point(u, v);
    }

    // Tab welded to the edge: concave ears where it leaves the edge, convex
    // corners on the screen side. The ears shrink with the depth so the
    // collapsed handle stays a clean sliver.
    function bridgePath(closed) {
        let d = root.depth;
        let r = Math.min(root.fillet, d / 2);
        let c = Math.min(root.corner, d - r, (root.bodyEnd - root.bodyStart) / 2);
        let v0 = root.bodyStart, v1 = root.bodyEnd;
        return "M" + root.point(0, v0 - r)
            + root.arc(r, 0, r, v0)
            + " L" + root.point(d - c, v0)
            + root.arc(c, 1, d, v0 + c)
            + " L" + root.point(d, v1 - c)
            + root.arc(c, 1, d - c, v1)
            + " L" + root.point(r, v1)
            + root.arc(r, 0, 0, v1 + r)
            + (closed ? " Z" : "");
    }

    // A strip along the whole edge, flaring into the screen at both ends so the
    // desktop behind it reads as a window with rounded corners.
    function flushPath(closed) {
        let d = root.depth;
        let r = Math.min(root.fillet, d);
        let v0 = root.bodyStart, v1 = root.bodyEnd;
        let open = "M" + root.point(d + r, v0)
            + root.arc(r, 0, d, v0 + r)
            + " L" + root.point(d, v1 - r)
            + root.arc(r, 0, d + r, v1);
        if (!closed) return open;
        return open + " L" + root.point(0, v1) + " L" + root.point(0, v0) + " Z";
    }

    readonly property string fillPath: root.style === "flush" ? root.flushPath(true) : root.bridgePath(true)
    // Only the screen-side contour gets the hairline; stroking the part lying
    // on the screen edge would draw a line along the bezel.
    readonly property string strokePath: root.style === "flush" ? root.flushPath(false) : root.bridgePath(false)

    ShapePath {
        strokeWidth: -1
        fillColor: QuayTheme.alpha(QuayTheme.base, 0.88)
        PathSvg { path: root.fillPath }
    }

    ShapePath {
        strokeWidth: 1
        strokeColor: QuayTheme.alpha(QuayTheme.text, 0.07)
        fillColor: "transparent"
        PathSvg { path: root.strokePath }
    }
}
