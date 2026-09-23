-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- === Replace Omarchy 4 defaults =========================================
-- Each of these keys already carries a default binding, so unbind first.

-- Was: ChatGPT web app.
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "Claude", {
  launch = "com.anthropic.Claude.desktop",
  focus = "^com\\.anthropic\\.Claude$",
})

-- Was: Hey Calendar.
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.proton.me" })

-- Was: Hey Email.
hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://mail.proton.me" })

-- Was: Omawrite.
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- === Bindings with no Omarchy 4 default =================================

o.bind("SUPER + SHIFT + I", "Cursor", { launch = "cursor" })
o.bind("SUPER + SHIFT + T", "Activity", { tui = "btop" })

-- === Disable Omarchy 4 defaults you don't use ===========================
-- These were commented out in your pre-4.x bindings.conf, and Omarchy 4
-- turns them on by default.

hl.unbind("SUPER + SHIFT + SLASH")    -- 1Password
hl.unbind("SUPER + SHIFT + ALT + G")  -- WhatsApp
hl.unbind("SUPER + SHIFT + CTRL + G") -- Google Messages
hl.unbind("SUPER + SHIFT + P")        -- Google Photos
hl.unbind("SUPER + SHIFT + ALT + E")  -- Hey "new email" (new in 4.x)

-- === Omasnap screenshots =================================================
-- https://github.com/omacom/omasnap - native Wayland capture + annotation.
-- Was: omarchy-capture-screenshot on PRINT. F12 and ALT+SHIFT+4 carry no
-- Omarchy 4 default; unbound defensively in case a later release adds one.
-- Each key toggles: first press opens the overlay, next press dismisses it.

hl.unbind("PRINT")
hl.unbind("F12")
hl.unbind("ALT + SHIFT + 4")
hl.unbind("SUPER + SHIFT + S")  -- Was: Google Maps (new in 4.x).

o.bind("PRINT", "Screenshot", "omasnap")
o.bind("F12", "Screenshot", "omasnap")
o.bind("ALT + SHIFT + 4", "Screenshot", "omasnap")
o.bind("SUPER + SHIFT + S", "Screenshot", "omasnap")

hl.layer_rule({
  match = { namespace = "^omasnap$" },
  no_anim = true,
  animation = "none",
  no_screen_share = true,
})

-- >>> munin (managed by munin install.sh) >>>
o.bind("SUPER + SHIFT + R", "Record meeting", "munin toggle")
-- <<< munin (managed by munin install.sh) <<<
