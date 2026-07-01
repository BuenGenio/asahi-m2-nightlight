#!/usr/bin/env bash
#
# Revert install.sh or install-dkms.sh. The colord sRGB profile assignment is
# harmless and left in place.
#
set -euo pipefail

KREL="$(uname -r)"
MODDIR="/lib/modules/${KREL}/kernel/drivers/gpu/drm/apple"
NAME="appledrm-nightlight"

[ "$(id -u)" -ne 0 ] || { echo "Run as your user, not root." >&2; exit 1; }

if command -v dkms >/dev/null && dkms status -m "$NAME" 2>/dev/null | grep -q "$NAME"; then
  echo "==> Removing DKMS module $NAME ..."
  sudo dkms remove -m "$NAME" --all
  sudo depmod -a "$KREL"
  echo "==> Done. Reboot to fall back to the stock module."
elif [ -e "$MODDIR/appledrm.ko.zst.orig" ]; then
  echo "==> Restoring stock appledrm module from backup ..."
  sudo cp "$MODDIR/appledrm.ko.zst.orig" "$MODDIR/appledrm.ko.zst"
  sudo depmod -a "$KREL"
  echo "==> Done. Reboot to load the stock module."
else
  echo "Nothing to revert (no DKMS module, no backup found)."
  echo "If Night Light broke, reinstall the stock module:"
  echo "    sudo apt install --reinstall linux-modules-$KREL && sudo depmod -a $KREL"
fi
