-- Extra autostart processes.

-- ActivityWatch
o.launch_on_start("aw-qt")
o.launch_on_start("aw-watcher-window-hyprland")
o.launch_on_start("aw-watcher-media-player")
o.launch_on_start("aw-watcher-herdr")

-- HDMI-A-1 enumerates as monitor 0, so Hyprland boots focused there (workspace 5).
-- Land on workspace 1 on DP-1 instead. Omarchy 4 dispatches in Lua, so the old
-- `hyprctl dispatch focusmonitor DP-1` form fails to parse and silently did nothing.
-- The sleep lets Hyprland finish applying monitor and workspace rules first.
o.exec_on_start([[sleep 2 && hyprctl dispatch 'hl.dsp.focus({ workspace = "1" })']])
