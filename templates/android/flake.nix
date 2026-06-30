{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        platformVersion = "36";
        buildToolsVersion = "36.0.0";
        systemImageType = "google_apis";
        abiVersion = "x86_64";
        systemImagePackage = "system-images;android-${platformVersion};${systemImageType};${abiVersion}";

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ platformVersion ];
          buildToolsVersions = [ buildToolsVersion ];
          includeEmulator = "if-supported";
          includeSystemImages = true;
          includeCmake = false;
          includeNDK = false;
          includeSources = true;
          systemImageTypes = [ systemImageType ];
          abiVersions = [ abiVersion ];
        };

        androidSdk = androidComposition.androidsdk;
      in
      {
        devShells.default = pkgs.mkShell rec {
          JAVA_HOME = pkgs.jdk21.home;
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = ANDROID_HOME;
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_HOME}/build-tools/${buildToolsVersion}/aapt2";

          packages = with pkgs; [
            gradle
            git
            jdk21
            kotlin-language-server
            android-tools

            (pkgs.writeShellScriptBin "create-avd" ''
              set -eu

              avd_name="''${1:-compose-api${platformVersion}}"
              avd_home="''${ANDROID_AVD_HOME:-$HOME/.android/avd}"

              mkdir -p "$avd_home"

              if [ -d "$avd_home/$avd_name.avd" ]; then
                echo "AVD already exists: $avd_name"
                exit 0
              fi

              printf 'no\n' | avdmanager create avd \
                --name "$avd_name" \
                --package "${systemImagePackage}"
            '')

            (pkgs.writeShellScriptBin "run-emulator" ''
              set -eu

              avd_name="''${1:-compose-api${platformVersion}}"
              if [ "$#" -gt 0 ]; then
                shift
              fi

              avd_home="''${ANDROID_AVD_HOME:-$HOME/.android/avd}"
              if [ ! -d "$avd_home/$avd_name.avd" ]; then
                create-avd "$avd_name"
              fi

              exec emulator -avd "$avd_name" "$@"
            '')
          ];

          shellHook = ''
            export ANDROID_AVD_HOME="''${ANDROID_AVD_HOME:-$HOME/.android/avd}"
            for android_tool_dir in "$ANDROID_HOME/tools/bin" "$ANDROID_HOME/cmdline-tools/"*/bin; do
              if [ -d "$android_tool_dir" ]; then
                export PATH="$android_tool_dir:$PATH"
              fi
            done
            export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
          '';
        };
      }
    );
}
