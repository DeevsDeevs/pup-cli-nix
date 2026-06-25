{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
, glibc ? null
}:

let
  version = "1.4.1";

  sources = {
    "aarch64-darwin" = {
      asset = "pup_${version}_Darwin_arm64.tar.gz";
      hash = "sha256-iw/zTgqTXm5U6NKnvKzxVD7bl0ltt7LC1e+MPAa2mRs=";
    };
    "x86_64-darwin" = {
      asset = "pup_${version}_Darwin_x86_64.tar.gz";
      hash = "sha256-49i58WQpzrM6GRGXfZJFVGRZaB3hp2YuhcYjc+7YhXw=";
    };
    "aarch64-linux" = {
      asset = "pup_${version}_Linux_arm64.tar.gz";
      hash = "sha256-RYdfvIPbqrYbX2Zsuj9WC/VWtRiXT7TIqhCYPCI1reM=";
    };
    "x86_64-linux" = {
      asset = "pup_${version}_Linux_x86_64.tar.gz";
      hash = "sha256-YYBmYBz4s6wa5eaCWpJbMIRAWRC4FXCor6iMy77KbA0=";
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
