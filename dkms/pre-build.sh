#!/usr/bin/env bash
#
# DKMS PRE_BUILD hook. Fetches the apple-dcp driver source matching the target
# kernel version and applies nightlight.patch into ./src, so the DKMS build
# tracks each kernel update instead of using a stale snapshot.
#
# Invoked by DKMS from the build directory as: pre-build.sh <kernelver>
# Override source with SRC_REPO / SRC_BRANCH env vars.
#
set -euo pipefail

KVER="${1:-${kernelver:-$(uname -r)}}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAJMIN="$(printf '%s' "$KVER" | grep -oE '^[0-9]+\.[0-9]+')"
VERSION="${KVER%%-*}"
REPO="${SRC_REPO:-https://github.com/UbuntuAsahi/linux}"
if [[ -n "${SRC_BRANCH:-}" ]]; then
  BRANCH="$SRC_BRANCH"
elif [[ "$REPO" == "https://github.com/AsahiLinux/linux" ]]; then
  BRANCH="$(git ls-remote --tags --refs "$REPO" "refs/tags/asahi-${VERSION}-*" | awk '{sub("refs/tags/", "", $2); print $2}' | sort -V | tail -n1)"
  [[ -n "$BRANCH" ]] || { echo "No Asahi Linux tag found for kernel $VERSION" >&2; exit 1; }
else
  BRANCH="asahi-arm-${MAJMIN}"
fi

echo "appledrm-nightlight: fetching apple-dcp source for ${KVER} ($REPO @ $BRANCH)"
rm -rf "$HERE/src" "$HERE/.linux"
git clone --depth 1 --filter=blob:none --sparse -b "$BRANCH" "$REPO" "$HERE/.linux"
git -C "$HERE/.linux" sparse-checkout set drivers/gpu/drm/apple >/dev/null
git -C "$HERE/.linux" apply "$HERE/nightlight.patch"
mkdir -p "$HERE/src"
cp -a "$HERE/.linux/drivers/gpu/drm/apple/." "$HERE/src/"
rm -rf "$HERE/.linux"
echo "appledrm-nightlight: source ready in ./src"
