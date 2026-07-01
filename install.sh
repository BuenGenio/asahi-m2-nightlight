#!/usr/bin/env bash
#
# Enable GNOME Night Light on Asahi Linux (Apple Silicon; tested on MacBook Air
# M2 / t8112). See README.md for the full explanation.
#
# Fixes two independent problems:
#   1. apple-dcp advertises no gamma LUT -> GNOME greys out Night Light.
#      Patch the driver to advertise a GAMMA_LUT and fold the ramp into the DCP's
#      existing colour-matrix IPC (the firmware has a 3x3 matrix but no LUT).
#   2. mutter's Night Light no-ops unless colord has a profile assigned to the
#      panel, and the EDID-less internal panel never gets one auto-generated.
#      Assign a standard sRGB profile in colord.
#
# NOT DKMS-managed: re-run after a kernel update.
#
set -euo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KREL="$(uname -r)"
KDIR="/lib/modules/${KREL}/build"
MODDIR="/lib/modules/${KREL}/kernel/drivers/gpu/drm/apple"
SRC_REPO="${SRC_REPO:-https://github.com/UbuntuAsahi/linux}"
SRC_BRANCH="${SRC_BRANCH:-asahi-arm-$(echo "$KREL" | grep -oE '^[0-9]+\.[0-9]+')}"

[ "$(id -u)" -ne 0 ] || die "Do not run as root: colord setup needs your user session (this script uses sudo only where needed)."

log "Kernel: $KREL"
case "$KREL" in
  *-asahi*) : ;;
  *) die "This is not an Asahi kernel ($KREL)." ;;
esac
grep -qai apple /proc/device-tree/compatible 2>/dev/null || warn "Could not confirm Apple hardware; continuing anyway."
[ -e "$MODDIR/appledrm.ko.zst" ] || die "appledrm module not found at $MODDIR (unexpected kernel layout)."
[ -d "$KDIR" ] || die "Kernel headers missing. Install: sudo apt install linux-headers-$KREL"
for t in git make gcc zstd strip depmod; do command -v "$t" >/dev/null || die "Missing tool: $t"; done
command -v colormgr >/dev/null || die "Missing 'colormgr' (install the colord package)."

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

log "Fetching apple-dcp source ($SRC_REPO @ $SRC_BRANCH) ..."
git clone --depth 1 --filter=blob:none --sparse -b "$SRC_BRANCH" "$SRC_REPO" "$WORK/linux" 2>/dev/null \
  || die "Clone of branch '$SRC_BRANCH' failed. Pick a matching branch with: SRC_BRANCH=<branch> $0"
git -C "$WORK/linux" sparse-checkout set drivers/gpu/drm/apple >/dev/null

log "Applying Night Light patch ..."
git -C "$WORK/linux" apply "$SCRIPT_DIR/nightlight.patch" \
  || die "Patch did not apply against '$SRC_BRANCH' (driver source drifted). See README.md."

log "Building appledrm out-of-tree against $KREL headers ..."
BUILD="$WORK/build"; mkdir -p "$BUILD"
cp -a "$WORK/linux/drivers/gpu/drm/apple/." "$BUILD/"
make -C "$KDIR" M="$BUILD" modules -j"$(nproc)"
[ -f "$BUILD/appledrm.ko" ] || die "Build produced no module."

log "Installing module (stock backed up to appledrm.ko.zst.orig if not already) ..."
strip --strip-debug "$BUILD/appledrm.ko"
zstd -q -f -19 "$BUILD/appledrm.ko" -o "$BUILD/appledrm.ko.zst"
sudo cp -n "$MODDIR/appledrm.ko.zst" "$MODDIR/appledrm.ko.zst.orig" 2>/dev/null || true
sudo cp "$BUILD/appledrm.ko.zst" "$MODDIR/appledrm.ko.zst"
sudo depmod -a "$KREL"

log "Assigning an sRGB colour profile to the panel (colord) ..."
"$SCRIPT_DIR/assign-colord-profile.sh"

echo
log "Done. Reboot to load the patched module, then enable Settings > Display > Night Light."
warn "Not DKMS-managed - re-run this script after any kernel update, or use ./install-dkms.sh to survive updates automatically."
