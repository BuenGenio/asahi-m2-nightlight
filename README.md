# Night Light for Asahi Linux (Apple M2)

Enable GNOME **Night Light** on Asahi Linux running on Apple Silicon laptops
(developed and tested on a **MacBook Air M2 / t8112**, Ubuntu Asahi, kernel
`7.0.0-1001-asahi-arm`, GNOME 50).

On a stock Asahi install the Night Light toggle is **greyed out** and has no
effect. This repo fixes it end-to-end with a small `apple-dcp` kernel patch plus
a one-line colord change.

## Why it doesn't work out of the box

There are **two** independent blockers:

1. **The kernel driver advertises no gamma table.** The Apple DCP firmware owns
   the colour pipeline and exposes a 3×3 colour *matrix* IPC (`iomfb_set_matrix`
   / tag `A422`) but **no arbitrary gamma LUT**. So `apple-dcp` calls
   `drm_crtc_enable_color_mgmt(crtc, 0, /*ctm*/true, /*gamma*/0)` — gamma size 0.
   GNOME gates Night Light *availability* on gamma support, so the toggle is
   greyed out.

2. **mutter needs a colord profile on the panel.** mutter 50 implements Night
   Light as a blackbody-scaled **KMS gamma LUT**, but `update_white_point()`
   returns early if the output has **no assigned colour profile**. The internal
   Apple panel exposes **no EDID** (the mode comes from the DCP, not DDC), so
   colord never auto-generates a profile — and Night Light silently no-ops even
   once the toggle is enabled.

## The fix

- **Kernel** (`nightlight.patch`): advertise a 256-entry `GAMMA_LUT`, and in the
  swap builder fold the ramp's per-channel gain into the diagonal of the
  existing `set_matrix` CTM (`out = diag(g)·CTM`). This is exact for the linear
  ramps Night Light and brightness use. A non-linear calibration curve (ICC
  VCGT) is reduced to its linear endpoint gain — acceptable for Night Light,
  lossy for hardware calibration.
- **Userspace**: assign a standard **sRGB** profile to the panel in colord so
  mutter's guard clause passes.

Net result: `temperature → mutter gamma LUT → KMS GAMMA_LUT → apple-dcp folds it
into the DCP colour matrix → panel warms.`

## Usage

```bash
git clone https://github.com/BuenGenio/asahi-m2-nightlight
cd asahi-m2-nightlight
./install.sh          # do NOT run as root; it uses sudo where needed
# reboot, then: Settings ▸ Display ▸ Night Light
```

Requirements: an Asahi kernel, `linux-headers-$(uname -r)`, and
`git make gcc zstd colord` installed.

### Reverting

```bash
./uninstall.sh        # restores the stock module; reboot
```

## Caveats

- **Not DKMS-managed.** The patched module is installed by hand, so a kernel /
  `linux-modules` package upgrade reverts it. **Re-run `./install.sh` after a
  kernel update.** (DKMS packaging is a welcome PR.)
- The kernel patch is a self-built, **unsigned** out-of-tree module. It loads
  because Asahi doesn't force module signatures (`module.sig_enforce=N`).
- Tested on M2 (t8112). The driver change is firmware-version-independent so it
  should apply to other Apple Silicon laptops with EDID-less internal panels,
  but only M2 is verified.
- `install.sh` fetches driver source from `UbuntuAsahi/linux` on the
  `asahi-arm-<major.minor>` branch to match your kernel. Override with
  `SRC_BRANCH=... SRC_REPO=... ./install.sh` if the source has drifted.

## Upstreaming

The kernel half is a clean, general improvement (every Asahi M2 user gets Night
Light). The gamma→matrix approximation tradeoff is documented in the patch so
reviewers can weigh it. See `nightlight.patch`.

## License

The `nightlight.patch` hunks are `GPL-2.0-only OR MIT` (same as the files they
modify). The scripts in this repo are MIT.
