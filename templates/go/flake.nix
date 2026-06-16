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
            gopls
            golangci-lint
            air

            (pkgs.writeShellScriptBin "init" ''
              set -eu

              if [ -d .git ]; then
                echo "Refusing to initialize: .git already exists" >&2
                exit 1
              fi

              project_name="$(basename "$PWD")"
              module_path="''${1:-}"

              if [ -z "$module_path" ]; then
                printf "GitHub username: "
                read -r github_username

                if [ -z "$github_username" ]; then
                  echo "GitHub username is required" >&2
                  exit 1
                fi

                module_path="github.com/$github_username/$project_name"
              fi

              go mod init "$module_path"
              git init
              git add .
              git commit -m "Initial commit"
            '')
          ];

          nativeBuildInputs = with pkgs; [ go ];
        };

        packages = rec {
          app = pkgs.callPackage ./package.nix { };
          default = app;
        };
      }
    );
}
