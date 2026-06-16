{
  lib,
  stdenv,
  pnpm_11,
  pnpmConfigHook,
  fetchPnpmDeps,
  nodejs,
  makeWrapper,
}:
let
  packageJson =
    if builtins.pathExists ./package.json then
      builtins.fromJSON (builtins.readFile ./package.json)
    else
      {
        name = "app";
        version = "0.1.0";
      };
in
stdenv.mkDerivation (finalAttrs: {
  pname = packageJson.name;
  version = packageJson.version;
  src = ./.;

  nativeBuildInputs = [
    pnpm_11
    pnpmConfigHook
    makeWrapper
  ];

  buildInputs = [ nodejs ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = lib.fakeHash;
    fetcherVersion = 3;
  };

  buildPhase = ''
    runHook preBuild
    pnpm run --if-present build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/${finalAttrs.pname}"
    cp package.json pnpm-lock.yaml "$out/share/${finalAttrs.pname}/"

    if [ -f pnpm-workspace.yaml ]; then
      cp pnpm-workspace.yaml "$out/share/${finalAttrs.pname}/"
    fi

    for dir in dist build lib; do
      if [ -d "$dir" ]; then
        cp -r "$dir" "$out/share/${finalAttrs.pname}/"
      fi
    done

    if [ -f index.js ]; then
      cp index.js "$out/share/${finalAttrs.pname}/"
    fi

    cd "$out/share/${finalAttrs.pname}"
    pnpm_config_store_dir="$STORE_PATH" pnpm install --prod --offline --frozen-lockfile --node-linker=hoisted --ignore-scripts

    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe nodejs} "$out/bin/${finalAttrs.pname}" \
      --chdir "$out/share/${finalAttrs.pname}" \
      --add-flags "${packageJson.main or "index.js"}"

    runHook postInstall
  '';
})
