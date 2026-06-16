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

            (pkgs.writeShellScriptBin "prettier" ''
              exec pnpm exec prettier "$@"
            '')

            (pkgs.writeShellScriptBin "ts" ''
              exec node --experimental-strip-types "$@"
            '')

            (pkgs.writeShellScriptBin "init" ''
              set -eu

              if [ -d .git ]; then
                echo "Refusing to initialize: .git already exists" >&2
                exit 1
              fi

              project_name="$(basename "$PWD" | tr '[:upper:] _' '[:lower:]--')"

              pnpm init -y
              node -e '
                const fs = require("fs");
                const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
                pkg.name = process.argv[1];
                pkg.version = "0.1.0";
                pkg.scripts = {
                  ...pkg.scripts,
                  ts: "node --experimental-strip-types",
                  typecheck: "tsc --noEmit",
                };
                fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
              ' "$project_name"

              pnpm add --save-dev typescript @types/node
              pnpm exec tsc --init

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
