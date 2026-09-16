-- Extra autostart processes.

-- ActivityWatch
o.launch_on_start("aw-qt")
o.launch_on_start("aw-watcher-window-hyprland")
o.launch_on_start("aw-watcher-media-player")
o.launch_on_start("aw-watcher-herdr")

-- HDMI-A-1 enumerates as monitor 0, so Hyprland boots focused there (workspace 5).
-- Move focus to the primary display instead.
o.exec_on_start("hyprctl dispatch focusmonitor DP-1")
