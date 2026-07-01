#!/usr/bin/env bash
#
# Revert install.sh: restore the stock apple-dcp module. The colord sRGB profile
# assignment is harmless and left in place.
#
set -euo pipefail

KREL="$(uname -r)"
MODDIR="/lib/modules/${KREL}/kernel/drivers/gpu/drm/apple"

[ "$(id -u)" -ne 0 ] || { echo "Run as your user, not root." >&2; exit 1; }

if [ -e "$MODDIR/appledrm.ko.zst.orig" ]; then
  echo "==> Restoring stock appledrm module ..."
  sudo cp "$MODDIR/appledrm.ko.zst.orig" "$MODDIR/appledrm.ko.zst"
  sudo depmod -a "$KREL"
  echo "==> Done. Reboot to load the stock module."
else
  echo "No backup (appledrm.ko.zst.orig) found."
  echo "Reinstall the stock module with:"
  echo "    sudo apt install --reinstall linux-modules-$KREL && sudo depmod -a $KREL"
fi
