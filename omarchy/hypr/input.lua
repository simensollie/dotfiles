-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Omarchy 4 already matches your old input.conf for kb_layout (read from
-- /etc/vconsole.conf, currently "no"), kb_options (compose:caps),
-- repeat_rate 40, numlock_by_default and touchpad scroll_factor 0.4.
-- Only the two genuine differences are set here.
hl.config({
  input = {
    -- Slower than Omarchy's 250ms default.
    repeat_delay = 600,

    -- Turn off mouse acceleration (Omarchy default: adaptive).
    accel_profile = "flat",
  },
})
