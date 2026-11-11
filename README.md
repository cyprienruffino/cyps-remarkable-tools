# nix-remarkable-sdk

Nix flake for developing apps for the reMarkable Paper Pro family (Paper Pro,
Paper Pro Move), mainly [AppLoad](https://github.com/asivery/rm-appload) apps.

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

## Tablet helpers

Both use the `remarkable` ssh host, set `RM_HOST` to use another one.

- `rm-deploy [--restart] <app directory>` installs an AppLoad app directory
  as `/home/root/xovi/exthome/appload/<directory name>`. It works while the
  app is open, which then needs reopening; new apps show up after tapping
  Reload in AppLoad's menu. It doesn't restart xochitl unless asked to:
  restarting it while an AppLoad app is open can crash it.
- `rm-logs [pattern]` follows xochitl's logs, where AppLoad and its apps log,
  optionally filtered.
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
