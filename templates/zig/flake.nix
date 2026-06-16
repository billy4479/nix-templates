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
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = rec {
          app = pkgs.stdenv.mkDerivation {
            pname = "app";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = with pkgs; [ zig ];

            buildPhase = ''
              runHook preBuild
              zig build --prefix $out
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              runHook postInstall
            '';
          };
          default = app;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            zls

            (pkgs.writeShellScriptBin "init" ''
              set -eu

              if [ -d .git ]; then
                echo "Refusing to initialize: .git already exists" >&2
                exit 1
              fi

              zig init
              git init
              git add .
              git commit -m "Initial commit"
            '')
          ];

          nativeBuildInputs = with pkgs; [ zig ];
        };
      }
    );
}
