-- WirePlumber
--
-- Copyright © 2021 Asymptotic Inc.
--    @author Sanchayan Maity <sanchayan@asymptotic.io>
--
-- Based on bt-profile-switch.lua in tests/examples
-- Copyright © 2021 George Kiagiadakis
--
-- Based on bluez-autoswitch in media-session
-- Copyright © 2021 Pauli Virtanen
--
-- SPDX-License-Identifier: MIT
--
-- This script is charged to automatically change BT profiles on a device. If a
-- client is linked to the device's loopback source node, the associated BT
-- device profile is automatically switched to HSP/HFP. If there is no clients
-- linked to the device's loopback source node, the BT device profile is
-- switched back to A2DP profile.
--
-- We switch to the highest priority profile that has an Input route available.
-- The reason for this is that we may have microphone enabled with non-HFP
-- codecs eg. Faststream.
-- When a stream goes away if the list with which we track the streams above
-- is empty, then we revert back to the old profile.

-- settings file: bluetooth.conf
--
-- LOCAL OVERRIDE (2026-11-02, simen-beelink). Copy of the stock 0.5.18 script
-- with one change: a Bluetooth device that was added less than
-- HEADSET_SETTLE_MSEC ago is not switched to its headset profile yet. The
-- switch is deferred and re-evaluated when the settle timer expires.
--
-- Why: the Jabra EVOLVE 65 dropped its HFP link 6 to 34 s after joining a
-- Teams call whenever Teams already held the microphone and the headset had
-- been powered on only 2 s earlier, so WirePlumber opened the SCO link while
-- the headset was still bringing up its own profiles. Joins with 11 s or more
-- between power-on and the switch never failed. Delete this file to get the
-- stock behaviour back. Playbook: docs/playbooks/2026-10-29-bluetooth-headset-stability.md
-- in the munin repo.

lutils = require ("linking-utils")
cutils = require ("common-utils")
log = Log.open_topic ("s-device")
persistent_storage_hooks_registered = false
autoswitch_hooks_registered = false

local PROFILE_RESTORE_TIMEOUT_MSEC = 2000
local PROFILE_SWITCH_TIMEOUT_MSEC = 500
local HEADSET_SETTLE_MSEC = 10000

local state = nil
local headset_profiles = {}
local non_headset_profiles = {}
local capture_stream_links = {}
local restore_timeout_source = {}
local switch_timeout_source = {}
local settle_timeout_source = {}
local deferred_switch = {}

-- LOCAL OVERRIDE (2026-11-24): report a call-mode microphone that is dead on
-- arrival, so it can be repaired.
--
-- Why: the SCO source node (bluez_input.<mac>.0) sometimes goes
-- "running -> error" a few ms after the switch to the headset profile. The
-- SCO connect is refused with EMLINK ("Too many links"): the SCO link of the
-- previous call is still alive on the controller or headset although the
-- kernel has forgotten it ("SCO packet for unknown connection handle").
-- The microphone is then silent, Teams reopens the device after about 16 s
-- and the headset link collapses. Seen 7 times 2026-11-05 to 2026-11-24,
-- always on a headset that had already done a call on the same connection.
-- Reproduced 2026-11-24: the state persists (90 s tested), a profile bounce
-- through "off" does not clear it; disconnecting and reconnecting only the
-- Handsfree profile does (and so does a full Bluetooth reconnect).
--
-- What: if that node errors within HEADSET_ERROR_WINDOW_USEC of a switch this
-- script made, log one warning containing SCO_DEAD_MARKER and the node name.
-- WirePlumber's Lua sandbox cannot run a command, so the reconnect is done by
-- headset-sco-recover.service, which follows this log. The window keeps the
-- normal teardown error (same pw.node line, 2 s or more after the switch) out.
local HEADSET_ERROR_WINDOW_USEC = 1500000
local HEADSET_REPORT_HOLDOFF_USEC = 30000000
local SCO_DEAD_MARKER = "headset-sco-dead"
-- Logged on every restore from the headset profile. The service then resets
-- the hands-free (HFP) link, 1.2 s with music still playing, which clears the
-- stale SCO link before it can break the next call.
local HFP_LEFT_MARKER = "headset-hfp-left"
local headset_switch_usec = {}
local last_report_usec = {}

function saveHeadsetProfile (device, profile_name, persistent)
  local key = "saved-headset-profile:" .. device.properties ["device.name"]
  headset_profiles [key] = profile_name
  if state ~= nil and persistent then
    state:save_after_timeout (headset_profiles)
  end
end

function getSavedHeadsetProfile (device)
  local key = "saved-headset-profile:" .. device.properties ["device.name"]
  return headset_profiles [key]
end

function saveNonHeadsetProfile (device, profile_name)
  non_headset_profiles [device.properties ["device.name"]] = profile_name
end

function getSavedNonHeadsetProfile (device)
  return non_headset_profiles [device.properties ["device.name"]]
end

function findProfile (device, index, name)
  for p in device:iterate_params ("EnumProfile") do
    local profile = cutils.parseParam (p, "EnumProfile")
    if profile ~= nil then
      if (index ~= nil and profile.index == index) or
         (name ~= nil and profile.name == name) then
        return profile
      end
    end
  end

  return nil
end

function getCurrentProfile (device)
  for p in device:iterate_params ("Profile") do
    local profile = cutils.parseParam (p, "Profile")
    if profile then
      return profile
    end
  end
  return nil
end

function hasProfileInputRoute (device, profile_index)
  for p in device:iterate_params ("EnumRoute") do
    local route = cutils.parseParam (p, "EnumRoute")
    if route and route.direction == "Input" and route.profiles then
      for _, v in pairs (route.profiles) do
        if v == profile_index then
          return true
        end
      end
    end
  end
  return false
end

function isHeadsetProfile (device, profile)
  if hasProfileInputRoute (device, profile.index) and
      (string.find (profile.name, "^headset%-head%-unit") or profile.name == "bap-duplex") then
    return true
  else
    return false
  end
end

function highestPrioHeadsetProfile (device)
  local found_profile = nil
  for p in device:iterate_params ("EnumRoute") do
    local route = cutils.parseParam (p, "EnumRoute")
    if route ~= nil and route.profiles ~= nil and route.direction == "Input" then
      for _, v in pairs (route.profiles) do
        local p = findProfile (device, v)
        if p ~= nil and isHeadsetProfile (device, p) then
          if found_profile == nil or found_profile.priority < p.priority then
            found_profile = p
          end
        end
      end
    end
  end
  return found_profile
end

function highestPrioNonHeadsetProfile (device)
  local found_profile = nil
  for p in device:iterate_params ("EnumRoute") do
    local route = cutils.parseParam (p, "EnumRoute")
    if route ~= nil and route.profiles ~= nil and route.direction ~= "Input" then
      for _, v in pairs (route.profiles) do
        local p = findProfile (device, v)
        if p ~= nil and not isHeadsetProfile (device, p) then
          if found_profile == nil or found_profile.priority < p.priority then
            found_profile = p
          end
        end
      end
    end
  end
  return found_profile
end

function switchDeviceToHeadsetProfile (dev_id, device_om)
  -- Find the actual device
  local device = device_om:lookup {
      Constraint { "bound-id", "=", dev_id, type = "gobject" }
  }
  if device == nil then
    log:info ("Device with id " .. tostring(dev_id).. " not found")
    return
  end

  -- Do not switch if the current profile is already a headset profile
  local cur_profile = getCurrentProfile (device)
  if cur_profile ~= nil and isHeadsetProfile (device, cur_profile) then
    log:info (device,
        "Current profile is already a headset profile, no need to switch")
    return
  elseif cur_profile == nil then
    log:info (device, "Could not get current profile, not switching")
    return
  end

  -- Get saved headset profile if any, otherwise find the highest priority one
  local profile = nil
  local profile_name = getSavedHeadsetProfile (device)
  if profile_name ~= nil then
    profile = findProfile (device, nil, profile_name)
    if profile ~= nil and not isHeadsetProfile (device, profile) then
      saveHeadsetProfile (device, nil, false)
      profile = nil
    end
  end
  if profile == nil then
    profile = highestPrioHeadsetProfile (device)
  end

  -- Switch if headset profile was found
  if profile ~= nil then
    local pod = Pod.Object {
      "Spa:Pod:Object:Param:Profile", "Profile",
      index = profile.index,
      save = false
    }
    log:info (device, "Switching profile from: " .. cur_profile.name
          .. " to: " .. profile.name)
    -- Local override: remember when the switch was made (see recovery hook).
    headset_switch_usec[tostring (dev_id)] = GLib.get_monotonic_time ()
    device:set_params ("Profile", pod)
  else
    log:warning ("Could not find valid headset profile, not switching")
  end
end

function restoreProfile (dev_id, device_om)
  -- Find the actual device
  local device = device_om:lookup {
      Constraint { "bound-id", "=", dev_id, type = "gobject" }
  }
  if device == nil then
    log:info ("Device with id " .. tostring(dev_id).. " not found")
    return
  end

  -- Do not restore if the current profile is already a non-headset profile
  local cur_profile = getCurrentProfile (device)
  if cur_profile ~= nil and not isHeadsetProfile (device, cur_profile) then
    log:info (device,
        "Current profile is already a non-headset profile, no need to restore")
    return
  elseif cur_profile == nil then
    log:info (device, "Could not get current profile, not switching")
    return
  end

  -- Get saved non-headset profile if any, otherwise find the highest priority one
  local profile = nil
  local profile_name = getSavedNonHeadsetProfile (device)
  if profile_name ~= nil then
    profile = findProfile (device, nil, profile_name)
    if profile ~= nil and isHeadsetProfile (device, profile) then
      saveNonHeadsetProfile (device, nil)
      profile = nil
    end
  end
  if profile == nil then
    profile = highestPrioNonHeadsetProfile (device)
  end

  -- Restore if non-headset profile was found
  if profile ~= nil then
    local pod = Pod.Object {
      "Spa:Pod:Object:Param:Profile", "Profile",
      index = profile.index,
      save = false
    }
    log:info (device, "Restoring profile from: " .. cur_profile.name
          .. " to: " .. profile.name)
    device:set_params ("Profile", pod)
    -- Local override: tell headset-sco-recover.service that call mode was
    -- left, so it can reset the hands-free link before the next call.
    log:notice (HFP_LEFT_MARKER .. " card=" .. tostring (device.properties ["device.name"]))
  else
    log:warning ("Could not find valid non-headset profile, not switching")
  end
end

function triggerSwitchDeviceToHeadsetProfile (source, dev_id)
  -- Always clear any pending restore/switch callbacks when triggering a new switch
  if restore_timeout_source[dev_id] ~= nil then
    restore_timeout_source[dev_id]:destroy ()
    restore_timeout_source[dev_id] = nil
    log:info ("Cancelled profile restore on device " .. tostring (dev_id))
  end
  if switch_timeout_source[dev_id] ~= nil then
    switch_timeout_source[dev_id]:destroy ()
    switch_timeout_source[dev_id] = nil
    log:info ("Cancelled profile switch on device " .. tostring (dev_id))
  end

  -- Local override: a freshly connected device is left alone until its settle
  -- timer expires; the evaluation is repeated then.
  if settle_timeout_source[dev_id] ~= nil then
    deferred_switch[dev_id] = true
    log:notice ("Deferring profile switch on device " .. tostring (dev_id)
        .. " until it has settled (" .. HEADSET_SETTLE_MSEC .. " ms after connect)")
    return
  end

  -- create new switch callback
  log:info ("Triggering profile switch on device " .. tostring (dev_id))
  switch_timeout_source[dev_id] = Core.timeout_add (PROFILE_SWITCH_TIMEOUT_MSEC, function ()
    switch_timeout_source[dev_id] = nil

    local e = source:call ("create-event", "autoswitch-bluez-headset-profile", nil, nil)
    e:set_data ("device-id", dev_id)
    EventDispatcher.push_event (e)
  end)
end

function triggerRestoreProfile (source, dev_id)
  -- Always clear any pending restore/switch callbacks when triggering a new restore
  if switch_timeout_source[dev_id] ~= nil then
    switch_timeout_source[dev_id]:destroy ()
    switch_timeout_source[dev_id] = nil
    log:info ("Cancelled profile switch on device " .. tostring (dev_id))
  end
  if restore_timeout_source[dev_id] ~= nil then
    restore_timeout_source[dev_id]:destroy ()
    restore_timeout_source[dev_id] = nil
    log:info ("Cancelled profile restore on device " .. tostring (dev_id))
  end

  -- Local override: a restore cancels a deferred switch too.
  deferred_switch[dev_id] = nil

  -- create new restore callback
  log:info ("Triggering profile restore on device " .. tostring (dev_id))
  restore_timeout_source[dev_id] = Core.timeout_add (PROFILE_RESTORE_TIMEOUT_MSEC, function ()
    restore_timeout_source[dev_id] = nil

    local e = source:call ("create-event", "autoswitch-bluez-a2dp-profile", nil, nil)
    e:set_data ("device-id", dev_id)
    EventDispatcher.push_event (e)
  end)
end

function getLinkedBluetoothLoopbackSourceNodeForStream (stream, node_om, link_om, visited_link_groups)
  local stream_id = stream["bound-id"]

  -- Make sure the node is linked
  local link = link_om:lookup {
    Constraint { "link.input.node", "=", stream_id, type = "pw-global"}
  }
  if link == nil then
    return nil
  end
  local peer_id = link.properties["link.output.node"]

  -- If the peer node is the BT loopback source node, return its Id.
  -- Otherwise recursively advance in the graph if it is linked to a filter.
  local bt_node = node_om:lookup {
      Constraint { "media.class", "matches", "Audio/Source", type = "pw-global" },
      Constraint { "bound-id", "=", peer_id, type = "gobject" },
      Constraint { "bluez5.loopback", "=", "true", type = "pw" }
  }
  if bt_node ~= nil then
    return bt_node
  else
    local filter_main_node = node_om:lookup {
      Constraint { "bound-id", "=", peer_id, type = "gobject" },
      Constraint { "node.link-group", "+", type = "pw" }
    }
    if filter_main_node ~= nil then
      local filter_link_group = filter_main_node.properties ["node.link-group"]
      if visited_link_groups == nil then
        visited_link_groups = {}
      end
      if visited_link_groups [filter_link_group] then
        return nil
      else
        visited_link_groups [filter_link_group] = true
      end
      for filter_stream_node in node_om:iterate {
          Constraint { "bound-id", "!", peer_id, type = "gobject" },
          Constraint { "stream.monitor", "!", "true", type = "pw" },
          Constraint { "bluez5.loopback", "!", "true", type = "pw" },
          Constraint { "node.link-group", "=", filter_link_group, type = "pw" }
        } do
        local bt_node = getLinkedBluetoothLoopbackSourceNodeForStream (filter_stream_node, node_om, link_om, visited_link_groups)
        if bt_node ~= nil then
          return bt_node
        end
      end
    end
  end

  return nil
end

function isBluetoothLoopbackSourceNodeLinkedToStream (bt_node, node_om, link_om)
  local bt_node_id = bt_node["bound-id"]
  for stream in node_om:iterate {
    Constraint { "media.class", "matches", "Stream/Input/Audio", type = "pw-global" },
    Constraint { "node.link-group", "-", type = "pw" },
    Constraint { "stream.monitor", "!", "true", type = "pw" },
    Constraint { "bluez5.loopback", "!", "true", type = "pw" }
  } do
    local linked_bt_node = getLinkedBluetoothLoopbackSourceNodeForStream (stream, node_om, link_om)
    if linked_bt_node ~= nil then
      local linked_bt_node_id = linked_bt_node ["bound-id"]
      if tonumber (linked_bt_node_id) == tonumber (bt_node_id) then
        return true
      end
    end
  end
  return false
end

local switch_profile_hook = AsyncEventHook {
  name = "switch-profile@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "autoswitch-bluez-headset-profile" },
    },
  },
  steps = {
    start = {
      next = "none",
      execute = function (event, transition)
        local source = event:get_source ()
        local device_om = source:call ("get-object-manager", "device")
        local device_id = event:get_data ("device-id")

        -- Switch profile
        switchDeviceToHeadsetProfile (device_id, device_om)

        -- Wait until the profile is applied
        Core.sync (function ()
          transition:advance ()
        end)
      end
    },
  }
}

local restore_profile_hook = AsyncEventHook {
  name = "restore-profile@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "autoswitch-bluez-a2dp-profile" },
    },
  },
  steps = {
    start = {
      next = "none",
      execute = function (event, transition)
        local source = event:get_source ()
        local device_om = source:call ("get-object-manager", "device")
        local device_id = event:get_data ("device-id")

        -- Restore profile
        restoreProfile (device_id, device_om)

        -- Wait until the profile is applied
        Core.sync (function ()
          transition:advance ()
        end)
      end
    },
  }
}

local evaluate_bluetooth_profiles_hook = SimpleEventHook {
  name = "evaluate-bluetooth-profiles@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "evaluate-bluetooth-profiles" },
    },
  },
  execute = function (event)
    local source = event:get_source ()
    local node_om = source:call ("get-object-manager", "node")
    local link_om = source:call ("get-object-manager", "link")

    -- Evaluate all bluetooth loopback source nodes, and switch to headset
    -- profile only if the node is running and linked to a stream that is not a
    -- monitor, otherwise just restore the profile.
    --
    -- If the bluetooth node is linked to a stream that is a monitor, its state
    -- will be 'running', so we cannot just rely on the state to know if we
    -- have to switch or not, we also need to check if the node is linked to
    -- a stream that is not a monitor.
    for bt_node in node_om:iterate {
        Constraint { "media.class", "matches", "Audio/Source" },
        Constraint { "device.id", "+" },
        Constraint { "bluez5.loopback", "=", "true", type = "pw" }
    } do
      local bt_node_state = bt_node["state"]
      local bt_dev_id = bt_node.properties ["device.id"]

      if bt_node_state == "running" and
          isBluetoothLoopbackSourceNodeLinkedToStream (bt_node, node_om, link_om) then
        triggerSwitchDeviceToHeadsetProfile (source, bt_dev_id)
      else
        triggerRestoreProfile (source, bt_dev_id)
      end
    end
  end
}

local link_added_hook = SimpleEventHook {
  name = "link-added@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "link-added" },
    },
  },
  execute = function (event)
    local source = event:get_source ()
    local node_om = source:call ("get-object-manager", "node")
    local link = event:get_subject ()
    local in_stream_id = link.properties["link.input.node"]
    local out_node_id = link.properties["link.output.node"]

    -- Only evaluate bluetooth profiles if a capture stream was linked, or if
    -- the BT loopback source node was linked to anything (e.g. a filter chain
    -- that gets linked after the capture stream was linked to the filter)
    local stream = node_om:lookup {
      Constraint { "media.class", "matches", "Stream/Input/Audio", type = "pw-global" },
      Constraint { "node.link-group", "-", type = "pw" },
      Constraint { "stream.monitor", "!", "true", type = "pw" },
      Constraint { "bluez5.loopback", "!", "true", type = "pw" },
      Constraint { "bound-id", "=", in_stream_id, type = "gobject" },
    }
    local bt_node = node_om:lookup {
      Constraint { "media.class", "matches", "Audio/Source", type = "pw-global" },
      Constraint { "bluez5.loopback", "=", "true", type = "pw" },
      Constraint { "bound-id", "=", out_node_id, type = "gobject" },
    }
    if stream ~= nil or bt_node ~= nil then
      capture_stream_links [link.id] = true
      source:call ("push-event", "evaluate-bluetooth-profiles", nil, nil)
    end
  end
}

local link_removed_hook = SimpleEventHook {
  name = "link-removed@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "link-removed" },
    },
  },
  execute = function (event)
    local source = event:get_source ()
    local link = event:get_subject ()

    -- Only evaluate bluetooth profiles if a capture stream was unlinked
    if capture_stream_links [link.id] then
      capture_stream_links [link.id] = nil
      source:call ("push-event", "evaluate-bluetooth-profiles", nil, nil)
    end
  end
}

local state_changed_hook = SimpleEventHook {
  name = "bluez-loopback-state-changed@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-state-changed" },
      Constraint { "media.class", "matches", "Audio/Source" },
      Constraint { "device.id", "+" },
      Constraint { "bluez5.loopback", "=", "true", type = "pw" }
    },
  },
  execute = function (event)
    local source = event:get_source ()
    local node = event:get_subject ()
    local old_state = event:get_properties ()["event.subject.old-state"]
    local new_state = event:get_properties ()["event.subject.new-state"]

    log:info (node, "state changed from '" .. old_state .. "' to '" .. new_state .. "'")

    -- Dont evaluate if the state changed from idle to suspended
    if old_state == "idle" and new_state == "suspended" then
      return
    end

    source:call ("push-event", "evaluate-bluetooth-profiles", nil, nil)
  end
}

local node_added_hook = SimpleEventHook {
  name = "bluez-loopback-added@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-added" },
      Constraint { "media.class", "matches", "Audio/Source" },
      Constraint { "device.id", "+" },
      Constraint { "bluez5.loopback", "=", "true", type = "pw" }
    },
  },
  execute = function (event)
    local source = event:get_source ()
    source:call ("push-event", "evaluate-bluetooth-profiles", nil, nil)
  end
}

local device_profile_changed_hook = SimpleEventHook {
  name = "bluez-profile-changed@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "device-params-changed" },
      Constraint { "event.subject.param-id", "=", "Profile" },
      Constraint { "device.api", "=", "bluez5" },
    },
  },
  execute = function (event)
    local device = event:get_subject ()
    -- the timers are keyed by the loopback node's "device.id" property, which
    -- is a string; device["bound-id"] is the same value as a number
    local dev_id = tostring (device["bound-id"])

    local function cancel_timer (tbl)
      if tbl[dev_id] == nil then
        return false
      end
      tbl[dev_id]:destroy ()
      tbl[dev_id] = nil
      return true
    end

    -- Always save the current profile when it changes
    local cur_profile = getCurrentProfile (device)
    if cur_profile ~= nil then
      if isHeadsetProfile (device, cur_profile) then
        log:info (device, "Saving headset profile " .. cur_profile.name)
        saveHeadsetProfile (device, cur_profile.name, cur_profile.save)
        -- Explicit headset (pactl/settings) must not be reverted by a
        -- restore timer armed when the previous capture stream closed.
        if cancel_timer (restore_timeout_source) then
          log:info (device, "Cancelled profile restore on device " .. dev_id)
        end
      else
        log:info (device, "Saving non-headset profile " .. cur_profile.name)
        saveNonHeadsetProfile (device, cur_profile.name)
        if cancel_timer (switch_timeout_source) then
          log:info (device, "Cancelled profile switch on device " .. dev_id)
        end
      end
    end
  end
}

-- Local override: start the settle timer when a Bluetooth device appears.
local device_added_hook = SimpleEventHook {
  name = "bluez-device-added@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "device-added" },
      Constraint { "device.api", "=", "bluez5" },
    },
  },
  execute = function (event)
    local source = event:get_source ()
    local device = event:get_subject ()
    -- same key as the loopback node's "device.id" property (a string)
    local dev_id = tostring (device["bound-id"])

    if settle_timeout_source[dev_id] ~= nil then
      settle_timeout_source[dev_id]:destroy ()
      settle_timeout_source[dev_id] = nil
    end
    deferred_switch[dev_id] = nil
    log:notice (device, "Bluetooth device added; headset profile switches are deferred for "
        .. HEADSET_SETTLE_MSEC .. " ms")
    settle_timeout_source[dev_id] = Core.timeout_add (HEADSET_SETTLE_MSEC, function ()
      settle_timeout_source[dev_id] = nil
      if deferred_switch[dev_id] then
        deferred_switch[dev_id] = nil
        log:notice ("Device " .. dev_id .. " has settled; re-evaluating Bluetooth profiles")
        source:call ("push-event", "evaluate-bluetooth-profiles", nil, nil)
      end
      return false
    end)
  end
}

-- Local override: see the comment at HEADSET_ERROR_WINDOW_USEC. The SCO
-- source is media.class "Audio/Source/Internal" while the loopback source the
-- applications see is "Audio/Source"; hence the wildcard and the name check.
local sco_source_error_hook = SimpleEventHook {
  name = "bluez-sco-source-error@autoswitch-bluetooth-profile",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-state-changed" },
      Constraint { "media.class", "matches", "Audio/Source*" },
      Constraint { "device.id", "+" },
    },
  },
  execute = function (event)
    if event:get_properties ()["event.subject.new-state"] ~= "error" then
      return
    end

    local node = event:get_subject ()
    local name = node.properties ["node.name"] or ""
    if node.properties ["bluez5.loopback"] == "true" or
        not string.find (name, "^bluez_input%.") then
      return
    end

    local dev_id = tostring (node.properties ["device.id"])
    local now = GLib.get_monotonic_time ()
    local switched = headset_switch_usec[dev_id]
    if switched == nil or now - switched > HEADSET_ERROR_WINDOW_USEC then
      return
    end
    if last_report_usec[dev_id] ~= nil and
        now - last_report_usec[dev_id] < HEADSET_REPORT_HOLDOFF_USEC then
      return
    end

    last_report_usec[dev_id] = now
    log:warning (SCO_DEAD_MARKER .. " node=" .. name .. " errored "
        .. tostring ((now - switched) // 1000)
        .. " ms after the headset switch; the headset needs a reconnect")
  end
}

function evaluatePersistentStorage ()
  if Settings.get_boolean ("bluetooth.use-persistent-storage") and
      not persistent_storage_hooks_registered then
    state = State ("bluetooth-autoswitch")
    headset_profiles = state:load ()
    persistent_storage_hooks_registered = true
  elseif persistent_storage_hooks_registered then
    state = nil
    headset_profiles = {}
    persistent_storage_hooks_registered = false
  end
end

function evaluateAutoswitch ()
  if Settings.get_boolean ("bluetooth.autoswitch-to-headset-profile") and
      not autoswitch_hooks_registered then
    capture_stream_links = {}
    restore_timeout_source = {}
    switch_timeout_source = {}
    switch_profile_hook:register ()
    restore_profile_hook:register ()
    evaluate_bluetooth_profiles_hook:register ()
    link_added_hook:register ()
    link_removed_hook:register ()
    state_changed_hook:register ()
    node_added_hook:register ()
    device_profile_changed_hook:register ()
    device_added_hook:register ()
    sco_source_error_hook:register ()
    autoswitch_hooks_registered = true
  elseif autoswitch_hooks_registered then
    capture_stream_links = nil
    restore_timeout_source = nil
    switch_timeout_source = nil
    switch_profile_hook:remove ()
    restore_profile_hook:remove ()
    evaluate_bluetooth_profiles_hook:remove ()
    link_added_hook:remove ()
    link_removed_hook:remove ()
    state_changed_hook:remove ()
    node_added_hook:remove ()
    device_profile_changed_hook:remove ()
    device_added_hook:remove ()
    sco_source_error_hook:remove ()
    headset_switch_usec = {}
    last_report_usec = {}
    for _, t in pairs (settle_timeout_source) do t:destroy () end
    settle_timeout_source = {}
    deferred_switch = {}
    autoswitch_hooks_registered = false
  end
end

Settings.subscribe ("bluetooth.use-persistent-storage", function ()
  evaluatePersistentStorage ()
end)
evaluatePersistentStorage ()

Settings.subscribe ("bluetooth.autoswitch-to-headset-profile", function ()
  evaluateAutoswitch ()
end)
evaluateAutoswitch ()

log:notice ("autoswitch-bluetooth-profile: local override with " .. HEADSET_SETTLE_MSEC
    .. " ms headset settle delay and dead-microphone report loaded")
