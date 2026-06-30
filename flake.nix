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
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = pkgs.writeShellApplication {
          name = "nix-templates-fmt";
          runtimeInputs = [ pkgs.nixfmt ];
          text = ''
            if [ "$#" -eq 0 ]; then
              set -- \
                flake.nix \
                templates/go/flake.nix \
                templates/go/package.nix \
                templates/node/flake.nix \
                templates/node/package.nix \
                templates/svelte/flake.nix \
                templates/svelte/package.nix \
                templates/android/flake.nix \
                templates/rust/flake.nix \
                templates/zig/flake.nix \
                templates/python-notebook/flake.nix \
                templates/python-app/flake.nix
            fi

            exec nixfmt "$@"
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixd
            nixfmt
          ];
        };
      }
    )
    // {
      templates = {
        go = {
          path = ./templates/go;
          description = "Go application with buildGoModule";
        };

        node = {
          path = ./templates/node;
          description = "Node/pnpm application";
        };

        svelte = {
          path = ./templates/svelte;
          description = "SvelteKit application";
        };

        android = {
          path = ./templates/android;
          description = "Android Kotlin Jetpack Compose application";
        };

        rust = {
          path = ./templates/rust;
          description = "Rust application with buildRustPackage";
        };

        zig = {
          path = ./templates/zig;
          description = "Zig application";
        };

        python-notebook = {
          path = ./templates/python-notebook;
          description = "Python Marimo notebook project";
        };

        python-app = {
          path = ./templates/python-app;
          description = "Python application with buildPythonApplication";
        };

        default = self.templates.go;
      };
    };
}
