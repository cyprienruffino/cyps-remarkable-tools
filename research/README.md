# Research apps

AppLoad apps used to work out how xochitl's native ink works, kept for
reference and for digging further. Neither is needed to use `NativeInk.qml`.
Both need the rm-sdk extension. To try one, pack and install it like any app:

```sh
cd research/ink-probe && rcc --binary -o resources.rcc application.qrc
ssh remarkable mkdir -p /home/root/xovi/exthome/appload/ink-probe
scp manifest.json resources.rcc remarkable:/home/root/xovi/exthome/appload/ink-probe/
```

then tap Reload in AppLoad's menu.

- `ink-probe`: the last version (v16) of the probe that got native ink working.
  It finds xochitl's `PenInput`, creates a `PenInputSurface` with a
  `ScenePenInputHandler` and a `ScreenDriver`, moves the surface onto xochitl's
  main window item, and logs (`journalctl -u xochitl | grep PROBE`) the
  pen manager's region, active inputs, and finished strokes with
  `Inspector.describeValue()`.
- `pen-debug-log`: turns xochitl's pen debug messages on until xochitl
  restarts, to see what a real notebook does with the pen.

What the probes found, in order:

1. The pen types are QML types xochitl registers, in `com.remarkable`
   (`PenInputSurface`, `PenInputLineHandler`, `SceneView`) and
   `xofm.libs.devicesceneview` (`ScenePenInputHandler`); `ScreenDriver` is in
   `xofm.modules.devicesceneview`. Creating them from an app doesn't crash.
2. The live `PenInput` is the `penInput` property of xochitl's main window
   item (`legacydevice/window/main`), up the `parent` chain from the app.
3. `setTransform()` needs a real `QTransform`, which QML can't create: hence
   the rm-sdk extension's `Transforms`.
4. With xochitl's debug logging on, a notebook shows the sequence:
   `* stroke … (pen-down)`, `begin stroke`, `New StrokeRenderer`, points, `end
   stroke`. Notebooks don't use `PenInput.setFilterEvents()`.
5. Inside AppLoad's window the pen manager's region stays empty and the
   digitizer treats the pen as a mouse (`begin of mouse event`). On the main
   window item, the region is the surface, and the ink appears.
6. `strokeCompleted(Line)` gives the tool (eraser included) and bounding box,
   but not the points: apps record those from the digitizer
   (`pen_strokes.h`), which maps straight to the screen.

Reading or listing xochitl's `qrc:` resources from an app crashes xochitl:
don't.
