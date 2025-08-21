-- GH_QuickLoot.lua
-- Fast auto-looting module for Gather Hero

local addonName, GH = ...

-- Create the QuickLoot module
GH.QuickLoot = {}
local QL = GH.QuickLoot

-- Configuration settings
QL.settings = {
  enabled = true,        -- Instant looting enabled by default
  autoConfirmBOP = true, -- Auto-confirm BoP items when solo
  debugMode = false,     -- Debug mode for troubleshooting
  smartLoot = true,      -- Only auto-loot gathering items
  suppressLootUI = true, -- Hide the loot UI for gathering nodes
  sessionOnly = true,    -- Only active during gathering sessions
}

-- Local variables for state tracking
local isLooting = false
local isHidden = true
local isAnyItemLocked = false
local internalFrame = nil
local lootedSlots = {}
local LOOT_SLOT_ITEM = Enum.LootSlotType.Item

-- Initialize saved variables
function QL:InitSettings()
  -- Initialize settings in DB if they don't exist
  if not GatherHeroDB then GatherHeroDB = {} end
  if not GatherHeroDB.quickLootSettings then
    GatherHeroDB.quickLootSettings = CopyTable(QL.settings)
  else
    -- Copy saved settings to our local table
    for k, v in pairs(GatherHeroDB.quickLootSettings) do
      QL.settings[k] = v
    end
  end
end

-- Save current settings to DB
function QL:SaveSettings()
  if not GatherHeroDB then GatherHeroDB = {} end
  GatherHeroDB.quickLootSettings = CopyTable(QL.settings)
end

-- Check if an item fits in bags
function QL:ItemFitsInBags(itemLink, itemQuantity)
  -- Get item info
  local itemFamily = C_Item.GetItemFamily(itemLink)
  local itemStackCount = select(8, C_Item.GetItemInfo(itemLink))

  -- Check if we have a partial stack we can add to
  local inventoryItemCount = C_Item.GetItemCount(itemLink)
  if inventoryItemCount > 0 and itemStackCount > 1 then
    if ((itemStackCount - (inventoryItemCount % itemStackCount)) >= itemQuantity) then
      return true
    end
  end

  -- Check if we have space in our bags
  for bagSlot = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
    local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagSlot)

    if freeSlots > 0 then
      -- If no special bag requirements or we match the bag family
      if not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0) then
        return true
      end
    end
  end

  return false
end

-- Process a single loot slot
function QL:LootSlot(slot)
  local itemLink = GetLootSlotLink(slot)
  local slotType = GetLootSlotType(slot)
  local lootQuantity, _, lootQuality, lootLocked, isQuestItem = select(3, GetLootSlotInfo(slot))

  -- Skip if locked or quest item (and not in classic)
  if lootLocked then
    isAnyItemLocked = true
    return false
  end

  -- If smart loot is enabled, only loot gathering items
  if QL.settings.smartLoot and slotType == LOOT_SLOT_ITEM and itemLink then
    local isGatheringItem = false

    -- Get item information
    local _, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID, itemSubClassID = GetItemInfo(itemLink)

    -- Use GH utility function if available, or our simple check
    if GH.IsGatheringItem then
      isGatheringItem = GH:IsGatheringItem(itemClassID, itemSubClassID, GetItemInfo(itemLink))
    else
      -- Simple fallback check for gathering items
      isGatheringItem = (
        (itemClassID == 7 and (itemSubClassID == 7 or itemSubClassID == 9 or itemSubClassID == 6)) or -- Mining, Herb, Skin
        (itemType == "Trade Goods") or
        (itemType == "Tradeskill" and itemSubType == "Cloth")
      )
    end

    if not isGatheringItem then
      -- Not a gathering item, so don't auto-loot
      return false
    end
  end

  -- Check if item can fit in bags before looting
  if slotType == LOOT_SLOT_ITEM and itemLink and not self:ItemFitsInBags(itemLink, lootQuantity) then
    -- Item doesn't fit in bags, so don't auto-loot
    return false
  end

  -- Auto-loot the item
  LootSlot(slot)
  lootedSlots[slot] = true

  -- Auto-confirm BoP items when solo if enabled
  if QL.settings.autoConfirmBOP and not IsInGroup() then
    ConfirmLootSlot(slot)
  end

  return true
end

-- Create our frame and initialize
function QL:Initialize()
  if internalFrame then return end

  -- Initialize settings
  QL:InitSettings()

  -- Create our internal frame for reparenting the loot frame
  internalFrame = CreateFrame("Frame", "GatherHeroQuickLootFrame", UIParent)
  internalFrame:SetToplevel(true)
  internalFrame:Hide()

  -- Register for loot events
  internalFrame:RegisterEvent("LOOT_READY")
  internalFrame:RegisterEvent("LOOT_OPENED")
  internalFrame:RegisterEvent("LOOT_CLOSED")
  internalFrame:RegisterEvent("LOOT_SLOT_CHANGED")
  internalFrame:RegisterEvent("UI_ERROR_MESSAGE")
  internalFrame:RegisterEvent("ADDON_LOADED")

  -- Set up event handler
  internalFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
      QL:InitSettings()
      QL:SetupHooks()
    end

    if not QL.settings.enabled and event ~= "ADDON_LOADED" then return end

    if event == "LOOT_READY" then
      QL:OnLootReady(...)
    elseif event == "LOOT_OPENED" then
      QL:OnLootReady(...) -- Use same handler for both events
    elseif event == "LOOT_CLOSED" then
      QL:OnLootClosed()
    elseif event == "LOOT_SLOT_CHANGED" then
      QL:OnLootSlotChanged(...)
    elseif event == "UI_ERROR_MESSAGE" then
      QL:OnErrorMessage(...)
    end
  end)
end

-- Set up required hooks for loot UI
function QL:SetupHooks()
  -- Only hook if not already done
  if LootFrame:IsEventRegistered("LOOT_OPENED") and not QL.hooked then
    -- For Dragonflight and later
    if LE_EXPANSION_LEVEL_CURRENT >= 9 then
      hooksecurefunc(LootFrame, "UpdateShownState", function(self)
        if self.isInEditMode then
          self:SetParent(UIParent)
        else
          self:SetParent(internalFrame)
        end
      end)
    end

    QL.hooked = true

    -- Reset state initially
    QL:ResetLootFrame()
  end
end

-- Handler for LOOT_READY event
function QL:OnLootReady(autoLoot)
  -- Don't process if already looting
  if isLooting then return end

  -- Check if we're in session-only mode and there's no active session
  if QL.settings.sessionOnly and GH.sessionState ~= "active" then
    -- If we're not in an active session but smart loot is disabled,
    -- don't intercept the looting at all (let default WoW handling work)
    return
  end

  isLooting = true
  isAnyItemLocked = false
  wipe(lootedSlots)

  -- Reset the loot frame
  QL:ResetLootFrame()

  local numItems = GetNumLootItems()
  if numItems == 0 then
    isLooting = false
    return
  end

  -- Play the fishing sound if fishing loot
  if IsFishingLoot() then
    PlaySound(SOUNDKIT.FISHING_REEL_IN, "Master")
  end

  -- Check if we should auto-loot based on Blizzard's settings
  local shouldAutoLoot = autoLoot
  if autoLoot == nil then
    shouldAutoLoot = GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
  end

  if shouldAutoLoot then
    -- Process all loot slots in reverse order (more efficient)
    for slot = numItems, 1, -1 do
      if self:LootSlot(slot) then
        numItems = numItems - 1
      end
    end

    -- If we still have items left, show the loot frame
    if numItems > 0 then
      QL:ShowLootFrame()
    end
  else
    -- If not auto-looting, just show the loot frame
    QL:ShowLootFrame()
  end
end

-- Handler for LOOT_SLOT_CHANGED event
function QL:OnLootSlotChanged(slot)
  -- If we're looting and the slot has been previously looted but still has an item
  if isLooting and lootedSlots[slot] and LootSlotHasItem(slot) then
    -- Try to loot it again
    self:LootSlot(slot)
  end
end

-- Handler for LOOT_CLOSED event
function QL:OnLootClosed()
  isLooting = false
  isHidden = true
  isAnyItemLocked = false
  wipe(lootedSlots)

  -- Reset the loot frame
  QL:ResetLootFrame()
end

-- Handler for UI_ERROR_MESSAGE event
function QL:OnErrorMessage(category, message)
  -- Handle inventory full messages
  if tContains({ ERR_INV_FULL, ERR_ITEM_MAX_COUNT }, message) then
    if isLooting and isHidden then
      QL:ShowLootFrame(true)
    end

    -- Notify GH about inventory full if it supports that
    if isLooting and GH.PlayInventoryFullSound then
      GH:PlayInventoryFullSound()
    end
  end
end

-- Anchor the loot frame
function QL:AnchorLootFrame()
  local f = LootFrame
  if GetCVarBool("lootUnderMouse") then
    local x, y = GetCursorPosition()
    f:ClearAllPoints()

    -- Different anchoring based on expansion
    if LE_EXPANSION_LEVEL_CURRENT >= 9 then -- Dragonflight+
      x = x / (f:GetEffectiveScale()) - 30
      y = math.max((y / f:GetEffectiveScale()) + 50, 350)
      f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y)
    else
      x = x / f:GetEffectiveScale()
      y = y / f:GetEffectiveScale()
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 40, y + 20)
      f:GetCenter()
    end
    f:Raise()
  else
    if LE_EXPANSION_LEVEL_CURRENT >= 9 then -- Dragonflight+
      local scale = f:GetScale()
      f:SetPoint(f.systemInfo.anchorInfo.point, f.systemInfo.anchorInfo.relativeTo,
        f.systemInfo.anchorInfo.relativePoint,
        f.systemInfo.anchorInfo.offsetX / scale,
        f.systemInfo.anchorInfo.offsetY / scale)
    else
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -125)
    end
  end
end

-- Show the loot frame
function QL:ShowLootFrame(delayed)
  isHidden = false

  -- Handle different UI addons like ElvUI
  if LootFrame:IsEventRegistered("LOOT_OPENED") then
    LootFrame:SetParent(UIParent)
    LootFrame:SetFrameStrata("HIGH")
    self:AnchorLootFrame()
    if delayed then
      self:AnchorLootFrame()
    end
  end
end

-- Reset the loot frame state
function QL:ResetLootFrame()
  if LootFrame:IsEventRegistered("LOOT_OPENED") then
    LootFrame:SetParent(internalFrame)
  end
end

-- Toggle QuickLoot on/off
function QL:Toggle()
  QL.settings.enabled = not QL.settings.enabled
  QL:SaveSettings()
end

-- Add slash command handlers
local function ExtendSlashCommands()
  -- Add QuickLoot options to the existing /gh command
  local originalHandler = SlashCmdList["GATHERHERO"]
  SlashCmdList["GATHERHERO"] = function(msg)
    local cmd, arg = strsplit(" ", msg:lower(), 2)

    if cmd == "quickloot" or cmd == "ql" or cmd == "loot" then
      if arg == "on" or arg == "enable" then
        QL.settings.enabled = true
        QL:SaveSettings()
      elseif arg == "off" or arg == "disable" then
        QL.settings.enabled = false
        QL:SaveSettings()
      elseif arg == "toggle" then
        QL:Toggle()
      elseif arg == "session" or arg == "sessiononly" then
        QL.settings.sessionOnly = not QL.settings.sessionOnly
        QL:SaveSettings()
      elseif arg == "bop" or arg == "confirm" then
        QL.settings.autoConfirmBOP = not QL.settings.autoConfirmBOP
        QL:SaveSettings()
      elseif arg == "smart" then
        QL.settings.smartLoot = not QL.settings.smartLoot
        QL:SaveSettings()
      elseif arg == "ui" or arg == "hideui" then
        QL.settings.suppressLootUI = not QL.settings.suppressLootUI
        QL:SaveSettings()
      elseif arg == "status" or arg == nil or arg == "" then
        print("|cFF00FF00Gather Hero QuickLoot:|r Status")
        print("  Enabled: " .. (QL.settings.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("  Session Only: " .. (QL.settings.sessionOnly and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("  Auto-confirm BoP when solo: " .. (QL.settings.autoConfirmBOP and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("  Smart looting (only gathering): " .. (QL.settings.smartLoot and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        print("  Suppress loot UI: " .. (QL.settings.suppressLootUI and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
      else
        print("|cFF00FF00Gather Hero QuickLoot:|r Commands")
        print("  /gh quickloot on - Enable QuickLoot")
        print("  /gh quickloot off - Disable QuickLoot")
        print("  /gh quickloot toggle - Toggle QuickLoot on/off")
        print("  /gh quickloot session - Toggle session-only mode (only auto-loot during active sessions)")
        print("  /gh quickloot bop - Toggle auto-confirm BoP when solo")
        print("  /gh quickloot smart - Toggle smart looting (only gathering items)")
        print("  /gh quickloot ui - Toggle loot UI suppression")
        print("  /gh quickloot status - Show current settings")
      end
      return
    end

    -- Call the original handler for other commands
    originalHandler(msg)
  end
end

-- Initialize the module
C_Timer.After(0.1, function()
  QL:Initialize()
  ExtendSlashCommands()
end)
