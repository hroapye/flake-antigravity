#!/usr/bin/env bash
set -euo pipefail

readonly SOURCE_NAME="Antigravity.tar.gz"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/update-antigravity.sh <Antigravity.tar.gz URL>

Example:
  ./scripts/update-antigravity.sh \
    https://storage.googleapis.com/antigravity-public/antigravity-hub/2.35.1-4615540875067392/linux-x64/Antigravity.tar.gz

The archive is downloaded into the Nix store, its hash and version metadata are
written to vendor/antigravity-source.json, and the package is built.
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

readonly url="$1"
readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repo_root="$(cd -- "$script_dir/.." && pwd)"
readonly metadata_path="$repo_root/vendor/antigravity-source.json"

for dependency in nix jq; do
  if ! command -v "$dependency" >/dev/null; then
    printf 'error: required command not found: %s\n' "$dependency" >&2
    exit 1
  fi
done

if [[ ! "$url" =~ ^https://storage\.googleapis\.com/antigravity-public/antigravity-hub/([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/linux-x64/Antigravity\.tar\.gz$ ]]; then
  printf 'error: unsupported Antigravity URL:\n  %s\n' "$url" >&2
  usage >&2
  exit 2
fi

readonly version="${BASH_REMATCH[1]}"
readonly build_id="${BASH_REMATCH[2]}"

prefetch_json="$(nix store prefetch-file --json --name "$SOURCE_NAME" "$url")"
hash="$(jq -er '.hash' <<<"$prefetch_json")"

tmp_metadata="$(mktemp "$repo_root/vendor/.antigravity-source.XXXXXX")"
trap 'rm -f -- "$tmp_metadata"' EXIT

jq -n \
  --arg version "$version" \
  --arg buildId "$build_id" \
  --arg url "$url" \
  --arg hash "$hash" \
  --arg filename "$SOURCE_NAME" \
  '{
    version: $version,
    buildId: $buildId,
    url: $url,
    hash: $hash,
    filename: $filename
  }' >"$tmp_metadata"

mv -- "$tmp_metadata" "$metadata_path"

printf 'Updated Antigravity to %s (build %s)\n' "$version" "$build_id"
printf 'Hash: %s\n' "$hash"

if [[ "${ANTIGRAVITY_SKIP_BUILD:-0}" != "1" ]]; then
  nix build "path:$repo_root" --out-link "$repo_root/result"
fi

printf 'Profile upgrade command: nix profile upgrade %s\n' "$(basename -- "$repo_root")"
