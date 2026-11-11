// Turns xochitl's pen debug messages on until xochitl restarts, to log what a
// real notebook does with the pen.
import QtQuick
import RmSdk

Rectangle {
    anchors.fill: parent
    color: "white"

    Text {
        anchors.centerIn: parent
        width: parent.width - 64
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 36
        text: "Pen debug logging is on.\n\nClose this, open a notebook, and write a few strokes."
    }

    Component.onCompleted: {
        Logging.setFilterRules(["rm.peninput", "rm.digitizer", "rm.ui.scenepeninputhandler", "rm.stroke",
                                "xofm.modules.devicesceneview.screendriver"]
            .map(category => category + ".debug=true").join("\n"))
        console.log("PROBE pen debug logging on")
    }
}
