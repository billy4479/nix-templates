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
          app = pkgs.rustPlatform.buildRustPackage {
            pname =
              if builtins.pathExists ./Cargo.toml then
                (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.name
              else
                "app";
            version = "0.1.0";
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
          };
          default = app;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cargo
            rust-analyzer
            rustfmt
            clippy

            (pkgs.writeShellScriptBin "init" ''
              set -eu

              if [ -d .git ]; then
                echo "Refusing to initialize: .git already exists" >&2
                exit 1
              fi

              project_name="$(basename "$PWD")"
              cargo init --bin --name "$project_name" .
              cargo generate-lockfile
              git init
              git add .
              git commit -m "Initial commit"
            '')
          ];
        };
      }
    );
}
