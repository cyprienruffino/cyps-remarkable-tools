# remarkable-sdk

Nix flake for developing apps for the reMarkable Paper Pro family (Paper Pro,
Paper Pro Move), mainly [AppLoad](https://github.com/asivery/rm-appload) apps.

## Dev shell

```sh
nix develop github:cyprienruffino/remarkable-sdk
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
- `rm-deploy` and `rm-logs`, below.

To use it from a project's own flake, take
`inputs.remarkable-sdk.devShells.${system}.default`.

## Tablet helpers

Both use the `remarkable` ssh host, set `RM_HOST` to use another one.

- `rm-deploy [--no-restart] <app directory>` installs an AppLoad app directory
  as `/home/root/xovi/exthome/appload/<directory name>` and restarts xochitl.
  It works while the app's backend is running.
- `rm-logs [pattern]` follows xochitl's logs, where AppLoad and its apps log,
  optionally filtered.

They're also available without the dev shell:

```sh
nix run github:cyprienruffino/remarkable-sdk#rm-deploy -- dist/myapp
```
