{
  description = "Tools for developing reMarkable apps (AppLoad, xovi) on the Paper Pro family";

  # Binaries link against this nixpkgs' glibc, which must not be newer than the
  # device's: 25.11 has glibc 2.40, reMarkable OS 3.29 has 2.43.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        # rm-sdk, a xovi extension adding helpers to xochitl's QML. Built against
        # the host's Qt headers, which match the tablet's Qt version; its Qt
        # symbols resolve against the Qt xochitl has loaded.
        rm-sdk-extension = pkgs.pkgsCross.aarch64-multiplatform.stdenv.mkDerivation {
          pname = "rm-sdk-extension";
          version = "0.3.0";
          src = ./xovi/rm-sdk;
          # Don't embed Nix store library paths
          NIX_DONT_SET_RPATH_aarch64_unknown_linux_gnu = 1;
          NIX_NO_SELF_RPATH = 1;
          buildPhase =
            let
              qtbase = pkgs.qt6.qtbase;
              qtdeclarative = pkgs.qt6.qtdeclarative;
              includes = builtins.concatStringsSep " " (map (dir: "-I${dir}") [
                "${qtbase}/include" "${qtbase}/include/QtCore" "${qtbase}/include/QtGui"
                "${qtdeclarative}/include" "${qtdeclarative}/include/QtQml"
              ]);
            in
            ''
              for header in *.h; do
                ${qtbase}/libexec/moc "$header" -o "moc_''${header%.h}.cpp"
              done
              $CXX -std=c++17 -O2 -fPIC -shared -DQT_NO_DEBUG ${includes} \
                -o rm-sdk.so main.cpp moc_*.cpp xovi-meta.cpp

              # Qt symbols are left undefined on purpose, but undefined symbols
              # of our own classes (e.g. from a header moc didn't process) would
              # only fail when xochitl loads the extension, crashing it. Done
              # here, since check phases don't run when cross-compiling.
              if $NM -D -C --undefined-only rm-sdk.so | grep -E "vtable for [A-PR-Za-z][A-Za-z0-9_]*$| [A-PR-Za-z][A-Za-z0-9_]*::staticMetaObject$"; then
                echo "Undefined symbols of the extension's own classes" >&2
                exit 1
              fi
            '';
          installPhase = "install -Dm644 rm-sdk.so $out/rm-sdk.so";
        };

        # The device side of rm-input, static so it doesn't depend on the tablet's libraries
        rm-input-device = pkgs.pkgsCross.aarch64-multiplatform.stdenv.mkDerivation {
          pname = "rm-input-device";
          version = "0.1.0";
          src = ./rm-input;
          buildInputs = [ pkgs.pkgsCross.aarch64-multiplatform.glibc.static ];
          buildPhase = "$CC -O2 -static -Wall -o rm-input rm-input.c";
          installPhase = "install -Dm755 rm-input $out/bin/rm-input";
        };
        rm-deploy-extension = pkgs.writeShellApplication {
          name = "rm-deploy-extension";
          runtimeInputs = [ pkgs.openssh pkgs.coreutils ];
          text = builtins.readFile ./scripts/rm-deploy-extension.sh;
          # The remote scripts are quoted for the tablet's shell on purpose
          excludeShellChecks = [ "SC2016" "SC2029" ];
        };
        rm-input = pkgs.writeShellApplication {
          name = "rm-input";
          runtimeInputs = [ pkgs.openssh pkgs.coreutils ];
          text = builtins.replaceStrings [ "@rmInputDevice@" ] [ "${rm-input-device}" ] (builtins.readFile ./scripts/rm-input.sh);
          excludeShellChecks = [ "SC2029" ];
        };
        appload-run = pkgs.stdenv.mkDerivation {
          pname = "appload-run";
          version = "0.1.0";
          src = ./appload-run;
          nativeBuildInputs = [ pkgs.cmake pkgs.ninja pkgs.qt6.wrapQtAppsHook ];
          buildInputs = [ pkgs.qt6.qtbase pkgs.qt6.qtdeclarative ];
          meta.mainProgram = "appload-run";
        };
        rm-deploy = pkgs.writeShellApplication {
          name = "rm-deploy";
          runtimeInputs = [ pkgs.openssh pkgs.gnutar ];
          text = builtins.readFile ./scripts/rm-deploy.sh;
          # Paths in the ssh commands are expanded locally on purpose
          excludeShellChecks = [ "SC2029" ];
        };
        rm-screenshot = pkgs.writeShellApplication {
          name = "rm-screenshot";
          runtimeInputs = [ pkgs.openssh ];
          text = builtins.readFile ./scripts/rm-screenshot.sh;
          # The remote script is quoted for the tablet's shell on purpose
          excludeShellChecks = [ "SC2016" "SC2029" ];
        };
        rm-logs = pkgs.writeShellApplication {
          name = "rm-logs";
          runtimeInputs = [ pkgs.openssh ];
          text = builtins.readFile ./scripts/rm-logs.sh;
          excludeShellChecks = [ "SC2029" ];
        };
      });

      templates.appload = {
        path = ./templates/appload;
        description = "AppLoad application with a QML frontend and a C++ backend";
      };
      templates.default = self.templates.appload;

      devShells = forAllSystems (pkgs:
        let
          cross = pkgs.pkgsCross.aarch64-multiplatform;
        in
        {
          default = pkgs.mkShell {
            packages = [
              cross.buildPackages.gcc
              pkgs.cmake
              pkgs.ninja
              pkgs.pkg-config
              pkgs.python3
              # rcc, qml and qmltestrunner, for AppLoad frontends
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              self.packages.${pkgs.stdenv.hostPlatform.system}.appload-run
              self.packages.${pkgs.stdenv.hostPlatform.system}.rm-deploy
              self.packages.${pkgs.stdenv.hostPlatform.system}.rm-logs
              self.packages.${pkgs.stdenv.hostPlatform.system}.rm-screenshot
              self.packages.${pkgs.stdenv.hostPlatform.system}.rm-input
              self.packages.${pkgs.stdenv.hostPlatform.system}.rm-deploy-extension
            ];

            RM_TOOLCHAIN_FILE = "${self}/cmake/aarch64-remarkable.cmake";
            # Don't embed Nix store library paths in device binaries
            NIX_DONT_SET_RPATH_aarch64_unknown_linux_gnu = 1;
            NIX_NO_SELF_RPATH = 1;
            RCC_EXECUTABLE = "${pkgs.qt6.qtbase}/libexec/rcc";
            QT_PLUGIN_PATH = "${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}";
            QML2_IMPORT_PATH = "${pkgs.qt6.qtdeclarative}/${pkgs.qt6.qtbase.qtQmlPrefix}";

            # rcc lives in libexec
            shellHook = ''
              export PATH="$PATH:${pkgs.qt6.qtbase}/libexec"
            '';
          };
        });
    };
}
