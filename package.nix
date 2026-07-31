{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
, glibc ? null
}:

let
  version = "1.10.1";

  sources = {
    "aarch64-darwin" = {
      asset = "pup_${version}_Darwin_arm64.tar.gz";
      hash = "sha256-JpFrl8PxB24iDv37Wpw9TsMq+it4CdXTcg0Sod6UsVY=";
    };
    "x86_64-darwin" = {
      asset = "pup_${version}_Darwin_x86_64.tar.gz";
      hash = "sha256-xhFw/9pz7bGeOCAyI3uQjhx/FQ0zh5yVsQN9YqXhwfo=";
    };
    "aarch64-linux" = {
      asset = "pup_${version}_Linux_arm64.tar.gz";
      hash = "sha256-3MZue1QFGO36H31QarBqYdkZ7U3SAgV+eMp1x5Jwom0=";
    };
    "x86_64-linux" = {
      asset = "pup_${version}_Linux_x86_64.tar.gz";
      hash = "sha256-xtvCzaSAI/Sz+J1iwGEiYiZgDQjdk83uW4G3vBzhqPY=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system} or (throw "pup is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "pup";
  inherit version;

  src = fetchurl {
    url = "https://github.com/datadog-labs/pup/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  nativeBuildInputs = lib.optionals stdenvNoCC.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.isLinux [ glibc ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 pup "$out/bin/pup"

    install -Dm644 README.md "$out/share/doc/pup/README.md"
    install -Dm644 LICENSE "$out/share/licenses/pup/LICENSE"
    if [ -f LICENSE-3rdparty.csv ]; then
      install -Dm644 LICENSE-3rdparty.csv "$out/share/licenses/pup/LICENSE-3rdparty.csv"
    fi
    runHook postInstall
  '';

  passthru.updateScript = ./scripts/update.sh;

  meta = with lib; {
    description = "Pup CLI, an AI-agent-ready Datadog observability companion";
    homepage = "https://github.com/datadog-labs/pup";
    changelog = "https://github.com/datadog-labs/pup/releases/tag/v${version}";
    license = licenses.asl20;
    platforms = builtins.attrNames sources;
    mainProgram = "pup";
  };
}
