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
```

**Recommended — DKMS** (survives kernel updates automatically):

```bash
./install-dkms.sh     # do NOT run as root; uses sudo where needed
# reboot, then: Settings ▸ Display ▸ Night Light
```

DKMS rebuilds the patched driver on every kernel update and shadows the stock
module via `updates/` (no overwrite). Requires `dkms` and network at build time.

**Or — plain install** (must be re-run after each kernel update):

```bash
./install.sh
```

Requirements: an Asahi kernel, `linux-headers-$(uname -r)`, and
`git make gcc zstd colord` (+ `dkms` for the recommended path).

### Reverting

```bash
./uninstall.sh        # dkms remove, or restore the stock module; reboot
```

## Caveats

- **Persistence.** Use `./install-dkms.sh` (recommended) and the module is
  rebuilt automatically on kernel updates. The plain `./install.sh` overwrites
  the stock module and must be **re-run after every kernel update**.
- **DKMS tracks the kernel source.** Because the patched module is the whole
  in-tree `appledrm`, the DKMS `PRE_BUILD` hook (`dkms/pre-build.sh`) fetches the
  matching driver source for the target kernel and re-applies `nightlight.patch`
  at build time — so it needs network access during `apt upgrade`.
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
