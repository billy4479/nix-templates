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
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            typescript-language-server
            svelte-language-server
            tailwindcss-language-server

            (pkgs.writeShellScriptBin "prettier" ''
              exec pnpm exec prettier "$@"
            '')

            (pkgs.writeShellScriptBin "init" ''
              set -eu

              if [ -d .git ]; then
                echo "Refusing to initialize: .git already exists" >&2
                exit 1
              fi

              tmp="$(mktemp -d)"
              cleanup() {
                rm -rf "$tmp"
              }
              trap cleanup EXIT

              pnpm dlx sv create "$tmp" --template minimal --types ts --no-add-ons --install pnpm
              cp -a "$tmp"/. .

              git init
              git add .
              git commit -m "Initial commit"
            '')
          ];

          nativeBuildInputs = with pkgs; [
            nodejs_latest
            pnpm_11
          ];
        };

        packages = rec {
          app = pkgs.callPackage ./package.nix { };
          default = app;
        };
      }
    );
}
