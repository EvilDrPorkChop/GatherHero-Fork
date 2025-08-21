-- GGT_Utils.lua
-- Utility functions for GatherHero

local _, GH = ...

-- Variables for Phial status tracking
GH.phialWarningShown = false -- If we've shown the warning already in this session
GH.lastPhialUse = 0          -- When the player last used a Phial
GH.phialActive = false       -- If Phial buff is currently active
GH.TSM_API = nil             -- TSM API reference

-- New variables for tracking additional buffs
GH.firewaterWarningShown = false -- If we've shown the Darkmoon Firewater warning already in this session
GH.firewaterActive = false       -- If Darkmoon Firewater buff is currently active

-- Wait for TSM to be loaded
function GH:InitTSM()
  if _G.TSM_API then
    self.TSM_API = _G.TSM_API
    C_Timer.After(2, function() GH:InitTSM() end)
  end
end

-- New function to check if player has Darkmoon Firewater buff
function GH:CheckFirewaterStatus()
  self.firewaterActive = false -- Assume no buff until we find it

  -- Use tooltip scanning method which works in any WoW version
  local tooltipName = "GHScanningTooltip"
  if not _G[tooltipName] then
    CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
  end
  local tooltip = _G[tooltipName]

  -- Scan through player buffs looking for Darkmoon Firewater
  for i = 1, 40 do
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    pcall(function() tooltip:SetUnitBuff("player", i) end) -- Use pcall to prevent errors

    -- Check each line of the tooltip
    for j = 1, tooltip:NumLines() do
      local textLine = _G[tooltipName .. "TextLeft" .. j]
      if textLine then
        local text = textLine:GetText() or ""
        if text:find("Darkmoon Firewater") then
          self.firewaterActive = true
          return true
        end
      end
    end
  end

  return false
end

-- Show warning for missing Darkmoon Firewater
function GH:ShowFirewaterWarning()
  -- Only show once per session
  if self.firewaterWarningShown then return end
  self.firewaterWarningShown = true

  -- Create popup for Darkmoon Firewater
  StaticPopupDialogs["GH_FIREWATER_WARNING"] = {
    text = "You're gathering without Darkmoon Firewater active!\n\nThis buff increases gathering speed significantly.",
    button1 = "Remind me later",
    button2 = "Ignore",
    OnAccept = function()
      -- Reset the warning so it can show again later in this session
      self.firewaterWarningShown = false
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  -- Show the popup
  StaticPopup_Show("GH_FIREWATER_WARNING")

  -- Play warning sound
  PlaySound(SOUNDKIT.RAID_WARNING, "Master", false)
end

-- New function to check for fishing cap
function GH:CheckFishingCap()
  -- Check if player is wearing a fishing cap on head slot
  local headSlotID = 1 -- Head is slot ID 1
  local itemLink = GetInventoryItemLink("player", headSlotID)

  if itemLink then
    local itemName = GetItemInfo(itemLink)
    if itemName then
      -- Check if it's one of the fishing caps
      if itemName == "Weavercloth Fishing Cap" or itemName == "Artisan Fishing Cap" then
        return true
      end
    end
  end

  -- Not wearing fishing cap, check if they have it in their bags
  local hasFishingCapInBags = false

  for bagID = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
      if itemInfo and itemInfo.hyperlink then
        local bagItemName = GetItemInfo(itemInfo.hyperlink)
        if bagItemName and (bagItemName == "Weavercloth Fishing Cap" or bagItemName == "Artisan Fishing Cap") then
          hasFishingCapInBags = true
          -- Remember which fishing cap they have for the warning
          self.fishingCapName = bagItemName
          self.fishingCapBagID = bagID
          self.fishingCapSlot = slot
          break
        end
      end
    end
    if hasFishingCapInBags then break end
  end

  -- Return false if they don't have the cap on, but indicate if it's in bags
  return false, hasFishingCapInBags
end

-- Show warning for fishing without cap
function GH:ShowFishingCapWarning()
  if not self.fishingCapName then return end

  -- Only show once per session
  if self.fishingCapWarningShown then return end
  self.fishingCapWarningShown = true

  -- Create popup for fishing cap
  StaticPopupDialogs["GH_FISHING_CAP_WARNING"] = {
    text = "You're fishing without your " .. self.fishingCapName .. "!\n\nWearing it gives you better fishing results.",
    button1 = "Equip Cap",
    button2 = "Ignore",
    OnAccept = function()
      -- Equip the fishing cap
      C_Container.PickupContainerItem(self.fishingCapBagID, self.fishingCapSlot)
      PickupInventoryItem(1) -- 1 is the head slot
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  -- Show the popup
  StaticPopup_Show("GH_FISHING_CAP_WARNING")

  -- Play warning sound
  PlaySound(SOUNDKIT.RAID_WARNING, "Master", false)
end

-- Check if Phial of Truesight buff is active
function GH:CheckPhialStatus()
  self.phialActive = false -- Assume no buff until we find it

  -- Use tooltip scanning method which works in any WoW version
  local tooltipName = "GHScanningTooltip"
  if not _G[tooltipName] then
    CreateFrame("GameTooltip", tooltipName, nil, "GameTooltipTemplate")
  end
  local tooltip = _G[tooltipName]

  -- Scan through player buffs looking for Phial of Truesight
  for i = 1, 40 do
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    pcall(function() tooltip:SetUnitBuff("player", i) end) -- Use pcall to prevent errors

    -- Check each line of the tooltip
    for j = 1, tooltip:NumLines() do
      local textLine = _G[tooltipName .. "TextLeft" .. j]
      if textLine then
        local text = textLine:GetText() or ""
        if text:find("Phial of Truesight") or text:find("Truesight") then
          self.phialActive = true
          return true
        end
      end
    end
  end

  return false
end

-- Check if player is in a specific zone
function GH:IsPlayerInZone(zoneName)
  -- Get current zone information
  local currentZone = GetZoneText() or ""
  local currentSubZone = GetSubZoneText() or ""
  local currentMinimapZone = GetMinimapZoneText() or ""

  -- Convert to lowercase for case-insensitive comparison
  local zone = zoneName:lower()
  currentZone = currentZone:lower()
  currentSubZone = currentSubZone:lower()
  currentMinimapZone = currentMinimapZone:lower()

  -- Check if any of the current zone texts match or contain the specified zone
  return currentZone:find(zone) or
      currentSubZone:find(zone) or
      currentMinimapZone:find(zone)
end

-- Check if player is in The War Within zones (Khaz Algar)
function GH:IsInKhazAlgarZone()
  local khazAlgarZones = {
    "khaz algar",
    "isle of dorn",
    "hallowfall",
    "the ringing deeps",
    "undermine",
    "azj-kahet",
    "siren isle"
  }

  for _, zoneName in ipairs(khazAlgarZones) do
    if self:IsPlayerInZone(zoneName) then
      return true
    end
  end

  return false
end

-- Check for Phial when looting
function GH:CheckPhialWhenLooting(itemClassID, itemSubClassID, itemName)
  -- Debug output
  if self.debugMode then
    print("|cFF00FF00Gather Hero Debug:|r CheckPhialWhenLooting called for:", itemName)
  end

  -- Return early if phial checking is disabled in settings
  if GatherHeroDB and GatherHeroDB.phialSettings and
      not GatherHeroDB.phialSettings.checkPhial then
    return
  end

  -- Only skip buff checks for non-gathering items in all-loot mode
  local isPureGatheringItem = self:IsGatheringItem(itemClassID, itemSubClassID, itemName)
  if not isPureGatheringItem and self.sessionState == "active" and
      GatherHeroDB.sessionSettings.trackAllLoot then
    return -- Don't check buffs for non-gathering items in all-loot mode
  end

  -- Skip Phial check for skinning items (Leather - itemClassID 7, itemSubClassID 6)
  if itemClassID == 7 and itemSubClassID == 6 then
    return -- Skip phial check for leather/skinning items
  end

  -- Check for fishing
  local isFishing = false
  if itemName then
    local lowerName = string.lower(itemName)

    -- Check if it's a fish by common fish keywords
    if string.find(lowerName, "fish") or
        string.find(lowerName, "trout") or
        string.find(lowerName, "bass") or
        string.find(lowerName, "shark") or
        string.find(lowerName, "perch") or
        string.find(lowerName, "sturgeon") or
        string.find(lowerName, "bitterling") or
        string.find(lowerName, "dace") or
        string.find(lowerName, "pike") or
        string.find(lowerName, "minnow") then
      isFishing = true

      -- Check for fishing cap if fishing - only if we're in active session
      if self.sessionState == "active" and GatherHeroDB.phialSettings.checkFishingCap then
        local hasCapOn, hasCapInBags = self:CheckFishingCap()
        if not hasCapOn and hasCapInBags then
          self:ShowFishingCapWarning()
        end
      end

      -- Skip phial check for fishing
      return
    end

    -- Also check War Within fish list if we have it defined in the addon
    if self.warWithinFish then
      for _, fishName in ipairs(self.warWithinFish) do
        if itemName == fishName then
          isFishing = true

          -- Check for fishing cap if fishing
          if self.sessionState == "active" and GatherHeroDB.phialSettings.checkFishingCap then
            local hasCapOn, hasCapInBags = self:CheckFishingCap()
            if not hasCapOn and hasCapInBags then
              self:ShowFishingCapWarning()
            end
          end

          -- Skip phial check for known fish
          return
        end
      end
    end

    -- Also check item name for skinning-related items
    if string.find(lowerName, "leather") or
        string.find(lowerName, "hide") or
        string.find(lowerName, "skin") or
        string.find(lowerName, "scales") then
      return -- Skip phial check for skinning items by name
    end
  end

  -- Check if we're in Khaz Algar zone
  local inKhazAlgarZone = self:IsInKhazAlgarZone()

  -- Debug output
  if self.debugMode then
    print("|cFF00FF00Gather Hero Debug:|r Current zone info:")
    print("  In Khaz Algar zone:", inKhazAlgarZone)
    print("  Current zone:", GetZoneText())
    print("  Current subzone:", GetSubZoneText())
  end

  -- ONLY check Phial and Firewater in Khaz Algar zones
  if inKhazAlgarZone then
    -- Check for Phial of Truesight
    self:CheckPhialStatus()

    -- If not active and we haven't shown warning yet this session, show it
    if not self.phialActive and not self.phialWarningShown and self.timerActive then
      -- Only show warning if enabled in settings
      if not GatherHeroDB or not GatherHeroDB.phialSettings or
          GatherHeroDB.phialSettings.showWarning then
        self:ShowPhialWarning()
      end
    end

    -- Initialize gatheringBuffs if it doesn't exist yet
    if not GatherHeroDB.gatheringBuffs then
      GatherHeroDB.gatheringBuffs = {
        checkFirewater = true,
        showFirewaterWarning = true
      }

      if self.debugMode then
        print("|cFF00FF00Gather Hero Debug:|r Created missing gatheringBuffs settings")
      end
    end

    -- Check for Darkmoon Firewater in Khaz Algar zones
    if GatherHeroDB.gatheringBuffs.checkFirewater then
      -- Check for firewater buff
      self:CheckFirewaterStatus()

      -- If not active and we haven't shown warning yet this session, show it
      if not self.firewaterActive and not self.firewaterWarningShown and self.timerActive then
        -- Only show warning if enabled in settings
        if GatherHeroDB.gatheringBuffs.showFirewaterWarning then
          self:ShowFirewaterWarning()
        end
      end
    end
  end
end

-- Reset phial detection state
function GH:ResetPhialWarning()
  self.phialWarningShown = false
  self.lastPhialUse = 0
  -- Also check current status
  self:CheckPhialStatus()
end

-- Reset fishing cap detection state
function GH:ResetFishingCapWarning()
  self.fishingCapWarningShown = false
  self.fishingCapName = nil
  self.fishingCapBagID = nil
  self.fishingCapSlot = nil
end

-- Reset firewater detection state
function GH:ResetFirewaterWarning()
  self.firewaterWarningShown = false
  -- Also check current status
  self:CheckFirewaterStatus()
end

-- Format gold value to include gold, silver, and copper
function GH:FormatMoney(amount)
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)
  local copper = math.floor(amount % 100)

  return string.format(
    "%d|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t %d|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t %d|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t",
    gold, silver, copper)
end

-- Determine if an item is a gathering item (herb, ore, fish, etc.)
function GH:IsGatheringItem(itemClassID, itemSubClassID, itemName)
  -- Check for additional specific gathering-related items
  if itemName then
    -- Convert to lowercase for case-insensitive comparison
    local lowerName = string.lower(itemName)

    -- Check for specific gathering byproducts
    if lowerName == "leyline residue" or
        lowerName == "null stone" or
        lowerName == "null lotus" or
        lowerName == "weavercloth" or
        lowerName == "crystalline powder" then
      return true
    end

    -- Define list of The War Within fish
    local warWithinFish = {
      "Bismuth Bitterling",
      "Bloody Perch",
      "Crystalline Sturgeon",
      "Dilly-Dally Dace",
      "Arathor Hammerfish",
      "Dornish Pike",
      "Goldengill Trout",
      "Kaheti Slum Shark",
      "Nibbling Minnow",
      "Pale Huskfish",
      "Quiet River Bass",
      "Roaring Anglerseeker",
      "Specular Rainbowfish",
      "Whispering Stargazer",
      "\"Gold\" Fish",
      "Awoken Coelacanth",
      "Cursed Ghoulfish",
      "Queen's Lurefish",
      "Regal Dottyback",
      "Sanguine Dogfish",
      "Spiked Sea Raven"
    }

    -- Check for fish by keywords
    if string.find(lowerName, "fish") or
        string.find(lowerName, "trout") or
        string.find(lowerName, "bass") or
        string.find(lowerName, "shark") or
        string.find(lowerName, "perch") or
        string.find(lowerName, "sturgeon") or
        string.find(lowerName, "bitterling") or
        string.find(lowerName, "dace") or
        string.find(lowerName, "pike") or
        string.find(lowerName, "minnow") then
      return true
    end

    -- Check against our specific fish list
    for _, fishName in ipairs(warWithinFish) do
      if itemName == fishName then
        return true
      end
    end
  end

  -- Check for Trade Goods class (ID 7)
  if itemClassID == 7 then
    -- Check for herb subclass (ID 9)
    if itemSubClassID == 9 then
      -- This is an herb
      return true
    end

    -- Check for metal & stone subclass (ID 7)
    if itemSubClassID == 7 then
      -- This is an ore/mining material
      return true
    end

    -- Other trade goods subclasses that might be from gathering
    -- Leather (ID 6), Elemental (ID 10), etc.
    if itemSubClassID == 6 or itemSubClassID == 10 then
      return true
    end
  end

  -- Check for fish items (class 0, subclass 5 - food/drink)
  if itemClassID == 0 and itemSubClassID == 5 then
    -- Not all foods are fish, so we need to check the name
    if itemName then
      local lowerName = string.lower(itemName)
      if string.find(lowerName, "fish") or
          string.find(lowerName, "trout") or
          string.find(lowerName, "bass") or
          string.find(lowerName, "shark") or
          string.find(lowerName, "perch") then
        return true
      end
    end
  end

  -- Fallback to keyword check for items that might be miscategorized
  if itemName then
    local lowerName = string.lower(itemName)
    if string.find(lowerName, "ore") or
        string.find(lowerName, "herb") or
        string.find(lowerName, "vein") then
      return true
    end
  end

  -- Not a gathering item
  return false
end

-- Helper function to get market value from TSM
function GH:GetMarketValue(itemLink, count)
  -- Default to 0
  local marketValue = 0
  local totalValue = 0

  -- Try to get TSM item string
  if self.TSM_API and self.TSM_API.ToItemString then
    local itemString = self.TSM_API.ToItemString(itemLink)
    if itemString then
      -- Use the price source from settings if available
      local priceSource = "DBMarket"
      if GatherHeroDB and GatherHeroDB.priceSource then
        priceSource = GatherHeroDB.priceSource
      end

      marketValue = self.TSM_API.GetCustomPriceValue(priceSource, itemString) or 0
      totalValue = marketValue * count
    end
  end

  -- If no market value found, use a placeholder
  if totalValue <= 0 then
    totalValue = count * 1000 -- 10s per item as fallback
  end

  return totalValue
end

-- Format time as HH:MM:SS
function GH:FormatTime(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = math.floor(seconds % 60)

  return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Debug helper functions
GH.Debug = {}

-- Print a table's contents recursively (up to maxDepth)
function GH.Debug:DumpTable(t, indent, maxDepth, currentDepth)
  if not t or type(t) ~= "table" then
    print("Not a table:", t)
    return
  end

  indent = indent or 0
  maxDepth = maxDepth or 3
  currentDepth = currentDepth or 0

  if currentDepth > maxDepth then
    print(string.rep("  ", indent) .. "...")
    return
  end

  for k, v in pairs(t) do
    if type(v) == "table" then
      print(string.rep("  ", indent) .. tostring(k) .. " = {")
      self:DumpTable(v, indent + 1, maxDepth, currentDepth + 1)
      print(string.rep("  ", indent) .. "}")
    else
      print(string.rep("  ", indent) .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

-- Print challenge state
function GH.Debug:PrintChallengeState()
  print("|cFF00FF00Gather Hero Debug:|r Current Challenge State:")

  if not GatherHeroDB or not GatherHeroDB.challenges then
    print("  No challenge data found")
    return
  end

  print("  Enabled:", GatherHeroDB.challenges.enabled)
  print("  Active Challenge:", GatherHeroDB.challenges.activeChallenge)
  print("  Progress:", GatherHeroDB.challenges.challengeProgress)
  print("  Goal:", GatherHeroDB.challenges.challengeGoal)
  print("  Completed:", GatherHeroDB.challenges.challengeCompleted)

  -- Print challenge-specific data
  if GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
    print("  --- High Value Node Challenge Data ---")
    local settings = GatherHeroDB.challenges.settings.highValueNode
    print("  Multiplier:", settings.currentMultiplier or settings.multiplier)

    -- Session stats
    print("  Session Gold:", GH.sessionGold)
    print("  Node Count:", GH.nodeCount)
    local avgNodeValue = GH.nodeCount > 0 and (GH.sessionGold / GH.nodeCount) or 0
    print("  Average Node Value:", GH.ChallengeMode:FormatGold(avgNodeValue))
    print("  Target Value:", GH.ChallengeMode:FormatGold(GatherHeroDB.challenges.challengeGoal))
    print("  Highest Value So Far:", GH.ChallengeMode:FormatGold(GatherHeroDB.challenges.challengeProgress))
  elseif GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
    print("  --- Timed Gather Challenge Data ---")
    local data = GatherHeroDB.challenges.timedGatherData
    if data then
      print("  Time Window:", data.timeWindow)
      print("  Total Duration:", data.totalDuration)
      print("  Required Gathers:", data.requiredGathers)
      print("  Gathers Completed:", data.gathersCompleted)
      print("  Next Gather Time:", data.nextGatherTime - GetTime())
      print("  End Time:", data.endTime - GetTime())
    else
      print("  No timed gather data available")
    end
  end
end

-- Add slash command to toggle debug mode and print debug info
SLASH_GHDEBUG1 = "/ghdebug"
SlashCmdList["GHDEBUG"] = function(msg)
  if msg == "on" then
    GH.debugMode = true
    print("|cFF00FF00Gather Hero:|r Debug mode enabled")
  elseif msg == "off" then
    GH.debugMode = false
    print("|cFF00FF00Gather Hero:|r Debug mode disabled")
  elseif msg == "state" then
    GH.Debug:PrintChallengeState()
  else
    print("|cFF00FF00Gather Hero Debug Commands:|r")
    print("  /ghdebug on - Enable debug mode")
    print("  /ghdebug off - Disable debug mode")
    print("  /ghdebug state - Print current challenge state")
  end
end
