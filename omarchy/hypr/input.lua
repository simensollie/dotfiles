-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Omarchy 4 derives kb_layout from XKBLAYOUT in /etc/vconsole.conf and falls
-- back to "us" when that key is missing (a fresh install only writes KEYMAP).
-- Set it explicitly so the layout survives reinstalls. Omarchy's defaults
-- already cover kb_options (compose:caps), repeat_rate 40, numlock_by_default
-- and touchpad scroll_factor 0.4.
hl.config({
  input = {
    kb_layout = "no",

    -- Slower than Omarchy's 250ms default.
    repeat_delay = 600,

    -- Turn off mouse acceleration (Omarchy default: adaptive).
    accel_profile = "flat",
  },
})
