# cyps-remarkable-tools

Tools and libs for developing apps for the reMarkable Paper Pro family (Paper Pro,
Paper Pro Move), mainly [AppLoad](https://github.com/asivery/rm-appload) apps.
Enabled by a Nix flake

## Dev shell

```sh
nix develop github:cyprienruffino/nix-remarkable-sdk
```

It provides:

- `aarch64-unknown-linux-gnu-gcc`/`g++`, a cross compiler for the tablet, and
  `$RM_TOOLCHAIN_FILE`, a CMake toolchain file using it:
  ```sh
  cmake -B build -DCMAKE_TOOLCHAIN_FILE=$RM_TOOLCHAIN_FILE
  ```
  Binaries use the device's dynamic linker and link libstdc++ statically, so
  they only depend on the device's glibc. nixpkgs is pinned to a release whose
  glibc (2.40) is older than reMarkable OS's (2.43 on 3.29).
- `rcc`, `qml` and `qmltestrunner` (Qt 6), to pack, preview and test AppLoad
  QML frontends on a PC.
- `cmake`, `ninja`, `pkg-config` and `python3`.
- `appload-run`, `rm-deploy`, `rm-logs`, `rm-screenshot` and `rm-input`, below.

## Starting an app

```sh
nix flake init -t github:cyprienruffino/nix-remarkable-sdk
```

creates an AppLoad app with a QML frontend and a C++ backend, see its README.
`backend/appload.h` is a header-only client for AppLoad's backend protocol.

## Running apps on a PC

`appload-run <app directory>` stands in for AppLoad: it provides the
`net.asivery.AppLoad` QML module, starts the app's real backend over the same
socket protocol, and shows the frontend at the Paper Pro Move's resolution
(`--size pro` for the Paper Pro, or `WIDTHxHEIGHT`). Apps can use some of
xochitl's own QML modules, which `appload-run` replaces with stand-ins that do
nothing (see `appload-run/stubs`):

- `xofm.libs.epaper`: `ScreenModeItem { mode: ScreenModeItem.Pen }` makes the
  area it covers refresh with the fast, low latency waveform xochitl uses for
  ink, e.g. over a drawing area.

For testing, `--tap X,Y` clicks and `--stroke X1,Y1:X2,Y2:...` drags like a
pen (both repeatable) before `--screenshot file.png` saves the window and quits; with `QT_QPA_PLATFORM=offscreen` it needs no
display:

```sh
QT_QPA_PLATFORM=offscreen appload-run --tap 477,890 --screenshot shot.png dist-pc/myapp
```

To use it from a project's own flake, take
`inputs.remarkable-sdk.devShells.${system}.default`.

## Native ink

`templates/appload/ui/NativeInk.qml` lets apps write with the pen as fast as
in a notebook, using xochitl's own pen pipeline (`PenInputSurface` and
`ScenePenInputHandler`, which AppLoad apps can create). It needs the rm-sdk
extension, and falls back to drawing with the mouse elsewhere, e.g. in
`appload-run`.

xochitl draws the ink live but doesn't give the strokes to apps, so the app's
backend records them from the digitizer with `templates/appload/backend/pen_strokes.h`
and passes them to `NativeInk.addScreenStroke()`, which keeps and draws them;
the eraser end erases the ink it passes over. See Dice & Life's notes page for
a complete example.

What it took, for the curious: xochitl's pen manager only routes the pen to
input surfaces on its main window item (the one with a `penInput` property),
so `NativeInk` puts its surface there, over itself, instead of inside AppLoad's
window, where the manager finds no area to draw in and hands the pen to the UI
as a mouse. The surface and handler also need `setTransform()` with real
`QTransform`s, which is why the extension exists. `Logging.setFilterRules()`
with `rm.peninput`, `rm.digitizer` and `rm.stroke` shows the whole pipeline.

## The rm-sdk xovi extension

`xovi/rm-sdk` is a small [xovi](https://github.com/asivery/xovi) extension
adding helpers to xochitl's QML, for AppLoad apps to use with xochitl's own
types. It's built with `nix build .#rm-sdk-extension` and installed with
`rm-deploy-extension result/rm-sdk.so`. It provides:

- `import RmSdk`, `Transforms.identity()` and `Transforms.fromValues(m11, m12,
  m21, m22, dx, dy)`: QTransform values, which QML can't create, for xochitl
  types that need them.
- `Inspector.describe(object)`: any object's classes, typed properties, and
  method and signal signatures, from Qt's metadata, to see how xochitl's own
  types work.
- `Logging.setFilterRules(rules)`: switches logging categories while xochitl
  runs, e.g. `"rm.peninput.debug=true"` to see xochitl's own debug messages.

Extensions are compiled with the cross compiler against the host Qt's headers,
which match the tablet's Qt version (6.10); their Qt symbols resolve against
the Qt xochitl has loaded, so they don't link to it. The `.xovi` metadata
xovi expects is written by hand in `xovi-meta.cpp`.

`appload-run` has a stand-in for `RmSdk`, so apps using it still load on a PC.

## Tablet helpers

Both use the `remarkable` ssh host, set `RM_HOST` to use another one.

- `rm-deploy [--restart] <app directory>` installs an AppLoad app directory
  as `/home/root/xovi/exthome/appload/<directory name>`. Tap Reload in
  AppLoad's menu to load it: until then AppLoad keeps using the app's previous
  frontend, even when reopening it. It doesn't restart xochitl unless asked to:
  restarting it while an AppLoad app is open can crash it.
- `rm-logs [pattern]` follows xochitl's logs, where AppLoad and its apps log,
  optionally filtered.
- `rm-deploy-extension <extension.so>` installs a xovi extension and restarts
  xochitl to load it. A broken extension crashes xochitl on every start, so it
  refuses to run while an AppLoad app is open, checks that xochitl came back
  with xovi, and removes the extension again if it didn't.
- `rm-screenshot [output.png]` takes a screenshot of the tablet and copies it
  here. It needs the [rm-shot](https://github.com/rmitchellscott/rm-shot) xovi
  extension, and refuses to run until xochitl has been up for 30s: rm-shot
  crashes xochitl when asked for a screenshot while it's starting.
- `rm-input tap X Y`, `rm-input swipe X1 Y1 X2 Y2 [ms]` and
  `rm-input pen X1,Y1 X2,Y2 ... [/ X1,Y1 ...]` (`/` lifting the pen between
  strokes, for letters like P) simulate a finger or the pen, in screen
  pixels, by writing events to the touchscreen and digitizer, which xochitl
  handles like real ones. With `rm-screenshot`, that's enough to drive the
  tablet remotely, e.g. to open an app from AppLoad's menu and test it.
  Take a fresh screenshot before each tap: the screen may have changed.
  Taps mirror what a real finger sends, which `rm-input record [touch|pen]`
  prints for comparison. To close a fullscreen AppLoad app, swipe down from
  the top center (`rm-input swipe 477 0 477 250`) and tap the X right away,
  before AppLoad's title bar hides again.

They're also available without the dev shell:

```sh
nix run github:cyprienruffino/nix-remarkable-sdk#rm-deploy -- dist/myapp
```
