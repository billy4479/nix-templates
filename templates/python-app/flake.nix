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

        pyPkgs = pkgs.python3.withPackages (
          python-pkgs: with python-pkgs; [
            python-lsp-server
            python-lsp-ruff
          ]
        );
      in
      {
        packages = rec {
          app = pkgs.python3.pkgs.buildPythonApplication {
            pname =
              if builtins.pathExists ./pyproject.toml then
                (builtins.fromTOML (builtins.readFile ./pyproject.toml)).project.name
              else
                "app";
            version = "0.1.0";
            src = ./.;
            pyproject = true;

            nativeBuildInputs = with pkgs.python3.pkgs; [
              setuptools
              wheel
            ];
          };
          default = app;
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [ pyPkgs ];

          packages = with pkgs; [
            ruff
          ];
        };
      }
    );
}
