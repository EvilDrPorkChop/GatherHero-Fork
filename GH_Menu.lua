-- GH_Menu.lua
-- Ace3 Configuration Menu for Gather Hero

local addonName, GH = ...

-- Ace3 Libraries
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-- Initialize Ace3 Configuration
function GH:InitializeMenu()
  -- Check if we've already initialized the menu
  if self.menuInitialized then
    return
  end

  -- Create options table
  local options = {
    name = "Gather Hero",
    type = "group",
    args = {
      general = {
        name = "General Settings",
        type = "group",
        order = 1,
        args = {
          headerDisplay = {
            name = "Display Options",
            type = "header",
            order = 1,
          },
          showCounter = {
            name = "Show Counter",
            desc = "Show the gold counter frame",
            type = "toggle",
            order = 2,
            get = function() return GatherHeroDB.displaySettings.showCounter end,
            set = function(_, value)
              GatherHeroDB.displaySettings.showCounter = value
              if value then
                self.counterFrame:Show()
              else
                self.counterFrame:Hide()
              end
            end,
          },

          quickLootToggle = {
            name = "Quick Looting",
            desc = "Enable or disable instant looting for gathering nodes",
            type = "toggle",
            width = "full",
            order = 5.5, -- Adjust this to fit your existing order
            get = function() return GH.QuickLoot and GH.QuickLoot.settings.enabled end,
            set = function(_, value)
              if GH.QuickLoot then
                GH.QuickLoot.settings.enabled = value
                GH.QuickLoot:SaveSettings()

                -- Open dialog for session-only option if enabling
                if value and not StaticPopupDialogs["GH_QUICKLOOT_SESSION_OPTION"] then
                  StaticPopupDialogs["GH_QUICKLOOT_SESSION_OPTION"] = {
                    text = "How would you like Quick Looting to work?",
                    button1 = "Only during gathering sessions",
                    button2 = "Always active",
                    button3 = "Only gathering items, always",
                    OnAccept = function()
                      GH.QuickLoot.settings.sessionOnly = true
                      GH.QuickLoot.settings.smartLoot = true
                      GH.QuickLoot:SaveSettings()
                    end,
                    OnCancel = function()
                      GH.QuickLoot.settings.sessionOnly = false
                      GH.QuickLoot.settings.smartLoot = false
                      GH.QuickLoot:SaveSettings()
                    end,
                    OnAlt = function()
                      GH.QuickLoot.settings.sessionOnly = false
                      GH.QuickLoot.settings.smartLoot = true
                      GH.QuickLoot:SaveSettings()
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                  }
                  StaticPopup_Show("GH_QUICKLOOT_SESSION_OPTION")
                end
              end
            end,
          },
          showFloatingText = {
            name = "Show Floating Text",
            desc = "Show floating gold text when items are looted",
            type = "toggle",
            order = 3,
            get = function() return GatherHeroDB.displaySettings.showFloatingText end,
            set = function(_, value) GatherHeroDB.displaySettings.showFloatingText = value end,
          },
          combineLoots = {
            name = "Combine Close Loots",
            desc = "Combine loots that happen within a short time window",
            type = "toggle",
            order = 4,
            get = function() return GatherHeroDB.displaySettings.combineLoots end,
            set = function(_, value) GatherHeroDB.displaySettings.combineLoots = value end,
          },
          showGoldPerHour = {
            name = "Show Gold Per Hour",
            desc = "Show gold per hour calculation",
            type = "toggle",
            order = 5,
            get = function() return GatherHeroDB.displaySettings.showGoldPerHour end,
            set = function(_, value)
              GatherHeroDB.displaySettings.showGoldPerHour = value
              self:UpdateCounterVisibility()
            end,
          },
          resetSession = {
            name = "Reset Session",
            desc = "Reset the current session counter and timer",
            type = "execute",
            order = 6,
            func = function()
              self.sessionGold = 0
              self.timerActive = false
              self.sessionStartTime = nil
              self.phialWarningShown = false
              self:UpdateCounter()
              self:UpdateTimer()
              if self.goldPerHourText then
                self.goldPerHourText:SetText("0|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t/hr")
              end
            end,
          },
        },
      },

      sessions = {
        name = "Sessions",
        type = "group",
        order = 2,
        args = {
          headerSessions = {
            name = "Session Management",
            type = "header",
            order = 1,
          },
          autoStart = {
            name = "Auto-Start Session",
            desc = "Automatically start a new session when you gather your first herb or ore",
            type = "toggle",
            order = 2,
            get = function() return GatherHeroDB.sessionSettings.autoStart end,
            set = function(_, value) GatherHeroDB.sessionSettings.autoStart = value end,
          },
          confirmStop = {
            name = "Confirm Stop Session",
            desc = "Show a confirmation dialog when stopping a session",
            type = "toggle",
            order = 3,
            get = function() return GatherHeroDB.sessionSettings.confirmStop end,
            set = function(_, value) GatherHeroDB.sessionSettings.confirmStop = value end,
          },
          saveHistory = {
            name = "Save Session History",
            desc = "Save completed sessions in history",
            type = "toggle",
            order = 4,
            get = function() return GatherHeroDB.sessionSettings.saveHistory end,
            set = function(_, value) GatherHeroDB.sessionSettings.saveHistory = value end,
          },
          trackAllLoot = {
            name = "Track All Loot When Manually Started",
            desc =
            "When enabled, ALL looted items will be tracked when you manually start a session. Otherwise, only gathering profession items are tracked.",
            type = "toggle",
            width = "full",
            order = 4.5,
            get = function() return GatherHeroDB.sessionSettings.trackAllLoot end,
            set = function(_, value) GatherHeroDB.sessionSettings.trackAllLoot = value end,
          },
          sessionControls = {
            name = "Session Controls",
            type = "header",
            order = 5,
          },
          currentStatus = {
            name = "Current Session Status",
            desc = "Status of the current session",
            type = "description",
            order = 6,
            fontSize = "medium",
            func = function()
              local statusText = ""
              if GH.sessionState == "idle" then
                statusText = "Idle"
              elseif GH.sessionState == "active" then
                statusText = "Active"
              elseif GH.sessionState == "paused" then
                statusText = "Paused"
              end
              return "Status: " .. statusText
            end,
          },
          startSession = {
            name = "Start Session",
            desc = "Start a new gathering session",
            type = "execute",
            order = 7,
            func = function() GH:StartSession() end,
            disabled = function() return GH.sessionState == "active" end,
          },
          pauseSession = {
            name = "Pause Session",
            desc = "Pause the current session",
            type = "execute",
            order = 8,
            func = function() GH:PauseSession() end,
            disabled = function() return GH.sessionState ~= "active" end,
          },
          resumeSession = {
            name = "Resume Session",
            desc = "Resume a paused session",
            type = "execute",
            order = 9,
            func = function() GH:ResumeSession() end,
            disabled = function() return GH.sessionState ~= "paused" end,
          },
          stopSession = {
            name = "Stop Session",
            desc = "Stop and save the current session",
            type = "execute",
            order = 10,
            func = function()
              if GatherHeroDB.sessionSettings.confirmStop and GH.sessionGold > 0 then
                StaticPopupDialogs["GH_CONFIRM_STOP_SESSION"] = {
                  text = "Stop the current gathering session?",
                  button1 = "Yes",
                  button2 = "No",
                  OnAccept = function() GH:StopSession() end,
                  timeout = 0,
                  whileDead = true,
                  hideOnEscape = true,
                  preferredIndex = 3,
                }
                StaticPopup_Show("GH_CONFIRM_STOP_SESSION")
              else
                GH:StopSession()
              end
            end,
            disabled = function() return GH.sessionState == "idle" end,
          },
        },
      },
      autoSave = {
        name = "Auto-Save",
        type = "group",
        order = 2.5, -- Position between Sessions and Gathering Buffs
        args = {
          headerAutoSave = {
            name = "Auto-Save Settings",
            type = "header",
            order = 1,
          },
          autoSaveDescription = {
            name = "Auto-save helps protect your session data in case of unexpected game crashes.",
            desc = "Configure how frequently your session data is backed up.",
            type = "description",
            order = 2,
            fontSize = "medium",
            width = "full",
          },
          enabled = {
            name = "Enable Auto-Save",
            desc = "Automatically save your session data at regular intervals",
            type = "toggle",
            order = 3,
            width = "full",
            get = function()
              if not GatherHeroDB.autoSave then
                GatherHeroDB.autoSave = {
                  enabled = true,
                  interval = 60,
                  lastSave = 0
                }
              end
              return GatherHeroDB.autoSave.enabled
            end,
            set = function(_, value)
              GatherHeroDB.autoSave.enabled = value
            end,
          },
          interval = {
            name = "Save Interval",
            desc = "How often to save session data (in seconds)",
            type = "range",
            order = 4,
            min = 15,
            max = 300,
            step = 15,
            width = "full",
            get = function()
              if not GatherHeroDB.autoSave then
                GatherHeroDB.autoSave = {
                  enabled = true,
                  interval = 60,
                  lastSave = 0
                }
              end
              return GatherHeroDB.autoSave.interval
            end,
            set = function(_, value)
              GatherHeroDB.autoSave.interval = value
            end,
            disabled = function()
              return not GatherHeroDB.autoSave or not GatherHeroDB.autoSave.enabled
            end,
          },
          intervalDescription = {
            name = function()
              local interval = 60
              if GatherHeroDB.autoSave then
                interval = GatherHeroDB.autoSave.interval or 60
              end

              local timeText
              if interval < 60 then
                timeText = interval .. " seconds"
              elseif interval == 60 then
                timeText = "1 minute"
              elseif interval < 120 then
                timeText = "1 minute and " .. (interval - 60) .. " seconds"
              elseif interval % 60 == 0 then
                timeText = (interval / 60) .. " minutes"
              else
                timeText = math.floor(interval / 60) .. " minutes and " .. (interval % 60) .. " seconds"
              end

              return "Your session will be saved automatically every " .. timeText .. "."
            end,
            type = "description",
            order = 5,
            fontSize = "medium",
            width = "full",
            disabled = function()
              return not GatherHeroDB.autoSave or not GatherHeroDB.autoSave.enabled
            end,
          },
          lastSaveInfo = {
            name = function()
              if not GatherHeroDB.autoSave or not GatherHeroDB.autoSave.lastSave or GatherHeroDB.autoSave.lastSave == 0 then
                return "No auto-save has occurred yet."
              end

              local currentTime = GetTime()
              local lastSave = GatherHeroDB.autoSave.lastSave
              local timeSince = math.floor(currentTime - lastSave)

              if timeSince < 0 then
                return "Last auto-save: just now"
              elseif timeSince < 60 then
                return "Last auto-save: " .. timeSince .. " seconds ago"
              elseif timeSince < 120 then
                return "Last auto-save: 1 minute ago"
              elseif timeSince < 3600 then
                return "Last auto-save: " .. math.floor(timeSince / 60) .. " minutes ago"
              elseif timeSince < 7200 then
                return "Last auto-save: 1 hour ago"
              else
                return "Last auto-save: " .. math.floor(timeSince / 3600) .. " hours ago"
              end
            end,
            type = "description",
            order = 6,
            fontSize = "medium",
            width = "full",
            hidden = function()
              -- Only show if auto-save is enabled and a save has occurred
              return not GatherHeroDB.autoSave or not GatherHeroDB.autoSave.enabled or not GatherHeroDB.autoSave
                  .lastSave or GatherHeroDB.autoSave.lastSave == 0
            end,
          },
          saveNow = {
            name = "Save Now",
            desc = "Manually save your current session data now",
            type = "execute",
            order = 7,
            func = function()
              -- Only allow manual save if there's an active session
              if GH.sessionState ~= "active" then
                print("|cFFFF0000Gather Hero:|r Cannot save - no active session.")
                return
              end

              -- Calculate current session time
              local currentTime = GetTime()
              local pauseTime = GH.totalPausedTime or 0
              local sessionTime = currentTime - GH.sessionStartTime - pauseTime

              -- Only save if the session is longer than 30 seconds
              if sessionTime < 30 then
                print("|cFFFF0000Gather Hero:|r Session is too short to save (less than 30 seconds).")
                return
              end

              -- Create a backup of the current session
              local sessionBackup = {
                id = GH.currentSessionId,
                startTime = GH.sessionStartTime,
                lastSaveTime = currentTime,
                duration = sessionTime,
                gold = GH.sessionGold,
                goldPerHour = (sessionTime > 0) and (GH.sessionGold * 3600 / sessionTime) or 0,
                date = date("%Y-%m-%d %H:%M:%S"),
                character = UnitName("player") .. "-" .. GetRealmName(),
                nodeCount = GH.nodeCount,
                zone = GH.currentSessionZone,
                warmode = GH.currentSessionWarmode,

                -- Detailed data fields
                items = GH:DeepCopyTable(GH.sessionItems or {}),
                professionType = GH.sessionProfessionType or "Unknown",
                zoneBreakdown = GH:DeepCopyTable(GH.sessionZoneBreakdown or {}),
                timeSpent = sessionTime,

                -- Flag as a manually saved session
                isAutoSaved = true,
                manualSave = true
              }

              -- Store the backup in the saved variables
              GatherHeroDB.currentSessionBackup = sessionBackup

              -- Update last save time
              if not GatherHeroDB.autoSave then
                GatherHeroDB.autoSave = {
                  enabled = true,
                  interval = 60,
                  lastSave = 0
                }
              end
              GatherHeroDB.autoSave.lastSave = currentTime

              print("|cFF00FF00Gather Hero:|r Session manually saved.")
            end,
            disabled = function()
              return GH.sessionState ~= "active"
            end,
          },
          loadLatestBackup = {
            name = "Load Latest Auto-Save",
            desc = "Load the most recent auto-saved session data",
            type = "execute",
            order = 8,
            width = "full",
            func = function()
              -- Check if there's a backed-up session
              if not GatherHeroDB.currentSessionBackup then
                print("|cFFFF0000Gather Hero:|r No auto-saved session found.")
                return
              end

              -- Check if we're already in a session
              if GH.sessionState ~= "idle" then
                -- Create confirmation dialog
                StaticPopupDialogs["GH_CONFIRM_LOAD_BACKUP"] = {
                  text = "You currently have an active session. Loading the backup will replace it. Continue?",
                  button1 = "Yes",
                  button2 = "No",
                  OnAccept = function()
                    GH:LoadBackupSession(GatherHeroDB.currentSessionBackup)
                  end,
                  timeout = 0,
                  whileDead = true,
                  hideOnEscape = true,
                  preferredIndex = 3,
                }
                StaticPopup_Show("GH_CONFIRM_LOAD_BACKUP")
              else
                -- No active session, load directly
                GH:LoadBackupSession(GatherHeroDB.currentSessionBackup)
              end
            end,
            disabled = function()
              return not GatherHeroDB.currentSessionBackup
            end,
          },

          backupInfo = {
            name = function()
              if not GatherHeroDB.currentSessionBackup then
                return "No auto-save data available."
              end

              local backup = GatherHeroDB.currentSessionBackup
              local goldAmount = math.floor((backup.gold or 0) / 10000)
              local nodeCount = backup.nodeCount or 0
              local dateStr = backup.date or "Unknown date"

              return string.format("Latest backup: %s\nGold: %dg | Nodes: %d | Duration: %s",
                dateStr,
                goldAmount,
                nodeCount,
                GH:FormatTime(backup.duration or 0))
            end,
            type = "description",
            order = 9,
            fontSize = "medium",
            width = "full",
            hidden = function()
              return not GatherHeroDB.currentSessionBackup
            end,
          },
        },
      },
      phial = {
        name = "Gathering Buffs",
        type = "group",
        order = 3,
        args = {
          headerPhial = {
            name = "Khaz Algar Gathering Buffs",
            type = "header",
            order = 1,
            desc = "These settings only apply when in Khaz Algar zones (The War Within)",
          },
          khazAlgarInfo = {
            name = "Khaz Algar Only",
            desc = "These buff checks only apply when you are in Khaz Algar zones from The War Within expansion",
            type = "description",
            order = 2,
            fontSize = "medium",
            width = "full",
          },
          checkPhial = {
            name = "Check for Phial of Truesight",
            desc = "Check if Phial of Truesight is active when gathering herbs or mining in Khaz Algar",
            type = "toggle",
            order = 3,
            get = function() return GatherHeroDB.phialSettings.checkPhial end,
            set = function(_, value) GatherHeroDB.phialSettings.checkPhial = value end,
          },
          showWarning = {
            name = "Show Phial Warning",
            desc = "Show a warning if Phial of Truesight is not active",
            type = "toggle",
            order = 4,
            get = function() return GatherHeroDB.phialSettings.showWarning end,
            set = function(_, value) GatherHeroDB.phialSettings.showWarning = value end,
          },
          checkFirewater = {
            name = "Check for Darkmoon Firewater",
            desc = "Check if Darkmoon Firewater is active when gathering in Khaz Algar",
            type = "toggle",
            order = 5,
            get = function()
              -- Initialize if needed
              if not GatherHeroDB.gatheringBuffs then
                GatherHeroDB.gatheringBuffs = {}
              end
              return GatherHeroDB.gatheringBuffs.checkFirewater
            end,
            set = function(_, value)
              if not GatherHeroDB.gatheringBuffs then
                GatherHeroDB.gatheringBuffs = {}
              end
              GatherHeroDB.gatheringBuffs.checkFirewater = value
            end,
          },
          showFirewaterWarning = {
            name = "Show Firewater Warning",
            desc = "Show a warning if Darkmoon Firewater is not active",
            type = "toggle",
            order = 6,
            get = function()
              if not GatherHeroDB.gatheringBuffs then
                GatherHeroDB.gatheringBuffs = {}
              end
              return GatherHeroDB.gatheringBuffs.showFirewaterWarning
            end,
            set = function(_, value)
              if not GatherHeroDB.gatheringBuffs then
                GatherHeroDB.gatheringBuffs = {}
              end
              GatherHeroDB.gatheringBuffs.showFirewaterWarning = value
            end,
          },

          -- Fishing Equipment (applies in all zones)
          headerFishing = {
            name = "Fishing Equipment (All Zones)",
            type = "header",
            order = 7,
          },
          checkFishingCap = {
            name = "Check for Fishing Cap",
            desc = "Check if you're wearing your fishing cap when fishing",
            type = "toggle",
            order = 8,
            get = function() return GatherHeroDB.phialSettings.checkFishingCap end,
            set = function(_, value) GatherHeroDB.phialSettings.checkFishingCap = value end,
          },
          fishingCapTypes = {
            name = "Fishing Caps",
            desc = "The addon will check for these fishing caps",
            type = "description",
            order = 9,
            fontSize = "medium",
            width = "full",
            func = function() return "• Weavercloth Fishing Cap\n• Artisan Fishing Cap" end,
          },

          -- Manual check button
          checkNow = {
            name = "Check Buffs Now",
            desc = "Check if gathering buffs are currently active for your current zone",
            type = "execute",
            order = 10,
            func = function()
              local inKhazAlgarZone = GH:IsInKhazAlgarZone()

              if inKhazAlgarZone then
                -- We're in Khaz Algar, check both buffs
                print("|cFF00FF00Gather Hero:|r You are in Khaz Algar! Checking appropriate buffs...")

                -- Check for Phial of Truesight
                if GH:CheckPhialStatus() then
                  print("|cFF00FF00Gather Hero:|r Phial of Truesight is active!")
                else
                  if GatherHeroDB.phialSettings.showWarning and not GH.phialWarningShown then
                    GH:ShowPhialWarning()
                  else
                    print("|cFFFF0000Gather Hero:|r Phial of Truesight is NOT active!")
                  end
                end

                -- Check for Darkmoon Firewater
                if GatherHeroDB.gatheringBuffs and GatherHeroDB.gatheringBuffs.checkFirewater then
                  if GH:CheckFirewaterStatus() then
                    print("|cFF00FF00Gather Hero:|r Darkmoon Firewater is active!")
                  else
                    if GatherHeroDB.gatheringBuffs.showFirewaterWarning and not GH.firewaterWarningShown then
                      GH:ShowFirewaterWarning()
                    else
                      print("|cFFFF0000Gather Hero:|r Darkmoon Firewater is NOT active!")
                    end
                  end
                end
              else
                -- Not in Khaz Algar
                print("|cFFFF9900Gather Hero:|r You are not in Khaz Algar. Gathering buff checks are skipped.")
                print("|cFFFF9900Gather Hero:|r Current zone: " .. GetZoneText())
              end

              -- Check for fishing cap (anywhere)
              local hasCapOn, hasCapInBags = GH:CheckFishingCap()
              if hasCapOn then
                print("|cFF00FF00Gather Hero:|r Fishing cap is equipped!")
              elseif hasCapInBags then
                if GatherHeroDB.phialSettings.checkFishingCap then
                  GH:ShowFishingCapWarning()
                else
                  print("|cFFFF0000Gather Hero:|r You have a fishing cap but it's not equipped!")
                end
              end
            end,
          },
        },
      },

      quickLoot = {
        name = "Quick Loot",
        type = "group",
        order = 4,
        args = {
          headerQuickLoot = {
            name = "Quick Loot Settings",
            type = "header",
            order = 1,
          },
          enabled = {
            name = "Enable Quick Looting",
            desc = "Automatically loot gathering nodes without showing the loot window",
            type = "toggle",
            width = "full",
            order = 2,
            get = function() return GH.QuickLoot.settings.enabled end,
            set = function(_, value)
              GH.QuickLoot.settings.enabled = value
              GH.QuickLoot:SaveSettings()
            end,
          },
          sessionOnly = {
            name = "Only During Gathering Sessions",
            desc = "Only auto-loot when a gathering session is active",
            type = "toggle",
            width = "full",
            order = 3,
            get = function() return GH.QuickLoot.settings.sessionOnly end,
            set = function(_, value)
              GH.QuickLoot.settings.sessionOnly = value
              GH.QuickLoot:SaveSettings()
            end,
          },
          smartLoot = {
            name = "Smart Looting",
            desc = "Only auto-loot gathering profession items (herbs, ore, skins, etc.)",
            type = "toggle",
            order = 4,
            get = function() return GH.QuickLoot.settings.smartLoot end,
            set = function(_, value)
              GH.QuickLoot.settings.smartLoot = value
              GH.QuickLoot:SaveSettings()
            end,
          },
          suppressLootUI = {
            name = "Hide Loot Window",
            desc = "Hide the default loot window when auto-looting",
            type = "toggle",
            order = 5,
            get = function() return GH.QuickLoot.settings.suppressLootUI end,
            set = function(_, value)
              GH.QuickLoot.settings.suppressLootUI = value
              GH.QuickLoot:SaveSettings()
            end,
          },
          autoConfirmBOP = {
            name = "Auto-confirm BoP Items",
            desc = "Automatically confirm Bind on Pickup items when not in a group",
            type = "toggle",
            order = 6,
            get = function() return GH.QuickLoot.settings.autoConfirmBOP end,
            set = function(_, value)
              GH.QuickLoot.settings.autoConfirmBOP = value
              GH.QuickLoot:SaveSettings()
            end,
          },
          debugMode = {
            name = "Debug Mode",
            desc = "Enable debug messages for QuickLoot (for troubleshooting)",
            type = "toggle",
            order = 7,
            get = function() return GH.QuickLoot.settings.debugMode end,
            set = function(_, value)
              GH.QuickLoot.settings.debugMode = value
              GH.QuickLoot:SaveSettings()
            end,
          },
        },
      },

      appearance = {
        name = "Appearance",
        type = "group",
        order = 5,
        args = {
          headerAppearance = {
            name = "Appearance Settings",
            type = "header",
            order = 1,
          },
          panelSize = {
            name = "Panel Size",
            type = "header",
            order = 2,
          },
          width = {
            name = "Width",
            desc = "Width of the counter frame",
            type = "range",
            order = 3,
            min = 150,
            max = 400,
            step = 10,
            get = function() return GatherHeroDB.displaySettings.width end,
            set = function(_, value)
              GatherHeroDB.displaySettings.width = value
              self:ApplySettings()
            end,
          },
          height = {
            name = "Height",
            desc = "Height of the counter frame",
            type = "range",
            order = 4,
            min = 80,
            max = 300,
            step = 10,
            get = function() return GatherHeroDB.displaySettings.height end,
            set = function(_, value)
              GatherHeroDB.displaySettings.height = value
              self:ApplySettings()
            end,
          },
          scale = {
            name = "Scale",
            desc = "Scale of the counter frame",
            type = "range",
            order = 5,
            min = 0.5,
            max = 2.0,
            step = 0.1,
            get = function() return GatherHeroDB.displaySettings.scale end,
            set = function(_, value)
              GatherHeroDB.displaySettings.scale = value
              self:ApplySettings()
            end,
          },
          colorSettings = {
            name = "Color Settings",
            type = "header",
            order = 6,
          },
          backgroundColor = {
            name = "Background Color",
            desc = "Set the background color of the frame",
            type = "color",
            order = 7,
            hasAlpha = false,
            get = function()
              local color = GatherHeroDB.displaySettings.backgroundColor or { r = 0, g = 0, b = 0 }
              return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
              GatherHeroDB.displaySettings.backgroundColor = { r = r, g = g, b = b }
              self:ApplySettings()
            end,
          },
          opacity = {
            name = "Background Opacity",
            desc = "Opacity of the counter frame background",
            type = "range",
            order = 8,
            min = 0.1,
            max = 1.0,
            step = 0.1,
            get = function() return GatherHeroDB.displaySettings.opacity end,
            set = function(_, value)
              GatherHeroDB.displaySettings.opacity = value
              self:ApplySettings()
            end,
          },
          borderHeader = {
            name = "Border Settings",
            type = "header",
            order = 9,
          },
          showBorder = {
            name = "Show Border",
            desc = "Toggle the visibility of the border",
            type = "toggle",
            order = 10,
            get = function() return GatherHeroDB.displaySettings.showBorder end,
            set = function(_, value)
              GatherHeroDB.displaySettings.showBorder = value
              self:ApplySettings()
            end,
          },
          borderColor = {
            name = "Border Color",
            desc = "Set the color of the frame border",
            type = "color",
            order = 11,
            hasAlpha = false,
            disabled = function() return not GatherHeroDB.displaySettings.showBorder end,
            get = function()
              local color = GatherHeroDB.displaySettings.borderColor or { r = 0.5, g = 0.5, b = 0.5 }
              return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
              GatherHeroDB.displaySettings.borderColor = { r = r, g = g, b = b }
              self:ApplySettings()
            end,
          },
          resetAppearance = {
            name = "Reset Appearance",
            desc = "Reset appearance settings to defaults",
            type = "execute",
            order = 12,
            confirm = true,
            confirmText = "Are you sure you want to reset all appearance settings to defaults?",
            func = function()
              GatherHeroDB.displaySettings.width = 260
              GatherHeroDB.displaySettings.height = 160
              GatherHeroDB.displaySettings.scale = 1.0
              GatherHeroDB.displaySettings.backgroundColor = { r = 0, g = 0, b = 0 }
              GatherHeroDB.displaySettings.opacity = 0.8
              GatherHeroDB.displaySettings.showBorder = false
              GatherHeroDB.displaySettings.borderColor = { r = 0.5, g = 0.5, b = 0.5 }
              self:ApplySettings()
            end,
          },
        },
      },

      soundSettings = {
        name = "Sound Settings",
        type = "group",
        order = 6,
        args = {
          headerSound = {
            name = "Sound Effect Settings",
            type = "header",
            order = 1,
          },
          enableSounds = {
            name = "Enable Node Value Sounds",
            desc = "Play special sounds when high-value nodes are found",
            type = "toggle",
            order = 2,
            get = function() return GatherHeroDB.soundSettings.enabled end,
            set = function(_, value)
              GatherHeroDB.soundSettings.enabled = value
              GH.soundsEnabled = value
            end,
          },
          testSounds = {
            name = "Test Sounds",
            type = "header",
            order = 3,
          },
          testGoodNode = {
            name = "Test Good Node Sound",
            desc = "Play the sound effect for a node worth 2x the average",
            type = "execute",
            order = 4,
            func = function()
              local volume = GatherHeroDB.soundSettings.volume or 1.0
              PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\cha-ching.ogg", "Master", volume)
            end,
          },
          testGreatNode = {
            name = "Test Great Node Sound",
            desc = "Play the sound effect for a node worth 3x the average",
            type = "execute",
            order = 5,
            func = function()
              local volume = GatherHeroDB.soundSettings.volume or 1.0
              PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master", volume)
            end,
          },
          soundVolume = {
            name = "Sound Volume",
            desc = "Adjust the volume of the special sound effects",
            type = "range",
            order = 6,
            min = 0,
            max = 1,
            step = 0.1,
            get = function() return GatherHeroDB.soundSettings.volume end,
            set = function(_, value) GatherHeroDB.soundSettings.volume = value end,
          },
        },
      },

      stats = {
        name = "Statistics",
        type = "group",
        order = 7,
        args = {
          headerStats = {
            name = "Session History",
            type = "header",
            order = 1,
          },
          viewSessionHistory = {
            name = "View Session History",
            desc = "View your recent gathering sessions",
            type = "execute",
            order = 2,
            func = function()
              -- Call the ShowHistoryWindow function directly
              GH:ShowHistoryWindow()
            end,
          },
          clearSessionHistory = {
            name = "Clear Session History",
            desc = "Clear all saved session history records",
            type = "execute",
            order = 3,
            confirm = true,
            confirmText =
            "Are you sure you want to clear all session history? This will delete all your saved session records.",
            func = function()
              GatherHeroDB.goldTracking.sessionHistory = {}
            end,
          },
          resetStatsHeader = {
            name = "Reset Options",
            type = "header",
            order = 4,
          },
          resetStats = {
            name = "Reset Statistics",
            desc = "Reset all tracked high scores (best GPH, best session, today's total)",
            type = "execute",
            order = 5,
            confirm = true,
            confirmText =
            "Are you sure you want to reset all statistics? This will reset high scores and today's totals.",
            func = function()
              GatherHeroDB.goldTracking.bestGPH = 0
              GatherHeroDB.goldTracking.bestSessionGold = 0
              GatherHeroDB.goldTracking.todayTotal = 0
              GatherHeroDB.goldTracking.todayDate = date("%Y-%m-%d")
            end,
          },
          highScores = {
            name = "High Scores",
            desc = "View challenge high scores and leaderboards",
            type = "execute",
            order = 6,
            func = function()
              if GH.HighScorePanel then
                GH.HighScorePanel:CreatePanel()
              end
            end,
          },
        },
      },
    },
  }

  -- If TSM is detected, add TSM price source options
  if self.TSM_API then
    options.args.priceSettings = {
      name = "Price Settings",
      type = "group",
      order = 8,
      args = {
        headerPrice = {
          name = "TSM Price Source Settings",
          type = "header",
          order = 1,
        },
        priceSource = {
          name = "Price Source",
          desc = "Select which TSM price source to use for item values",
          type = "select",
          order = 2,
          values = {
            ["DBMarket"] = "DBMarket (Market Value)",
            ["DBMinBuyout"] = "DBMinBuyout (Minimum Buyout)",
            ["DBHistorical"] = "DBHistorical (Historical Price)",
            ["DBRegionMarketAvg"] = "DBRegionMarketAvg (Region Market Value)",
          },
          get = function() return GatherHeroDB.priceSource end,
          set = function(_, value) GatherHeroDB.priceSource = value end,
        },
      },
    }
  end

  -- Register the options with AceConfig
  AceConfig:RegisterOptionsTable("GatherHero", options)

  -- Create the options panel using the traditional method
  self.optionsFrame = AceConfigDialog:AddToBlizOptions("GatherHero", "Gather Hero")

  -- Add slash command to open config
  self.slashCommands = self.slashCommands or {}
  table.insert(self.slashCommands, "config")

  self.menuInitialized = true

  -- Apply current settings to UI
  self:ApplySettings()
end

-- Function to open settings
function GH:OpenSettings()
  -- Use the reliable AceConfigDialog method
  AceConfigDialog:Open("GatherHero")
end

-- Apply current settings to UI elements
function GH:ApplySettings()
  if not self.counterFrame then return end

  if GatherHeroDB and GatherHeroDB.displaySettings then
    -- Apply scale
    if GatherHeroDB.displaySettings.scale then
      self.counterFrame:SetScale(GatherHeroDB.displaySettings.scale)
    end

    -- Apply size
    if GatherHeroDB.displaySettings.width and GatherHeroDB.displaySettings.height then
      self.counterFrame:SetSize(GatherHeroDB.displaySettings.width,
        GatherHeroDB.displaySettings.height)
    end

    -- Get colors from settings
    local bgColor = {
      r = GatherHeroDB.displaySettings.backgroundColor and
          GatherHeroDB.displaySettings.backgroundColor.r or 0,
      g = GatherHeroDB.displaySettings.backgroundColor and
          GatherHeroDB.displaySettings.backgroundColor.g or 0,
      b = GatherHeroDB.displaySettings.backgroundColor and
          GatherHeroDB.displaySettings.backgroundColor.b or 0,
      a = GatherHeroDB.displaySettings.opacity or 0.8
    }

    local borderColor = {
      r = GatherHeroDB.displaySettings.borderColor and GatherHeroDB.displaySettings.borderColor.r or
          0.5,
      g = GatherHeroDB.displaySettings.borderColor and GatherHeroDB.displaySettings.borderColor.g or
          0.5,
      b = GatherHeroDB.displaySettings.borderColor and GatherHeroDB.displaySettings.borderColor.b or
          0.5,
      a = 1
    }

    local showBorder = true
    if GatherHeroDB.displaySettings.showBorder ~= nil then
      showBorder = GatherHeroDB.displaySettings.showBorder
    end

    -- Apply background and border colors
    if self.counterFrame.SetBackdrop then
      local backdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 16,
      }

      -- Only add border if it should be shown
      if showBorder then
        backdrop.edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"
        backdrop.edgeSize = 16
        backdrop.insets = { left = 4, right = 4, top = 4, bottom = 4 }
      end

      self.counterFrame:SetBackdrop(backdrop)
      self.counterFrame:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)

      if showBorder then
        self.counterFrame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
      end
    else
      -- For 11.1.0 compatibility
      if self.counterFrame.background then
        self.counterFrame.background:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
      end

      -- Update border if it exists
      if self.counterFrame.border then
        if showBorder then
          self.counterFrame.border:Show()
          self.counterFrame.border:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        else
          self.counterFrame.border:Hide()
        end
        -- Create border if it should be shown but doesn't exist
      elseif showBorder and not self.counterFrame.border then
        local border = CreateFrame("Frame", nil, self.counterFrame, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop({
          edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
          edgeSize = 16,
          insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        border:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        self.counterFrame.border = border
      end
    end

    -- Apply visibility settings
    if not GatherHeroDB.displaySettings.showCounter then
      self.counterFrame:Hide()
    else
      self.counterFrame:Show()
    end

    -- Apply gold per hour visibility
    if self.goldPerHourText then
      if not GatherHeroDB.displaySettings.showGoldPerHour then
        self.goldPerHourText:Hide()
      else
        self.goldPerHourText:Show()
      end
    end
  end
end

-- Update counter visibility based on settings
function GH:UpdateCounterVisibility()
  if not self.counterFrame then return end

  if self.goldPerHourText and GatherHeroDB and GatherHeroDB.displaySettings then
    if GatherHeroDB.displaySettings.showGoldPerHour then
      self.goldPerHourText:Show()
    else
      self.goldPerHourText:Hide()
    end
  end
end
