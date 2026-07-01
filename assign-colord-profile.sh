#!/usr/bin/env bash
#
# Assign a standard sRGB colour profile to the internal panel in colord.
# mutter's Night Light no-ops without an assigned profile, and the EDID-less
# Apple panel never gets one auto-generated. Run as your user (needs the session
# bus); idempotent.
#
set -euo pipefail

command -v colormgr >/dev/null || { echo "colormgr not found (install the colord package)." >&2; exit 1; }

DEV="$(colormgr get-devices-by-kind display 2>/dev/null | awk -F': *' '/Object Path/{print $2; exit}')"
[ -n "${DEV:-}" ] || { echo "No colord display device found (is a desktop session running?)." >&2; exit 1; }

SRGB="$(colormgr get-standard-space srgb 2>/dev/null | awk -F': *' '/Object Path/{print $2; exit}')"
[ -n "${SRGB:-}" ] || { echo "No standard sRGB profile in colord." >&2; exit 1; }

colormgr device-add-profile "$DEV" "$SRGB" >/dev/null 2>&1 || true
colormgr device-make-profile-default "$DEV" "$SRGB" >/dev/null 2>&1 || true
echo "==> Assigned sRGB profile to $DEV"
