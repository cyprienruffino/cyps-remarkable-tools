// Stand-in for the rm-sdk xovi extension's Inspector, which describes
// xochitl's C++ types on the tablet.
pragma Singleton
import QtQuick

QtObject {
    function describe(object) { return "Inspector is only available on the tablet, with the rm-sdk extension" }
    function describeValue(value) { return describe(value) }
}
