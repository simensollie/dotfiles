-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Optimized for retina-class 2x displays, like 13" 2.8K, 27" 5K, 32" 6K.
hl.env("GDK_SCALE", "2")

-- Fallback for any monitor not configured explicitly below.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Primary: Samsung Odyssey G70B, 4K @ 144 Hz, 10-bit, on the left.
hl.monitor({
  output = "DP-1",
  mode = "3840x2160@144",
  position = "0x0",
  scale = 1.6,
  bitdepth = 10,
})

-- Secondary: BenQ V2400Eco, 1080p, to the right of DP-1.
-- DP-1 at scale 1.6 is 2400x1350 logical, so HDMI-A-1 starts at x=2400.
-- The y=135 offset centres the shorter panel against DP-1.
hl.monitor({
  output = "HDMI-A-1",
  mode = "1920x1080@60",
  position = "2400x135",
  scale = 1,
})

-- Bind specific workspace IDs to specific monitors.
for _, id in ipairs({ 1, 2, 3, 4 }) do
  hl.workspace_rule({ workspace = tostring(id), monitor = "DP-1", persistent = true })
end

hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1", persistent = true })
