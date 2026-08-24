# Solfuglen screensaver

Two independent pieces, both symlinked from this repo. Either can be removed
without affecting the other. See the Omarchy section of the top-level README for
the `ln` commands.

| Repo path | Deployed to |
|-----------|-------------|
| `omarchy/omarchy/branding/screensaver.txt` | `~/.config/omarchy/branding/screensaver.txt` |
| `omarchy/bin/ttfx` | `~/.local/bin/ttfx` |
| `omarchy/screensaver/` | not deployed -- generator tooling, run in place |

Requires `imagemagick` and `python-pillow` to regenerate; neither is needed to
merely use the art.

## 1. The art

`~/.config/omarchy/branding/screensaver.txt` (65 cols x 31 rows)

Phoenix rendered from `solfuglen-source.png` by tonal Floyd-Steinberg dithering
into braille glyphs, with the tail fading into embers, over a `SOLFUGLEN` wordmark.

A hard `-threshold` (what `omarchy transcode ascii` does) collapses this logo into a
solid blob, because the bird is dark against a bright sunburst everywhere. Dithering
turns the tonal range into dot density instead, so the wings keep their structure.

- Rebuild:  `./generate.sh`            (writes `preview.png` showing the terminal result)
- Install:  `./generate.sh --install`  (backs up the current file first, then writes
  through the symlink into this repo, so a rebuild shows up in `git status`)
- Revert:   `omarchy branding screensaver reset`, or restore a `screensaver.txt.bak.*`

Knobs are at the top of `generate.sh`: ink density, background cutoff, ember fade.
`ROWS` is the real constraint -- the 1080p monitor gives ~34 terminal rows at
JetBrains Mono 18, and the art must fit inside that.

## 2. Fire-effect pinning

`~/.local/bin/ttfx`

`omarchy-screensaver` calls `ttfx --random-effect`, which picks uniformly from all 38
effects, so the phoenix gets `matrix` or `vhstape` as often as `burn`. This wrapper
appends `--include-effects burn fireworks smoke beams spray colorshift` to that one
invocation and passes every other ttfx call through untouched.

Why wrap `ttfx` and not `omarchy-screensaver`: the graphical session PATH puts
`/usr/share/omarchy/bin` FIRST, ahead of `~/.local/bin`, so `omarchy-*` commands
cannot be shadowed from a user directory. `ttfx` lives in `/usr/bin` (position 21),
which `~/.local/bin` does beat -- in both the graphical and login-shell PATH.

This copies no packaged omarchy code, so upstream changes to `omarchy-screensaver`
are picked up normally.

Guards:
- `/usr/bin/ttfx` missing        -> exits 127 with a message
- ttfx drops `--include-effects` -> passes through unmodified, notifies once a day

Edit the `EFFECTS=(...)` line to change the pool. Full list: `ttfx --help`.

- Remove pinning entirely: `rm ~/.local/bin/ttfx` (drops the symlink; the repo copy stays)

## Verified

- `ttfx` renders the art exit-0 in a 133x34 pty (the tighter of the two monitors) -- fits, no clipping
- wrapper resolves ahead of `/usr/bin/ttfx` under both the graphical and login PATH
- pinning applies only to the screensaver call; other ttfx invocations pass through
- guard falls through cleanly when `--include-effects` is unavailable
- `pgrep -x ttfx` immediately after launch: 25 hits / 0 misses, so the wrapper's
  startup does not lose the packaged script's launch-then-pgrep race
