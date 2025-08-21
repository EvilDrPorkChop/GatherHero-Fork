-- GH_Events.lua
-- Event handling for Gather Hero

local addonName, GH = ...

-- Track whether we've initialized to prevent double initialization
local hasInitialized = false

-- Register events and initialize addon
local function OnEvent(self, event, ...)
  print("GH Event fired:", event, ...)
  if event == "ADDON_LOADED" and ... == addonName then
    -- Addon loaded
  elseif event == "CHAT_MSG_LOOT" then
    local message = ...
    GH:DebugLoot("Loot message received: " .. message)
    GH:ProcessLootMessage(message)
  elseif event == "CHAT_MSG_MONEY" then
    local message = ...
    GH:DebugLoot("Money message received: " .. message)
    GH:ProcessMoneyMessage(message)
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Only initialize once to prevent duplicate frames
    if not hasInitialized then
      GH:InitDB()

      -- Make sure we don't have an existing frame before creating a new one
      if GH.counterFrame then
        GH.counterFrame:Hide()
        GH.counterFrame:SetParent(nil)
        GH.counterFrame = nil
      end

      GH:InitializeUI()

      -- Initialize TSM if we haven't already
      if not GH.TSM_API then
        GH:InitTSM()
      end

      -- Initialize session state
      GH.sessionState = "idle"
      GH.currentSessionId = nil
      GH.pauseStartTime = nil
      GH.totalPausedTime = 0

      -- When loading, make sure session buttons are in correct state
      if GH.UpdateSessionButtons then
        GH:UpdateSessionButtons()
      end

      hasInitialized = true
    else
      -- Check visibility setting before showing
      if GH.counterFrame then
        if GatherHeroDB and GatherHeroDB.displaySettings and
            GatherHeroDB.displaySettings.showCounter == false then
          GH.counterFrame:Hide()
        else
          GH.counterFrame:Show()
        end
      end
    end
  elseif event == "UNIT_AURA" and ... == "player" then
    -- Player buffs changed, let's see if they used a Phial
    local hadPhial = GH.phialActive
    GH:CheckPhialStatus()

    -- If they didn't have a Phial before but now they do, they must have used one
    if not hadPhial and GH.phialActive then
      GH.lastPhialUse = GetTime()
      GH.phialWarningShown = false -- Reset the warning flag so it can show again if buff expires
    end
  end
end

-- Create and register event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA") -- To track buff changes
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("CHAT_MSG_MONEY")

-- Login handler
local function OnPlayerLogin()
  if not hasInitialized then
    GH:OnInitialize()

    -- Update old session records to include character name if missing
    GH:UpdateOldSessionRecords()

    hasInitialized = true
  end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", OnPlayerLogin)

-- Fix for gold per hour display
local function OnUpdate(self, elapsed)
  self.updateTimer = (self.updateTimer or 0) + elapsed
  if self.updateTimer < 1 then return end
  self.updateTimer = 0

  -- Check if we need to fix the gold per hour text
  if GH.counterFrame and not GH.goldPerHourText then
    -- Create gold per hour text if it doesn't exist
    GH.goldPerHourText = GH.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

    -- Position it below the gold text
    if GH.goldText then
      GH.goldPerHourText:SetPoint("TOP", GH.goldText, "BOTTOM", 0, -8)
    else
      GH.goldPerHourText:SetPoint("CENTER", GH.counterFrame, "CENTER", 0, -30)
    end

    GH.goldPerHourText:SetText("0|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t/hr")

    -- Store reference in counters table as well
    GH.counters = GH.counters or {}
    GH.counters.goldPerHourText = GH.goldPerHourText

    -- Update session status text position
    if GH.sessionStatusText then
      GH.sessionStatusText:SetPoint("TOP", GH.goldPerHourText, "BOTTOM", 0, -8)
    end

    -- Set visibility based on settings
    if GatherHeroDB and GatherHeroDB.displaySettings and
        GatherHeroDB.displaySettings.showGoldPerHour then
      GH.goldPerHourText:Show()
    else
      GH.goldPerHourText:Hide()
    end
  end
end
function GH:ProcessMoneyMessage(msg)
  -- Skip processing if at the mailbox
  if self.atMailbox then
    self:DebugLoot("At mailbox, skipping money processing")
    return
  end

  -- Skip if not in active session or not tracking all loot
  if not (self.sessionState == "active" and GatherHeroDB.sessionSettings.trackAllLoot) then
    self:DebugLoot("Not in active all-loot session, skipping money processing")
    return
  end

  -- Extract gold amount using patterns
  local gold = string.match(msg, "(%d+) Gold")
  local silver = string.match(msg, "(%d+) Silver")
  local copper = string.match(msg, "(%d+) Copper")

  gold = tonumber(gold) or 0
  silver = tonumber(silver) or 0
  copper = tonumber(copper) or 0

  local totalCopper = gold * 10000 + silver * 100 + copper

  if totalCopper > 0 then
    self:DebugLoot("Processing money: " .. totalCopper .. " copper")

    -- Add to session gold
    self.sessionGold = self.sessionGold + totalCopper

    -- Update the counter display
    self:UpdateCounter()

    -- Show floating text
    self:ShowFloatingGold(totalCopper)
  end
end

-- Create a small frame to check and fix UI elements
local fixFrame = CreateFrame("Frame")
fixFrame:SetScript("OnUpdate", OnUpdate)
