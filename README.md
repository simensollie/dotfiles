# dotfiles

Personal configuration files for macOS and Linux.

## Contents

| Directory | Description |
|-----------|-------------|
| `aerospace/` | [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager for macOS |
| `claude/` | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI settings, instructions, and custom statusline |
| `ghostty/` | [Ghostty](https://ghostty.org/) terminal config and themes, ported from [Omarchy](https://omarchy.org/) |
| `jankyborders/` | [JankyBorders](https://github.com/FelixKratz/JankyBorders) window border highlights for macOS |
| `omarchy/` | [Hyprland](https://hyprland.org/) keybindings, input, and monitor config for Linux |
| `starship/` | [Starship](https://starship.rs/) cross-shell prompt config |

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

### Starship

```bash
ln -sf ~/dev/dotfiles/starship/starship.toml ~/.config/starship.toml
```
