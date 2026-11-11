// Copies xochitl's own QML and JavaScript out of its resources, to see how it
// builds its UI. xochitl runs with QML_XHR_ALLOW_FILE_READ/WRITE, so XHR can
// read qrc: files and write them to disk. Paths are flattened, "/" becoming
// "__", since XHR can't create directories.
import QtQuick
import Qt.labs.folderlistmodel

Rectangle {
    id: root
    anchors.fill: parent
    color: "white"

    readonly property string output: "file:///home/root/.cache/xochitl-qml/"
    readonly property var extensions: [".qml", ".js", ".mjs", "qmldir", ".json"]
    property int pendingDirectories: 0
    property int written: 0
    property int failed: 0
    property bool done: false

    function save(name, contents) {
        const request = new XMLHttpRequest()
        request.open("PUT", output + name, false)
        request.send(contents)
    }

    function dumpFile(path) {
        const request = new XMLHttpRequest()
        request.open("GET", "qrc:" + path, false)
        request.send()
        if (request.responseText.length > 0) {
            save(path.substring(1).replace(/\//g, "__"), request.responseText)
            written++
        } else {
            failed++
        }
    }

    function listDirectory(path) {
        pendingDirectories++
        const model = Qt.createQmlObject('import Qt.labs.folderlistmodel; FolderListModel { showDirs: true; showHidden: true; showDotAndDotDot: false; sortField: FolderListModel.Unsorted }', root)
        model.statusChanged.connect(() => {
            if (model.status !== FolderListModel.Ready) {
                return
            }
            for (let i = 0; i < model.count; i++) {
                const name = model.get(i, "fileName")
                const child = path + (path.endsWith("/") ? "" : "/") + name
                if (model.get(i, "fileIsDir")) {
                    listDirectory(child)
                } else if (extensions.some(extension => name.endsWith(extension))) {
                    dumpFile(child)
                }
            }
            pendingDirectories--
            if (pendingDirectories === 0) {
                save("done", written + " files\n")
                done = true
            }
        })
        model.folder = "qrc:" + path
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 64
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: 40
        text: (root.done ? "Done: " : "Copying xochitl's QML… ") + root.written + " files"
            + (root.failed ? ", " + root.failed + " unreadable" : "")
    }

    Component.onCompleted: {
        save("started", "")
        listDirectory("/")
    }
}
