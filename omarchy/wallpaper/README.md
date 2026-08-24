# Solfuglen wallpaper

A synthwave sunset in the style of Omarchy's stock `tokyo-night/1-quattro.jpg`:
gradient sky, banded retro sun, layered ridges, mirrored lake, scanlines --
with the Solfuglen phoenix as the hero. "Solfuglen" means *sun bird*, so the
bird rises in front of the sun rather than sitting off to one side like the Audi.

Everything is composed procedurally with numpy/Pillow; the only external asset is
the logo, reused from `../screensaver/solfuglen-source.png`.

| Repo path | Deployed to |
|-----------|-------------|
| `omarchy/omarchy/backgrounds/tokyo-night/solfuglen-synthwave.jpg` | `~/.config/omarchy/backgrounds/tokyo-night/` (copy, not a symlink) |
| `omarchy/wallpaper/` | not deployed -- generator tooling, run in place |

- Rebuild:  `./generate.sh`            (3840x2160 master + a 1600x900 preview)
- Install:  `./generate.sh --install`  (copies to the theme's user-background
  folder and activates it)

Requires `imagemagick`, `python-numpy`, `python-scipy`, `python-pillow`.

## Pieces

`hero.py` cuts the phoenix out of the logo. The **green channel** is the clean
discriminator -- the bird sits at <=0.40, the yellow sunburst at >=0.69, with no
overlap -- where luminance overlaps badly and drops the bright head. It then
closes gaps, fills holes, and keeps the largest blob, which discards the detached
sunburst rays. The source frame guillotines the wing tips and tail, so the alpha
is ramped off at those edges to dissolve them into the scene.

`scene.py` draws the scene. Layout constants (`HORIZON`, `SUN_*`) are fractions of
the canvas, and every blur/line width scales off `K = W/3840`, so any resolution
renders the same composition. Output is deterministic: all randomness is seeded.

## Notes

Deployed as a plain copy rather than a symlink, unlike the screensaver files:
`omarchy theme bg set` stores `realpath` of the image in
`~/.local/state/omarchy/current/background`, so symlinking would bake a
`~/dev/dotfiles` path into Omarchy's state and break if the repo moves.

Other backgrounds already in that folder are left alone -- Omarchy's background
switcher cycles through all of them.
