import QtQuick
import net.asivery.AppLoad 1.0

Rectangle {
    id: root
    anchors.fill: parent
    color: "white"

    // Must match backend/main.cpp
    readonly property int msgShout: 1
    readonly property int msgReady: 100
    readonly property int msgShouted: 101

    // Called by AppLoad when the app is closed; stops the backend
    function unloading() {
        backend.terminate()
    }

    AppLoad {
        id: backend
        applicationID: "myapp" // must match manifest.json
        onMessageReceived: (type, contents) => {
            switch (type) {
            case root.msgReady:
                status.text = "Backend ready, tap the button"
                break
            case root.msgShouted:
                status.text = contents
                break
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 32

        Text {
            id: status
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Waiting for the backend…"
            font.pixelSize: 40
        }

        // The pen arrives as mouse events, fingers as touches: TapHandler takes both
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            height: 120
            radius: 12
            border.width: 4
            color: tap.pressed ? "black" : "white"

            Text {
                anchors.centerIn: parent
                text: "Shout"
                font.pixelSize: 40
                color: tap.pressed ? "white" : "black"
            }
            TapHandler {
                id: tap
                onTapped: backend.sendMessage(root.msgShout, "hello from qml")
            }
        }
    }
}
