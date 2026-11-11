// Stand-in for the rm-sdk xovi extension's Transforms, which gives QML real
// QTransform values on the tablet. On a PC, plain objects with the same values.
pragma Singleton
import QtQuick

QtObject {
    function identity() { return fromValues(1, 0, 0, 1, 0, 0) }
    function fromValues(m11, m12, m21, m22, dx, dy) { return { m11, m12, m21, m22, dx, dy } }
    function describe(transform) { return "QTransform(" + [transform.m11, transform.m12, transform.m21, transform.m22, transform.dx, transform.dy].join(", ") + ")" }
}
