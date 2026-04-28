{
  description = "Nix flake for Datadog Pup CLI - AI-agent-ready Datadog observability companion";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    let
      overlay = final: prev: {
        pup = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        let
          pupApp = {
            type = "app";
            program = "${pkgs.pup}/bin/pup";
            meta.description = "Run Datadog Pup CLI";
          };
        in
        {
          packages = {
            default = pkgs.pup;
            pup = pkgs.pup;
          };

          apps = {
            default = pupApp;
            pup = pupApp;
          };

          checks.default = pkgs.pup;

          formatter = pkgs.nixpkgs-fmt;

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              curl
              jq
              nixpkgs-fmt
              python3
            ];
          };
        }) // {
      overlays.default = overlay;
    };
}
