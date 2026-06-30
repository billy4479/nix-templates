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
