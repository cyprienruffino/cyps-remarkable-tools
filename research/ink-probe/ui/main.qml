// Draws with xochitl's native pen surface, logging where pen events go.
import QtQuick
import com.remarkable
import xofm.libs.epaper as Epaper
import RmSdk
import xofm.libs.devicesceneview
import xofm.modules.devicesceneview as SceneModules

Rectangle {
    id: root
    anchors.fill: parent
    color: "white"

    function log(...args) {
        console.log("PROBE", ...args)
    }

    property var penInputOwner: null

    function findPenInput() {
        let top = root
        while (top.parent) {
            top = top.parent
        }
        const queue = [top]
        while (queue.length > 0) {
            const item = queue.shift()
            if (item !== root && ("penInput" in item) && item.penInput) {
                penInputOwner = item
                return item.penInput
            }
            for (const child of item.children) {
                queue.push(child)
            }
        }
        return null
    }

    readonly property var penInput: findPenInput()

    function tryCall(name, call) {
        try {
            log(name, "->", call())
        } catch (error) {
            log(name, "failed:", error)
        }
    }

    // Maps the surface with real QTransforms from the rm-sdk extension
    function refresh(reason) {
        log("refresh", reason, "surface", surface.width, surface.height, "at", surface.mapToGlobal(0, 0))
        const identity = Transforms.identity()
        log("identity", Transforms.describe(identity))
        tryCall("surface.setTransform(identity)", () => surface.setTransform(identity))
        tryCall("handler.setTransform(identity, identity)", () => sceneHandler.setTransform(identity, identity))
        // What the surface does with pen positions: digitizer units (6760 x 11960
        // on the Move) or screen pixels?
        for (const point of [[0, 0], [954, 1696], [3380, 5980], [6760, 11960]]) {
            tryCall("mapPenPositionToLocal(" + point + ")", () => surface.mapPenPositionToLocal(Qt.point(point[0], point[1])))
        }
        if (penInput) {
            tryCall("manager.registerInput(surface)", () => penInput.surfaceManager.registerInput(surface))
            tryCall("manager.updateRegions()", () => penInput.surfaceManager.updateRegions())
            tryCall("manager.region", () => penInput.surfaceManager.region)
        }
    }

    Text {
        x: 24
        y: 24
        font.pixelSize: 32
        text: "v16: write one stroke in the lower part of the screen"
    }

    PenInputLineHandler {
        id: lineHandler
        sampleRate: root.penInput ? root.penInput.sampleRate : 0
        lineThickness: 2
        onStroke: line => { const keys = []; for (const key in line) keys.push(key); root.log("STROKE", line, "fields:", keys.join(",")) }
    }

    // The notebook's handler; it needs no document of its own
    ScenePenInputHandler {
        id: sceneHandler
        sampleRate: root.penInput ? root.penInput.sampleRate : 0
        lineThickness: 2
        onStrokeCompleted: stroke => {
            const keys = []
            for (const key in stroke) keys.push(key)
            root.log("STROKE COMPLETED", stroke, "pointCount", stroke.pointCount, "boundingRect", stroke.boundingRect)
            root.log("DESCRIBE Line\n" + Inspector.describeValue(stroke))
        }
        onStroke: line => root.log("STROKE", line)
        onGestureStarted: (...args) => root.log("gesture started", args.length)
        onGesturesRejected: (...args) => root.log("gestures rejected", args.length)
    }

    PenInputSurface {
        id: surface
        anchors {
            fill: parent
            topMargin: 90
        }
        handler: sceneHandler
        manager: root.penInput ? root.penInput.surfaceManager : null
        onWidthChanged: Qt.callLater(root.refresh, "width")
        onHeightChanged: Qt.callLater(root.refresh, "height")
    }

    // Nothing may overlap the surface: the pen manager subtracts items on top of it

    Connections {
        target: root.penInput
        function onPenDownChanged() { root.log("penDown changed") }
        function onPenCloseChanged(close) {
            root.penClose = close
            root.log("penClose", close, "screen mode", root.screenDriver ? root.screenDriver.globalMode : "-")
        }
    }
    Connections {
        target: root.penInput ? root.penInput.surfaceManager : null
        function onActiveInputsChanged(inputs) {
            root.log("active inputs:", inputs.length, inputs.map(input => String(input)).join(", "),
                "ours:", inputs.indexOf(sceneHandler) !== -1)
        }
        function onRegionChanged(region) { root.log("manager region changed:", region) }
    }

    property bool penClose: false
    // Like the notebook view, which drives the e-ink panel's modes through it
    SceneModules.ScreenDriver {
        id: screenDriverObject
        notePage: true
        visible: true
        pendingTiles: false
        penClose: root.penClose
        gestureMode: false
        selectionMode: false
        textMode: false
        snapMode: false
        quickBrowseMode: false
        activeTool: sceneHandler.lineTool
        onGlobalModeChanged: root.log("screen driver global mode", globalMode)
    }
    readonly property var screenDriver: screenDriverObject

    // Like the notebook view: the ScreenDriver probably puts the e-ink panel
    // in pen mode while writing
    function createScreenDriver() {
        for (const module of ["xofm.libs.devicesceneview", "xofm.modules.devicesceneview", "com.remarkable",
                              "xofm.libs.devicescreen", "xofm.libs.epaper", "xofm.libs.sceneview"]) {
            try {
                const driver = Qt.createQmlObject("import " + module + "; ScreenDriver { visible: true }", root)
                log("ScreenDriver created from", module)
                log("DESCRIBE ScreenDriver\n" + Inspector.describe(driver))
                try { driver.notePage = true } catch (error) { log("notePage:", error) }
                try { driver.activeTool = Qt.binding(() => lineHandler.lineTool) } catch (error) { log("activeTool:", error) }
                try { driver.penClose = Qt.binding(() => root.penClose) } catch (error) { log("penClose:", error) }
                return driver
            } catch (error) {
                log("ScreenDriver not in", module, String(error).replace(/\n/g, " ").substring(0, 160))
            }
        }
        return null
    }

    // PenInputBlockers mark areas where the pen acts as a mouse; one covering
    // the screen would leave the pen nowhere to draw. Disabled while this is
    // open, and restored exactly as they were.
    property var disabledBlockers: []

    function findBlockers() {
        let top = root
        while (top.parent) {
            top = top.parent
        }
        const found = []
        const queue = [top]
        while (queue.length > 0) {
            const item = queue.shift()
            if (String(item).startsWith("PenInputBlocker")) {
                found.push(item)
            }
            for (const child of item.children) {
                queue.push(child)
            }
        }
        return found
    }

    function disableBlockers() {
        const blockers = findBlockers()
        log("blockers found:", blockers.length)
        for (const blocker of blockers) {
            const position = blocker.mapToGlobal(0, 0)
            log("blocker", blocker, "objectName", blocker.objectName, "at", position.x, position.y, "size", blocker.width, blocker.height,
                "visible", blocker.visible, "enabled", blocker.enabled)
            if (blocker.enabled) {
                blocker.enabled = false
                disabledBlockers.push(blocker)
            }
        }
        if (penInput) {
            tryCall("manager.updateRegions() after disabling blockers", () => penInput.surfaceManager.updateRegions())
            tryCall("manager.region after disabling blockers", () => penInput.surfaceManager.region)
        }
    }

    function restoreBlockers() {
        for (const blocker of disabledBlockers) {
            try { blocker.enabled = true } catch (error) { log("restore failed:", error) }
        }
        log("restored blockers:", disabledBlockers.length)
        disabledBlockers = []
        if (penInput) {
            tryCall("manager.updateRegions() after restoring", () => penInput.surfaceManager.updateRegions())
        }
    }

    // Take the pen away from normal event handling while this is open, like a
    // notebook probably does, and always give it back
    function setFilterEvents(enabled) {
        if (penInput) {
            tryCall("penInput.setFilterEvents(" + enabled + ")", () => penInput.setFilterEvents(enabled))
        }
    }
    function debugRules(enabled) {
        return ["rm.peninput", "rm.digitizer", "rm.ui.scenepeninputhandler", "rm.stroke",
                "xofm.modules.devicesceneview.screendriver", "xofm.libs.epaper", "xofm.modules.epaper"]
            .map(category => category + ".debug=" + enabled).join("\n")
    }

    function unloading() {
        Logging.setFilterRules(debugRules(false))
        setFilterEvents(false)
        restoreBlockers()
    }
    Component.onDestruction: {
        Logging.setFilterRules(debugRules(false))
        setFilterEvents(false)
        restoreBlockers()
    }

    Timer {
        // Only once everything is mapped
        interval: 500
        running: true
        onTriggered: {
            // Move the surface out of AppLoad's window, onto xochitl's main
            // window item, in case the pen manager can't see it in there
            const owner = root.penInputOwner
            root.log("reparenting surface onto", owner, "size", owner.width, owner.height)
            surface.anchors.fill = undefined
            surface.parent = owner
            surface.x = 0
            surface.y = 200
            surface.width = owner.width
            surface.height = owner.height - 200
            surface.z = 100000
            root.refresh("reparented")
            if (root.penInput) {
                root.tryCall("manager.updateRegions() before writing", () => root.penInput.surfaceManager.updateRegions())
                root.tryCall("manager.region before writing", () => root.penInput.surfaceManager.region)
            }
        }
    }

    Component.onCompleted: {
        log("native ink v16 start, penInput", penInput)
        // xochitl's own pen debug messages, off by default
        Logging.setFilterRules(debugRules(true))
        log("DESCRIBE ScreenDriver\n" + Inspector.describe(screenDriver))
        refresh("start")
    }
}
