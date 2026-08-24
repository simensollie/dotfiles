# dotfiles

Personal configuration files for macOS and Linux.

## Contents

| Directory | Description |
|-----------|-------------|
| `aerospace/` | [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager for macOS |
| `claude/` | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI settings, instructions, and custom statusline |
| `ghostty/` | [Ghostty](https://ghostty.org/) terminal config and themes, ported from [Omarchy](https://omarchy.org/) |
| `herdr/` | [Herdr](https://herdr.dev/) terminal workspace manager for AI coding agents |
| `jankyborders/` | [JankyBorders](https://github.com/FelixKratz/JankyBorders) window border highlights for macOS |
| `omarchy/` | [Hyprland](https://hyprland.org/) keybindings, input, and monitor config, plus [Omarchy](https://omarchy.org/) shell (bar layout and idle timers) for Linux |
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
