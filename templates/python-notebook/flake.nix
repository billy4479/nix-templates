{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        pyPkgs = pkgs.python3.withPackages (
          python-pkgs: with python-pkgs; [
            numpy
            pandas
            matplotlib

            jupyterlab

            marimo
            watchdog

            python-lsp-server
            python-lsp-ruff
          ]
        );
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pyPkgs ];

          packages = with pkgs; [
            ruff
            marimo

            (pkgs.writeShellScriptBin "init" ''
              set -eu

              if [ -d .git ]; then
                echo "Refusing to initialize: .git already exists" >&2
                exit 1
              fi

              project_name="$(basename "$PWD")"
              notebook_name="''${1:-$project_name.py}"

              if [ -e "$notebook_name" ]; then
                echo "Refusing to overwrite $notebook_name" >&2
                exit 1
              fi

              cat > "$notebook_name" <<'EOF'
              import marimo

              __generated_with = "${pkgs.python3.pkgs.marimo.version}"
              app = marimo.App(width="medium")


              @app.cell
              def _():
                  import matplotlib.pyplot as plt
                  import marimo as mo
                  import numpy as np
                  import pandas as pd

                  return mo, np, pd, plt


              @app.cell
              def _(mo):
                  mo.md("# Notebook")
                  return


              if __name__ == "__main__":
                  app.run()
              EOF

              git init
              git add .
              git commit -m "Initial commit"
            '')
          ];
        };
      }
    );
}
