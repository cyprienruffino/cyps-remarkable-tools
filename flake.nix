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
      packages = forAllSystems (pkgs: {
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
