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

        projectName =
          let
            cmakeLists =
              if builtins.pathExists ./CMakeLists.txt then builtins.readFile ./CMakeLists.txt else "";
            matches = builtins.filter builtins.isList (builtins.split ''project\(([A-Za-z0-9_-]+)'' cmakeLists);
            name = if matches == [ ] then null else builtins.elemAt (builtins.head matches) 0;
          in
          if name == null then "app" else name;
      in
      {
        packages = rec {
          app = pkgs.stdenv.mkDerivation {
            pname = projectName;
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = with pkgs; [
              cmake
              ninja
            ];
          };
          default = app;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            ccache
            clang-tools
            cmake
            gdb
            ninja
          ];

          env = {
            CMAKE_CXX_COMPILER_LAUNCHER = "ccache";
            CMAKE_GENERATOR = "Ninja";
          };
        };
      }
    );
}
