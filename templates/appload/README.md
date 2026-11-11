# My App

An [AppLoad](https://github.com/asivery/rm-appload) application for the reMarkable Paper Pro family.

- `ui/`: the QML frontend, loaded by AppLoad inside xochitl
- `backend/`: the backend process, talking to the frontend over AppLoad's
  socket through `backend/appload.h`

To rename it, change `myapp` in `manifest.json`, `ui/main.qml` and `CMakeLists.txt`.

## Building

In `nix develop`:

```sh
# On the PC, with the backend, at the Paper Pro Move's resolution
cmake -B build-pc -G Ninja && cmake --build build-pc
cmake --install build-pc --prefix dist-pc/myapp
appload-run dist-pc/myapp

# On the tablet
cmake -B build-rm -G Ninja -DCMAKE_TOOLCHAIN_FILE=$RM_TOOLCHAIN_FILE && cmake --build build-rm
cmake --install build-rm --prefix dist/myapp
rm-deploy dist/myapp
rm-logs myapp
```
