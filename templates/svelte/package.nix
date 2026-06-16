{
  lib,
  stdenv,
  pnpm_11,
  pnpmConfigHook,
  fetchPnpmDeps,
  nodejs,
}:
stdenv.mkDerivation (finalAttrs: {
  pname =
    if builtins.pathExists ./package.json then
      (builtins.fromJSON (builtins.readFile ./package.json)).name
    else
      "app";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [
    pnpm_11
    pnpmConfigHook
  ];

  buildInputs = [ nodejs ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = lib.fakeHash;
    fetcherVersion = 3;
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/${finalAttrs.pname}"

    if [ -d build ]; then
      cp -r build "$out/share/${finalAttrs.pname}/"
    elif [ -d .svelte-kit/output ]; then
      cp -r .svelte-kit/output "$out/share/${finalAttrs.pname}/"
    else
      cp -r .svelte-kit "$out/share/${finalAttrs.pname}/"
    fi

    runHook postInstall
  '';
})
