#!/usr/bin/env bash
set -euo pipefail

GITHUB_REPO="datadog-labs/pup"
PACKAGE_FILE="package.nix"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: scripts/update.sh [OPTIONS]

Options:
  --version VERSION  Update to a specific Pup version, with or without leading v
  --check            Only check whether an update is available
  --no-build         Update files but skip local nix build verification
  -h, --help         Show this help

Examples:
  scripts/update.sh
  scripts/update.sh --check
  scripts/update.sh --version 0.54.1
EOF
}

ensure_repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/.."
  if [[ ! -f flake.nix || ! -f "$PACKAGE_FILE" ]]; then
    log_error "Could not find flake.nix/package.nix; run from the repo or keep scripts/update.sh in place."
    exit 1
  fi
}

require_tools() {
  local missing=()
  for tool in curl nix python3; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if (( ${#missing[@]} )); then
    log_error "Missing required tools: ${missing[*]}"
    exit 1
  fi
}

current_version() {
  python3 - <<'PY'
import re
text = open('package.nix').read()
m = re.search(r'\bversion\s*=\s*"([^"]+)"', text)
print(m.group(1) if m else 'unknown')
PY
}

latest_version() {
  local json tag
  json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")"
  tag="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])' <<<"$json")"
  printf '%s\n' "${tag#v}"
}

asset_for_system() {
  local version="$1"
  local system="$2"
  case "$system" in
    aarch64-darwin) printf 'pup_%s_Darwin_arm64.tar.gz\n' "$version" ;;
    x86_64-darwin)  printf 'pup_%s_Darwin_x86_64.tar.gz\n' "$version" ;;
    aarch64-linux)  printf 'pup_%s_Linux_arm64.tar.gz\n' "$version" ;;
    x86_64-linux)   printf 'pup_%s_Linux_x86_64.tar.gz\n' "$version" ;;
    *) log_error "Unsupported system: $system"; exit 1 ;;
  esac
}

prefetch_hash() {
  local version="$1"
  local system="$2"
  local asset url
  asset="$(asset_for_system "$version" "$system")"
  url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/${asset}"
  nix store prefetch-file --json "$url" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"])'
}

update_package_file() {
  local version="$1"
  local aarch64_darwin_hash="$2"
  local x86_64_darwin_hash="$3"
  local aarch64_linux_hash="$4"
  local x86_64_linux_hash="$5"

  python3 - "$version" "$aarch64_darwin_hash" "$x86_64_darwin_hash" "$aarch64_linux_hash" "$x86_64_linux_hash" <<'PY'
import re
import sys
from pathlib import Path

version, aarch64_darwin, x86_64_darwin, aarch64_linux, x86_64_linux = sys.argv[1:]
path = Path('package.nix')
text = path.read_text()

text, count = re.subn(r'\bversion\s*=\s*"[^"]+";', f'version = "{version}";', text, count=1)
if count != 1:
    raise SystemExit('failed to update version')

hashes = {
    'aarch64-darwin': aarch64_darwin,
    'x86_64-darwin': x86_64_darwin,
    'aarch64-linux': aarch64_linux,
    'x86_64-linux': x86_64_linux,
}

for system, new_hash in hashes.items():
    pattern = rf'("{re.escape(system)}"\s*=\s*\{{.*?hash\s*=\s*")[^"]+(";)'
    text, count = re.subn(pattern, rf'\g<1>{new_hash}\g<2>', text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'failed to update hash for {system}')

path.write_text(text)
PY
}

run_build_check() {
  log_info "Verifying package builds on current system..."
  nix build .#pup --print-build-logs
  ./result/bin/pup --version
}

main() {
  local target_version=""
  local check_only=false
  local skip_build=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        target_version="${2:-}"
        [[ -n "$target_version" ]] || { log_error "--version needs an argument"; exit 1; }
        shift 2
        ;;
      --check)
        check_only=true
        shift
        ;;
      --no-build)
        skip_build=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  ensure_repo_root
  require_tools

  local current latest
  current="$(current_version)"
  if [[ -n "$target_version" ]]; then
    latest="${target_version#v}"
  else
    latest="$(latest_version)"
  fi

  log_info "Current Pup version: $current"
  log_info "Target Pup version:  $latest"

  if [[ "$current" == "$latest" ]]; then
    log_info "Already up to date."
    exit 0
  fi

  if [[ "$check_only" == true ]]; then
    log_warn "Update available: $current -> $latest"
    exit 1
  fi

  local h_ad h_xd h_al h_xl
  log_info "Prefetching release artifacts..."
  h_ad="$(prefetch_hash "$latest" aarch64-darwin)"; log_info "aarch64-darwin: $h_ad"
  h_xd="$(prefetch_hash "$latest" x86_64-darwin)";  log_info "x86_64-darwin:  $h_xd"
  h_al="$(prefetch_hash "$latest" aarch64-linux)";  log_info "aarch64-linux:  $h_al"
  h_xl="$(prefetch_hash "$latest" x86_64-linux)";   log_info "x86_64-linux:   $h_xl"

  update_package_file "$latest" "$h_ad" "$h_xd" "$h_al" "$h_xl"

  if command -v nixpkgs-fmt >/dev/null 2>&1; then
    nixpkgs-fmt flake.nix package.nix >/dev/null
  fi

  if [[ "$skip_build" != true ]]; then
    run_build_check
  else
    log_warn "Skipping build verification (--no-build)."
  fi

  log_info "Updated package.nix to Pup $latest."
}

main "$@"
