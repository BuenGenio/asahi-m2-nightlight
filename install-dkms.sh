#!/usr/bin/env bash
#
# Install the Night Light fix via DKMS (recommended): the patched appledrm is
# rebuilt and reinstalled automatically on every kernel update, and shadows the
# stock module via updates/ (no overwrite; `dkms remove` reverts cleanly).
#
# See README.md. Requires network at build time.
#
set -euo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KREL="$(uname -r)"
NAME="appledrm-nightlight"
VER="1.0"
SRC="/usr/src/${NAME}-${VER}"

[ "$(id -u)" -ne 0 ] || die "Do not run as root: colord setup needs your user session (this script uses sudo where needed)."
case "$KREL" in *-asahi*) : ;; *) die "This is not an Asahi kernel ($KREL)." ;; esac
command -v dkms >/dev/null || die "dkms not installed. Run: sudo apt install dkms"
[ -d "/lib/modules/${KREL}/build" ] || die "Kernel headers missing. Install: sudo apt install linux-headers-$KREL"
for t in git make gcc; do command -v "$t" >/dev/null || die "Missing tool: $t"; done

log "Installing DKMS source tree to $SRC ..."
sudo rm -rf "$SRC"
sudo install -d "$SRC"
sudo install -m644 "$SCRIPT_DIR/dkms/dkms.conf"  "$SRC/dkms.conf"
sudo install -m755 "$SCRIPT_DIR/dkms/pre-build.sh" "$SRC/pre-build.sh"
sudo install -m644 "$SCRIPT_DIR/nightlight.patch" "$SRC/nightlight.patch"

log "Registering + building + installing via DKMS ..."
sudo dkms remove -m "$NAME" -v "$VER" --all 2>/dev/null || true
sudo dkms add    -m "$NAME" -v "$VER"
sudo dkms build  -m "$NAME" -v "$VER"
sudo dkms install --force -m "$NAME" -v "$VER"

log "DKMS status:"; dkms status -m "$NAME"

log "Assigning sRGB colour profile ..."
"$SCRIPT_DIR/assign-colord-profile.sh"

echo
log "Done. Reboot to load the patched module, then enable Settings > Display > Night Light."
log "This survives kernel updates (DKMS AUTOINSTALL). Revert with ./uninstall.sh."
