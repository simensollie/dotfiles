# dotfiles

Personal configuration files for macOS and Linux.

## Contents

| Directory | Description |
|-----------|-------------|
| `aerospace/` | [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager for macOS |
| `claude/` | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI settings, instructions, and custom statusline |
| `ghostty/` | [Ghostty](https://ghostty.org/) terminal config and themes, ported from [Omarchy](https://omarchy.org/) |
| `git/` | Git config (aliases, rebase-on-pull, histogram diffs, rerere) and global ignore file |
| `herdr/` | [Herdr](https://herdr.dev/) terminal workspace manager for AI coding agents |
| `jankyborders/` | [JankyBorders](https://github.com/FelixKratz/JankyBorders) window border highlights for macOS |
| `nvim/` | Neovim plugin additions on top of the `omarchy-nvim` package |
| `omarchy/` | [Hyprland](https://hyprland.org/) keybindings, input, and monitor config, plus [Omarchy](https://omarchy.org/) shell (bar layout and idle timers), the Solfuglen screensaver, Alacritty, bash and XCompose for Linux |
| `starship/` | [Starship](https://starship.rs/) cross-shell prompt config |
| `zsh/` | Zsh aliases and helpers (eza, fzf, zoxide-backed `cd`), ported from Omarchy |

## Setup

Clone and symlink the configs you need:

```bash
git clone git@github.com:simensollie/dotfiles.git ~/dev/dotfiles
```

### Claude Code

```bash
ln -sf ~/dev/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/dev/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/dev/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -sf ~/dev/dotfiles/claude/skills ~/.claude/skills
```

### AeroSpace

```bash
ln -sf ~/dev/dotfiles/aerospace/.config/aerospace ~/.config/aerospace
```

### JankyBorders

```bash
ln -sf ~/dev/dotfiles/jankyborders/.config/borders ~/.config/borders
```

### Ghostty

Requires [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads):

```bash
brew install --cask font-jetbrains-mono-nerd-font
ln -sf ~/dev/dotfiles/ghostty ~/.config/ghostty
```

The default theme is Tokyo Night (a strict port of Omarchy's palette). To swap
themes, change the `config-file` line in `ghostty/config` to point at another
file under `ghostty/themes/`.

### Herdr

Only `config.toml` is linked. `~/.config/herdr/` also holds sockets, logs, and
session state, so the directory itself must not be symlinked.

```bash
ln -sf ~/dev/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
```

Every action keeps its default `prefix` binding (`ctrl+b`) and adds a direct
Hyper chord, which assumes caps_lock is remapped to `cmd+ctrl+alt+shift` via
Karabiner. Note that herdr's own `hyper+` modifier is a different key and will
not match that remap, so the four modifiers are written out in full.

Run `herdr config check` after editing, and `herdr server reload-config` to
apply without restarting. `prefix+?` lists the active bindings.

### Omarchy (Linux)

Most of these are symlinked, so edits to the live config land straight in the
repo:

```bash
D=~/dev/dotfiles

# Hyprland (keybindings, monitors, input, look and feel)
for f in autostart bindings hyprland input looknfeel monitors; do
  ln -sfn "$D/omarchy/hypr/$f.lua" ~/.config/hypr/$f.lua
done
for f in hyprsunset xdph; do
  ln -sfn "$D/omarchy/hypr/$f.conf" ~/.config/hypr/$f.conf
done

# Alacritty
ln -sfn "$D/omarchy/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml

# Bash and XCompose
ln -sfn "$D/omarchy/bashrc"       ~/.bashrc
ln -sfn "$D/omarchy/bash_profile" ~/.bash_profile
ln -sfn "$D/omarchy/xcompose"     ~/.XCompose

# systemd user units
cp omarchy/systemd/user/voxtype.service ~/.config/systemd/user/
systemctl --user enable --now voxtype.service
systemctl --user enable --now appimagelauncherd.service
```

Apply Hyprland changes with `hyprctl reload`, then check `hyprctl configerrors`.

Only `voxtype.service` is tracked, because it is the one unit not provided by a
package (`appimagelauncherd` ships its own in `/usr/lib/systemd/user/`).
Enablement itself is never committed: `systemctl --user enable` writes absolute
symlinks into `*.target.wants/` that point at this machine's paths, so they do
not survive a move to another box. Run the enable commands instead.

Screensaver (the Solfuglen phoenix art, plus the wrapper that keeps the random
effect fire-themed):

```bash
ln -sfn "$D/omarchy/omarchy/branding/screensaver.txt" ~/.config/omarchy/branding/screensaver.txt
ln -sfn "$D/omarchy/bin/ttfx"                         ~/.local/bin/ttfx
```

Unlike `shell.json`, these are safe to symlink. `omarchy branding screensaver
reset` and `... image` both finish with a plain `cp`, which writes *through* a
symlink, and `... text` opens nvim, which preserves symlinks. Nothing does the
atomic rename that would replace the link with a regular file.

`omarchy/bin/ttfx` shadows `/usr/bin/ttfx`, not an `omarchy-*` command. That is
deliberate: the graphical session PATH (`systemctl --user show-environment`) puts
`/usr/share/omarchy/bin` *first*, ahead of `~/.local/bin`, so `omarchy-*` cannot be
overridden from a user directory -- even though the login-shell PATH is ordered the
other way round and makes it look like it can. See `omarchy/screensaver/README.md`.

**`shell.json` is the one exception, and must stay a copy:**

```bash
cp omarchy/omarchy/shell.json ~/.config/omarchy/shell.json   # deploy
cp ~/.config/omarchy/shell.json omarchy/omarchy/shell.json   # capture changes
```

`omarchy-shell-config` (behind every `omarchy bar ...` command) writes with
`jq > tmp; mv tmp shell.json`. That atomic rename replaces a symlink with a
regular file, so linking it would silently break on the first bar tweak and
leave the repo stale again. Copy it back by hand after changing the bar.

One caveat on the symlinked files: `omarchy refresh` uses `cp -f`, which writes
*through* a symlink. Running `omarchy refresh hyprland` therefore overwrites the
repo files with Omarchy's defaults rather than detaching the links. That shows
up in `git status`, and `git checkout -- omarchy/hypr` undoes it.

### Git

```bash
mkdir -p ~/.config/git
ln -sf ~/dev/dotfiles/git/config ~/.config/git/config
ln -sf ~/dev/dotfiles/git/ignore ~/.config/git/ignore
```

### Neovim

The base config comes from the `omarchy-nvim` package. Only local additions are
tracked here:

```bash
ln -sf ~/dev/dotfiles/nvim/lua/plugins/aw-watcher.lua \
  ~/.config/nvim/lua/plugins/aw-watcher.lua
```

### Starship

```bash
ln -sf ~/dev/dotfiles/starship/starship.toml ~/.config/starship.toml
```

### Zsh aliases

Requires `eza`, `zoxide`, `fzf`, `bat`:

```bash
brew install eza zoxide fzf bat
```

Then source the aliases file from `~/.zshrc` (after `zoxide init`):

```bash
[ -f "$HOME/dev/dotfiles/zsh/aliases.zsh" ] && source "$HOME/dev/dotfiles/zsh/aliases.zsh"
```
