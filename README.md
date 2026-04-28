# pup-cli-nix

Nix flake for [Datadog Pup](https://github.com/datadog-labs/pup), an AI-agent-ready CLI for Datadog observability.

This repo packages upstream Pup release binaries so Nix and Devbox users can install Pup without Homebrew.

## Quick start

```bash
nix run github:DeevsDeevs/pup-cli-nix
```

Install into a Nix profile:

```bash
nix profile install github:DeevsDeevs/pup-cli-nix
```

Use with Devbox global:

```bash
devbox global add github:DeevsDeevs/pup-cli-nix#pup
```

If your Devbox version expects a Git URL, use:

```bash
devbox global add git+ssh://git@github.com/DeevsDeevs/pup-cli-nix.git#pup
```

## Flake outputs

- `packages.default` / `packages.pup` — Pup CLI
- `apps.default` / `apps.pup` — runnable `pup` app
- `overlays.default` — exposes `pkgs.pup`

Supported systems:

- `aarch64-darwin`
- `x86_64-darwin`
- `aarch64-linux`
- `x86_64-linux`

## Use in another flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pup-cli-nix.url = "github:DeevsDeevs/pup-cli-nix";
  };

  outputs = { nixpkgs, pup-cli-nix, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pup-cli-nix.packages.${system}.default ];
      };
    };
}
```

## Updating

Update to the latest upstream Pup release:

```bash
./scripts/update.sh
```

Update to a specific version:

```bash
./scripts/update.sh --version 0.54.1
```

Only check if a newer release exists:

```bash
./scripts/update.sh --check
```

## Verification

```bash
nix flake check
nix run . -- --version
```
