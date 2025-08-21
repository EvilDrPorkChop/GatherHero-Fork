-- GatherHero.lua
-- Main file for the addon

local addonName, GH = ...
_G["GH"] = GH -- Expose to global scope for slash commands

-- Core variables
GH.sessionGold = 0
GH.timerActive = false
GH.sessionStartTime = nil

-- Session state variables
GH.sessionState = "idle" -- "idle", "active", "paused"
GH.currentSessionId = nil
GH.pauseStartTime = nil
GH.totalPausedTime = 0
GH.averageNodeValue = 0 -- Current average value per node
GH.soundsEnabled = true -- Toggle for sounds
GH.lastLootTime = nil   -- Time of the last loot (for node tracking)
GH.atMailbox = false    -- Flag to check if the player is at a mailbox
GH.fishingCapWarningShown = false
GH.fishingCapName = nil
GH.fishingCapBagID = nil
GH.fishingCapSlot = nil

-- Variables for floating text queue system
GH.floatingTextQueue = {}
GH.isProcessingQueue = false
GH.lastLootTimestamp = 0
GH.queuedGoldValue = 0
GH.LOOT_COMBINE_WINDOW = 0.2 -- Time window in seconds to combine loot notifications

-- Initialize saved variables
function GH:InitDB()
  -- Auto-save configuration
  if not GatherHeroDB.autoSave then
    GatherHeroDB.autoSave = {
      enabled = true,
      interval = 60, -- Auto-save every 60 seconds
      lastSave = 0
    }
  end
  -- Migration from old saved variables
  if not GatherHeroDB and GatheringGoldTrackerDB then
    GatherHeroDB = CopyTable(GatheringGoldTrackerDB)
  end

  -- Create the main DB table if it doesn't exist
  if not GatherHeroDB then
    GatherHeroDB = {}
  end

  -- Initialize UI position settings
  if not GatherHeroDB.position then
    GatherHeroDB.position = { x = 200, y = 200 }
  end

  -- Initialize UI display settings
  if not GatherHeroDB.displaySettings then
    GatherHeroDB.displaySettings = {
      showCounter = true,
      showFloatingText = true,
      combineLoots = true,
      showGoldPerHour = true,
      scale = 1.0,
      opacity = 0.8,
      -- New panel size and appearance settings
      width = 260,
      height = 160,
      backgroundColor = { r = 0, g = 0, b = 0 },
      borderColor = { r = 0.5, g = 0.5, b = 0.5 },
      showBorder = false
    }
  end

  -- Initialize gold tracking and statistics
  if not GatherHeroDB.goldTracking then
    GatherHeroDB.goldTracking = {
      bestGPH = 0,
      bestSessionGold = 0,
      todayTotal = 0,
      todayDate = date("%Y-%m-%d"),
      sessionHistory = {}
    }
  end

  -- Ensure all required fields exist in goldTracking
  if GatherHeroDB.goldTracking.bestGPH == nil then GatherHeroDB.goldTracking.bestGPH = 0 end
  if GatherHeroDB.goldTracking.bestSessionGold == nil then GatherHeroDB.goldTracking.bestSessionGold = 0 end
  if GatherHeroDB.goldTracking.todayTotal == nil then GatherHeroDB.goldTracking.todayTotal = 0 end
  if GatherHeroDB.goldTracking.sessionHistory == nil then GatherHeroDB.goldTracking.sessionHistory = {} end

  -- Check if today is a new day
  local today = date("%Y-%m-%d")
  if GatherHeroDB.goldTracking.todayDate ~= today then
    GatherHeroDB.goldTracking.todayTotal = 0
    GatherHeroDB.goldTracking.todayDate = today
  end

  -- Initialize Phial settings
  if not GatherHeroDB.phialSettings then
    GatherHeroDB.phialSettings = {
      checkPhial = true,
      showWarning = true,
      checkFishingCap = true
    }
  end

  -- Initialize new gathering buff settings
  if not GatherHeroDB.gatheringBuffs then
    GatherHeroDB.gatheringBuffs = {
      checkFirewater = true,      -- Check for Darkmoon Firewater
      showFirewaterWarning = true -- Show warning if Firewater is missing
    }
  end

  -- TSM price source settings
  if not GatherHeroDB.priceSource then
    GatherHeroDB.priceSource = "DBMarket"
  end

  if not GatherHeroDB.sessionSettings then
    GatherHeroDB.sessionSettings = {
      autoStart = true,    -- Automatically start session on first gather
      confirmStop = true,  -- Confirm before stopping a session
      saveHistory = true,  -- Save session history
      trackAllLoot = false -- track all loot when manually started
    }
  end

  if not GatherHeroDB.soundSettings then
    GatherHeroDB.soundSettings = {
      enabled = true,
      volume = 1.0
    }
  end

  -- Set current sound settings
  self.soundsEnabled = GatherHeroDB.soundSettings.enabled

  -- Initialize buff tracking variables
  self.phialWarningShown = false
  self.fishingCapWarningShown = false
  self.fishingCapName = nil
  self.fishingCapBagID = nil
  self.fishingCapSlot = nil

  -- Initialize new buff tracking variables
  self.firewaterWarningShown = false
  self.firewaterActive = false

  -- Set random login messages
  local messages = {
    "|cFF00FF00Gather Hero:|r Welcome! The flowers are blooming, the rocks are trembling. Let's gather like true loot goblins!",
    "|cFF00FF00Gather Hero:|r Welcome back! The herbs missed you. The ores? Not so much.",
    "|cFF00FF00Gather Hero:|r Ah, the smell of fresh herbs and fear in a beast's eyes. Let's get to work!",
    "|cFF00FF00Gather Hero:|r Time to do what we do best—annoy fish and vandalize the local landscape!",
    "|cFF00FF00Gather Hero:|r Another fine day to skin things that probably needed their skin. Oh well!",
    "|cFF00FF00Gather Hero:|r Time to bravely walk into danger… for a flower. Truly, the real endgame.",
    "|cFF00FF00Gather Hero:|r Let's gather like there's a vendor somewhere who actually pays well for this stuff.",
    "|cFF00FF00Gather Hero:|r Remember: every flower you pick is one less for that druid over there. Let's goooo!",
    "|cFF00FF00Gather Hero:|r If it sparkles, it's fair game. If it moves… skin it. Nature is loot.",
    "|cFF00FF00Gather Hero:|r Greetings, gatherer! May your bags be spacious and your tools sharp.",
    "|cFF00FF00Gather Hero:|r Every rose has its thorn. But it also has vendor value, so snip snip.",
    "|cFF00FF00Gather Hero:|r We gather not because we must—but because there are nodes on the map.",
    "|cFF00FF00Gather Hero:|r Ah yes, nothing like the thrill of finding an herb, only to aggro 5 wolves and a bee and get dismounted.",
    "|cFF00FF00Gather Hero:|r Remember: If it sparkles, it's loot. If it runs, it's loot with legs.",
    "|cFF00FF00Gather Hero:|r Time to strip-mine a continent in the name of crafting a slightly better pair of gloves!",
    "|cFF00FF00Gather Hero:|r 'Looks like there's treasure nearby!'—and looks like I'm about to mute voice lines again. Let's gather before he starts yelling.",
    "|cFF00FF00Gather Hero:|r Some heroes fight dragons. We… harvest spinach. Glorious.",
    "|cFF00FF00Gather Hero:|r There's gold in them hills! And also… probably some bears. You'll be fine.",
    "|cFF00FF00Gather Hero:|r Back at it, herb-slinger! Let's make the ecosystem cry one node at a time.",
    "|cFF00FF00Gather Hero:|r The fish are biting. The rocks are not. Use this to your advantage.",
    "|cFF00FF00Gather Hero:|r The beasts are furry, the herbs are leafy, and we are *very* busy.",
    "|cFF00FF00Gather Hero:|r Let's go make the world a little more empty and our bags a lot more full!"
  }
  -- Pick one at random when the addon loads
  local index = math.random(1, #messages)
  print(messages[index])

  -- Initialize core variables
  self.sessionGold = 0
  self.nodeCount = 0
  self.timerActive = false
  self.sessionStartTime = nil
  self.sessionState = "idle"
  self.currentSessionId = nil
  self.pauseStartTime = nil
  self.totalPausedTime = 0

  -- Initialize variables for floating text queue system
  self.floatingTextQueue = {}
  self.isProcessingQueue = false
  self.lastLootTimestamp = 0
  self.queuedGoldValue = 0
  self.LOOT_COMBINE_WINDOW = 0.2 -- Time window in seconds to combine loot notifications
end

-- Print welcome message and initialize when all files are loaded
function GH:OnInitialize()
  -- Check if we've already initialized to prevent duplicate UI elements
  if self.initialized then
    return
  end

  self:InitDB()
  self:InitializeUI()
  self:InitTSM()
  self:InitializeMenu()
  self:RegisterMailEvents()
  self:AnalyzeAllSessions()


  -- Initialize Challenge Mode
  if self.ChallengeMode then
    self.ChallengeMode:OnInitialize()
  end

  -- Apply settings from the menu
  self:ApplySettings()

  -- Mark as initialized
  self.initialized = true
end

-- Function to start a new session
function GH:StartSession(autoStarted)
  -- Don't start a new session if one is already active
  if self.sessionState == "active" then
    return
  end

  -- If paused, resume instead
  if self.sessionState == "paused" then
    self:ResumeSession()
    return
  end

  -- Track whether this was auto-started
  self.autoStarted = autoStarted or false

  -- Generate a unique session ID
  self.currentSessionId = tostring(time()) .. "-" .. math.random(1000, 9999)

  -- Reset session data
  self.sessionGold = 0
  self.nodeCount = 0
  self.sessionStartTime = GetTime()
  self.timerActive = true
  self.totalPausedTime = 0
  self.pauseStartTime = nil
  self.phialWarningShown = false
  self.firewaterWarningShown = false -- Reset Firewater warning flag too

  -- Get current zone
  self.currentSessionZone = GetZoneText() or GetMinimapZoneText() or "Unknown"

  -- Check if warmode is enabled
  self.currentSessionWarmode = C_PvP.IsWarModeDesired() or false

  -- Reset session tracking variables for detailed breakdown
  self.sessionItems = {}
  self.sessionProfessionType = "Unknown"
  self.sessionZoneBreakdown = {}
  self.sessionZoneBreakdown[self.currentSessionZone] = 0

  -- Set session state
  self.sessionState = "active"

  -- Update display
  self:UpdateSessionButtons()
  self:UpdateCounter()
  self:UpdateTimer()

  -- Check buffs immediately on manual session start
  if not self.autoStarted and self:IsInKhazAlgarZone() then
    self:CheckPhialStatus()
    self:CheckFirewaterStatus()

    -- Show warnings if appropriate
    if not self.phialActive and GatherHeroDB.phialSettings.showWarning then
      self:ShowPhialWarning()
    end

    if not self.firewaterActive and GatherHeroDB.gatheringBuffs and
        GatherHeroDB.gatheringBuffs.showFirewaterWarning then
      self:ShowFirewaterWarning()
    end
  end
end

-- Function to pause the current session
function GH:PauseSession()
  -- Can only pause an active session
  if self.sessionState ~= "active" then
    return
  end

  -- Mark the pause start time
  self.pauseStartTime = GetTime()

  -- Update session state
  self.sessionState = "paused"

  -- Update display
  self:UpdateSessionButtons()
end

-- Function to resume a paused session
function GH:ResumeSession()
  -- Can only resume a paused session
  if self.sessionState ~= "paused" then
    return
  end

  -- Calculate and add to total paused time
  if self.pauseStartTime then
    self.totalPausedTime = self.totalPausedTime + (GetTime() - self.pauseStartTime)
    self.pauseStartTime = nil
  end

  -- Update session state
  self.sessionState = "active"

  -- Update display
  self:UpdateSessionButtons()
end

-- Function to stop the current session and save it to history
function GH:StopSession()
  -- Can only stop an active or paused session
  if self.sessionState == "idle" then
    return
  end

  -- Get final session duration
  local totalSessionTime = 0

  if self.sessionState == "paused" and self.pauseStartTime then
    -- If paused, add the current pause duration to totalPausedTime
    self.totalPausedTime = self.totalPausedTime + (GetTime() - self.pauseStartTime)
  end

  if self.sessionStartTime then
    totalSessionTime = GetTime() - self.sessionStartTime - self.totalPausedTime
  end

  -- Save session to history if it was more than 1 minute
  if totalSessionTime > 60 then
    -- Initialize item collection if it doesn't exist
    if not self.sessionItems then
      self.sessionItems = {}
    end

    -- Create session data with expanded information
    local sessionData = {
      id = self.currentSessionId,
      startTime = self.sessionStartTime,
      endTime = GetTime(),
      duration = totalSessionTime,
      gold = self.sessionGold,
      goldPerHour = (totalSessionTime > 0) and (self.sessionGold * 3600 / totalSessionTime) or 0,
      date = date("%Y-%m-%d %H:%M:%S"),
      character = UnitName("player") .. "-" .. GetRealmName(),
      nodeCount = self.nodeCount,
      zone = self.currentSessionZone,
      warmode = self.currentSessionWarmode,

      -- New detailed data fields
      items = self.sessionItems,                                -- Table of item data by itemID
      professionType = self.sessionProfessionType or "Unknown", -- "Herbalism", "Mining", "Skinning", etc.
      zoneBreakdown = self.sessionZoneBreakdown or {},          -- Track gold by zone if player moves during session
      timeSpent = totalSessionTime,
    }

    -- Reset session items for next session
    self.sessionItems = {}

    -- Initialize session history if needed
    if not GatherHeroDB.goldTracking.sessionHistory then
      GatherHeroDB.goldTracking.sessionHistory = {}
    end

    -- Insert at the beginning of the table (most recent first)
    table.insert(GatherHeroDB.goldTracking.sessionHistory, 1, sessionData)

    -- Keep only the last 50 sessions
    while #GatherHeroDB.goldTracking.sessionHistory > 50 do
      table.remove(GatherHeroDB.goldTracking.sessionHistory)
    end
  end

  -- Reset session data
  self.sessionGold = 0
  self.timerActive = false
  self.sessionStartTime = nil
  self.totalPausedTime = 0
  self.pauseStartTime = nil
  self.currentSessionId = nil
  self.phialWarningShown = false
  self.fishingCapWarningShown = false
  self.nodeCount = 0
  self.currentSessionZone = nil
  self.currentSessionWarmode = nil
  -- Delete auto-save
  GatherHeroDB.currentSessionBackup = nil

  -- Reset detailed session data
  self.sessionItems = {}
  self.sessionProfessionType = nil
  self.sessionZoneBreakdown = nil

  -- Update session state
  self.sessionState = "idle"

  -- Update display
  self:UpdateSessionButtons()
  self:UpdateCounter()
  self:UpdateTimer()
  if self.goldPerHourText then
    self.goldPerHourText:SetText("0|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t/hr")
  end
end

-- Update session status text
function GH:UpdateSessionStatusText()
  if not self.sessionStatusText then return end

  local statusText = ""
  if self.sessionState == "idle" then
    statusText = "|cFFCCCCCCIdle|r"
  elseif self.sessionState == "active" then
    -- Only show "All Loot" if we're in a manually started session with trackAllLoot enabled
    if GatherHeroDB.sessionSettings.trackAllLoot and not self.autoStarted then
      statusText = "|cFF00FF00Active (All Loot)|r"
    else
      statusText = "|cFF00FF00Active|r"
    end
  elseif self.sessionState == "paused" then
    statusText = "|cFFFFFF00Paused|r"
  end

  self.sessionStatusText:SetText("Status: " .. statusText)
end

-- Update the state of session control buttons
function GH:UpdateSessionButtons()
  -- Update status text
  self:UpdateSessionStatusText()

  -- Update button states based on session state
  if not self.startButton or not self.pauseButton or not self.stopButton then
    return
  end

  if self.sessionState == "idle" then
    -- In idle state, only Start is enabled
    self.startButton:Enable()
    self.pauseButton:Disable()
    self.stopButton:Disable()
  elseif self.sessionState == "active" then
    -- In active state, Pause and Stop are enabled, Start is disabled
    self.startButton:Disable()
    self.pauseButton:Enable()
    self.stopButton:Enable()
  elseif self.sessionState == "paused" then
    -- In paused state, Resume (Start) and Stop are enabled, Pause is disabled
    self.startButton:Enable()
    self.pauseButton:Disable()
    self.stopButton:Enable()

    -- Change Start button text to "Resume"
    self.startButton:SetText("Resume")
  end

  -- Adjust button text based on state
  if self.sessionState ~= "paused" then
    self.startButton:SetText("Start")
  end
end

-- Register mail events
function GH:RegisterMailEvents()
  -- Create a frame specifically for mail and interaction events
  local eventFrame = CreateFrame("Frame")

  -- Register for both old and new mail events to ensure compatibility
  eventFrame:RegisterEvent("MAIL_SHOW")
  eventFrame:RegisterEvent("MAIL_CLOSED") -- Keep for backward compatibility
  eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

  -- Set up the event handler
  eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "MAIL_SHOW" then
      GH.atMailbox = true
      if GH.debugMode then
        print("|cFF00FF00Gather Hero:|r Mailbox opened (MAIL_SHOW) - atMailbox set to TRUE")
      end
    elseif event == "MAIL_CLOSED" then
      GH.atMailbox = false
      if GH.debugMode then
        print("|cFF00FF00Gather Hero:|r Mailbox closed (MAIL_CLOSED) - atMailbox set to FALSE")
      end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
      -- Check if this is the mail frame
      local type = ...
      if type == 17 then -- Mailbox interaction type
        GH.atMailbox = true
        if GH.debugMode then
          print("|cFF00FF00Gather Hero:|r Mailbox opened (PLAYER_INTERACTION) - atMailbox set to TRUE")
        end
      end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
      -- Check if this is the mail frame
      local type = ...
      if type == 17 then -- Mailbox interaction type
        GH.atMailbox = false
        if GH.debugMode then
          print("|cFF00FF00Gather Hero:|r Mailbox closed (PLAYER_INTERACTION) - atMailbox set to FALSE")
        end
      end
    end
  end)

  -- Store the frame reference
  self.mailEventFrame = eventFrame

  -- Debug message
  if self.debugMode then
    print("|cFF00FF00Gather Hero:|r Mail events registered")
  end
end

-- Use this function to handle any frame closing that might be a mailbox
function GH:CheckForMailboxClose()
  -- Only run if we're currently at a mailbox
  if not self.atMailbox then
    return
  end

  -- Check if mail frame is actually visible
  if MailFrame and not MailFrame:IsVisible() then
    self.atMailbox = false
    if self.debugMode then
      print("|cFF00FF00Gather Hero:|r Mail frame no longer visible - atMailbox set to FALSE")
    end
  end
end

-- Register for all interaction events
function GH:RegisterForEvents()
  -- Create a frame for general events
  local eventFrame = CreateFrame("Frame")

  -- Register for UI events that might indicate a mailbox closing
  eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
  eventFrame:RegisterEvent("UI_INFO_MESSAGE")

  -- Set up a periodic check to handle edge cases
  eventFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Check every second instead of every frame to reduce overhead
    self.checkTimer = (self.checkTimer or 0) + elapsed
    if self.checkTimer >= 1 then
      GH:CheckForMailboxClose()
      self.checkTimer = 0
    end
  end)

  eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
      local type = ...
      if type == 17 then -- Mailbox interaction type
        GH.atMailbox = false
        if GH.debugMode then
          print("|cFF00FF00Gather Hero:|r Mailbox interaction ended - atMailbox set to FALSE")
        end
      end
    elseif event == "UI_INFO_MESSAGE" then
      -- Sometimes closing mail produces info messages, check if mail is still visible
      C_Timer.After(0.1, function() GH:CheckForMailboxClose() end)
    end
  end)

  -- Store the frame reference
  self.eventFrame = eventFrame

  -- Debug message
  if self.debugMode then
    print("|cFF00FF00Gather Hero:|r General events registered")
  end
end

-- Mail event handlers
function GH:OnMailShow()
  self.atMailbox = true
  -- Print debug message if debug mode is enabled
  if self.debugMode then
    print("|cFF00FF00Gather Hero:|r Mail opened - pausing tracking")
  end
end

function GH:OnMailClosed()
  self.atMailbox = false
  -- Print debug message if debug mode is enabled
  if self.debugMode then
    print("|cFF00FF00Gather Hero:|r Mail closed - resuming tracking")
  end
end

-- Play sound based on node value, with volume control
function GH:PlayNodeValueSound(nodeValue)
  -- If sounds are disabled or we don't have enough nodes for an average, return
  if not self.soundsEnabled or self.nodeCount <= 1 then
    return
  end

  -- Calculate current average excluding this node
  local previousTotal = self.sessionGold - nodeValue
  local previousNodes = self.nodeCount - 1

  -- If this is the first node, there's no previous average
  if previousNodes <= 0 then
    return
  end

  local avgPerNode = previousTotal / previousNodes

  -- Get the volume from settings
  local volume = 1.0
  if GatherHeroDB and GatherHeroDB.soundSettings then
    volume = GatherHeroDB.soundSettings.volume or 1.0
  end

  -- If value is way above average, show in chat
  local valueMultiple = nodeValue / avgPerNode

  -- Determine which sound to play based on how much above average this node is
  if valueMultiple >= 3 then
    -- Value is at least 3x the average - play anime-wow sound
    PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master", volume)
    print("|cFFFF00FFGather Hero:|r |cFFFF00FFWow!|r This node is worth " ..
      string.format("%.1f", valueMultiple) .. "x the average!")
  elseif valueMultiple >= 2 then
    -- Value is at least 2x the average - play cha-ching sound
    PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\cha-ching.ogg", "Master", volume)
    print("|cFF00FF00Gather hero:|r |cFFFFFF00Cha-ching!|r This node is worth " ..
      string.format("%.1f", valueMultiple) .. "x the average!")
  end
end

-- Process loot messages to detect gathered herbs and mined ore
function GH:ProcessLootMessage(msg)
  -- Skip processing if at the mailbox
  if self.atMailbox then
    self:DebugLoot("At mailbox, skipping loot processing")
    return
  end

  -- Extract item link using a more reliable pattern
  local itemLink = string.match(msg, "|Hitem:[^|]+|h%[[^%]]+%]|h")
  local count = string.match(msg, "x(%d+)") or "1"
  count = tonumber(count)
  if not itemLink then
    self:DebugLoot("No item link found with primary pattern, trying alternate")
    -- Try a different pattern that might work better with WoW 11.1.0
    local itemName = string.match(msg, "You receive loot: %[(.-)%]")
    if itemName then
      self:DebugLoot("Found item name: " .. itemName)
      -- Get item ID by name if possible
      local itemFound = false
      for bagID = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
          local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
          if itemInfo and itemInfo.hyperlink then
            local thisItemName = GetItemInfo(itemInfo.hyperlink)
            if thisItemName and thisItemName == itemName then
              itemLink = itemInfo.hyperlink
              itemFound = true
              self:DebugLoot("Found matching item in bags: " .. itemName)
              break
            end
          end
        end
        if itemFound then break end
      end

      if not itemFound then
        self:DebugLoot("Could not find item in bags: " .. itemName)
        return
      end
    else
      self:DebugLoot("No item found in loot message")
      return
    end
  else
    self:DebugLoot("Found item link: " .. itemLink)
  end

  -- Check if the item is an herb, ore, or other gathering item
  local itemName, _, itemRarity, itemLevel, _, itemType, itemSubType, _, _, _, _, itemClassID, itemSubClassID =
      GetItemInfo(itemLink)

  self:DebugLoot("Item info: " ..
    itemName .. " (Class: " .. (itemClassID or "nil") .. ", SubClass: " .. (itemSubClassID or "nil") .. ")")

  -- Check if this is a gathering item using our utility function
  local isGatheringItem = self:IsGatheringItem(itemClassID, itemSubClassID, itemName)
  print("Is gathering item?", isGatheringItem)

  self:DebugLoot("Is gathering item? " .. (isGatheringItem and "Yes" or "No"))
  self:DebugLoot("Session state: " .. (self.sessionState or "nil"))
  self:DebugLoot("Track all loot? " .. (GatherHeroDB.sessionSettings.trackAllLoot and "Yes" or "No"))

  -- IMPORTANT FIX: Check if we should track all loot
  if not isGatheringItem and self.sessionState == "active" and GatherHeroDB.sessionSettings.trackAllLoot then
    self:DebugLoot("Non-gathering item will be tracked due to all-loot mode")
    isGatheringItem = true
  end

  -- Only proceed if it's a gathering item or we're in all-loot mode
  if not isGatheringItem then
    self:DebugLoot("Item is not a gathering item and all-loot is not enabled, skipping")
    return
  end

  -- Detect profession type based on item
  local professionType = "Unknown"
  if itemClassID == 7 then
    if itemSubClassID == 9 then
      professionType = "Herbalism"
    elseif itemSubClassID == 7 then
      professionType = "Mining"
    elseif itemSubClassID == 6 then
      professionType = "Skinning"
    end
  end

  -- Define list of War Within fish for profession detection
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

  -- Check if it's a fish (either by item class/subclass or by name)
  local isFish = false
  -- Check by item class/subclass (consumable food)
  if itemClassID == 0 and itemSubClassID == 5 then
    -- Not all foods are fish, so check the name
    if itemName then
      local lowerName = string.lower(itemName)
      if string.find(lowerName, "fish") or
          string.find(lowerName, "trout") or
          string.find(lowerName, "bass") or
          string.find(lowerName, "shark") or
          string.find(lowerName, "perch") then
        isFish = true
      end
    end
  end

  -- Also check by name keywords if not already identified
  if not isFish and itemName then
    local lowerName = string.lower(itemName)
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
      isFish = true
    end

    -- Check against our specific fish list
    for _, fishName in ipairs(warWithinFish) do
      if itemName == fishName then
        isFish = true
        break
      end
    end
  end

  -- If it's a fish, set the profession type to Fishing
  if isFish then
    professionType = "Fishing"
  end

  -- If we're in track-all mode and profession is still unknown, set it to "Mixed Farming"
  if self.sessionState == "active" and GatherHeroDB.sessionSettings.trackAllLoot and professionType == "Unknown" then
    professionType = "Mixed Farming"
  end

  -- Set session profession type if not already set
  if not self.sessionProfessionType or self.sessionProfessionType == "Unknown" then
    self.sessionProfessionType = professionType
  end

  -- IMPORTANT: We only start a session AFTER confirming it's a gathering item
  -- If we're in idle state and auto-start is enabled, start a new session
  if self.sessionState == "idle" and GatherHeroDB.sessionSettings.autoStart then
    -- Ensure we're not at mailbox before starting
    if not self.atMailbox then
      if self.debugMode then
        print("|cFF00FF00Gather Hero:|r Auto-starting session for gathering item:", itemName)
      end
      self:StartSession(true) -- Pass true to indicate this was auto-started
    else
      if self.debugMode then
        print("|cFF00FF00Gather Hero:|r Not starting session - at mailbox")
      end
    end
    -- If we're paused, don't track loot
  elseif self.sessionState == "paused" then
    return
    -- If we're not in active state and auto-start is disabled, ignore loot
  elseif self.sessionState ~= "active" then
    return
  end

  -- Check for Phial when looting - pass item info to check function
  self:CheckPhialWhenLooting(itemClassID, itemSubClassID, itemName)

  -- Track if this is part of the same node
  local isNewNode = true

  -- Check if this loot message is from the same node as the last one
  -- by comparing timestamps and using a small window (1 second)
  local currentTime = GetTime()
  if self.lastLootTime and (currentTime - self.lastLootTime) < 1.0 then
    isNewNode = false
  end

  -- Store the current loot time for future comparisons
  self.lastLootTime = currentTime

  -- Get market value using our utility function
  local totalValue = self:GetMarketValue(itemLink, count)

  -- Initialize session items if not exists
  if not self.sessionItems then
    self.sessionItems = {}
  end

  -- Store item data
  if not self.sessionItems[itemLink] then
    self.sessionItems[itemLink] = {
      name = itemName,
      count = 0,
      value = 0,
      unitValue = 0,
      itemID = GetItemInfoInstant(itemLink),
      quality = itemRarity,
      itemLevel = itemLevel,
      type = professionType
    }
  end

  -- Update item count and value
  self.sessionItems[itemLink].count = self.sessionItems[itemLink].count + count
  self.sessionItems[itemLink].value = self.sessionItems[itemLink].value + totalValue
  self.sessionItems[itemLink].unitValue = totalValue / count

  -- Track zone breakdown
  local currentZone = GetZoneText() or GetMinimapZoneText() or "Unknown"
  if not self.sessionZoneBreakdown then
    self.sessionZoneBreakdown = {}
  end
  if not self.sessionZoneBreakdown[currentZone] then
    self.sessionZoneBreakdown[currentZone] = 0
  end
  self.sessionZoneBreakdown[currentZone] = self.sessionZoneBreakdown[currentZone] + totalValue

  if totalValue > 0 then
    -- Add to session total
    self.sessionGold = self.sessionGold + totalValue

    -- Ensure nodeCount exists
    if not self.nodeCount then self.nodeCount = 0 end

    -- Increment node count only if this is a new node, not a continuation
    if isNewNode then
      self.nodeCount = self.nodeCount + 1

      -- Check if this node value is special and play appropriate sound
      self:PlayNodeValueSound(totalValue)
    end

    -- Update the counter display
    self:UpdateCounter()

    -- Show the floating text
    self:ShowFloatingGold(totalValue)

    -- Make sure the node value gets processed by the challenge system
    if self.ChallengeMode and self.ChallengeMode.CheckNodeValue then
      -- Create a temporary table to store loot from this node if it doesn't exist
      if isNewNode then
        if not self.currentNodeLoot then
          self.currentNodeLoot = {
            totalValue = 0,
            professionType = professionType,
            items = {}
          }
        end
      end

      -- Add this item to the current node's loot
      if self.currentNodeLoot then
        self.currentNodeLoot.totalValue = self.currentNodeLoot.totalValue + totalValue
        -- Store the item
        table.insert(self.currentNodeLoot.items, {
          link = itemLink,
          name = itemName,
          count = count,
          value = totalValue
        })

        -- If this is a new node, reset the collection after a short delay
        -- This allows multiple items from the same node to be batched together
        if isNewNode then
          -- Cancel any existing timers
          if self.nodeResetTimer then
            self.nodeResetTimer:Cancel()
            self.nodeResetTimer = nil
          end

          -- Set up a new timer to process the full node after all items are looted
          self.nodeResetTimer = C_Timer.NewTimer(0.5, function()
            -- Process the whole node value if we have accumulated items
            if self.currentNodeLoot and self.currentNodeLoot.totalValue > 0 then
              -- Process the complete node for challenge tracking
              if self.ChallengeMode and self.ChallengeMode.ProcessCompleteNode then
                self.ChallengeMode:ProcessCompleteNode(
                  self.currentNodeLoot.totalValue,
                  self.currentNodeLoot.professionType,
                  #self.currentNodeLoot.items
                )
              end

              -- Reset for next node
              self.currentNodeLoot = nil
            end

            self.nodeResetTimer = nil
          end)
        end
      end

      -- Also check this individual item (some valuable items might be worth checking on their own)
      self.ChallengeMode:CheckNodeValue(totalValue, professionType)
    end
  end
  -- If we have an active session, update the profession analysis
  if self.sessionState == "active" and self.currentSessionId then
    -- Create a temporary session object with the current data
    local currentSession = {
      items = self.sessionItems,
      gold = self.sessionGold,
      nodeCount = self.nodeCount
    }

    -- Analyze professions and update the session profession type
    local dominantProfession = self:AnalyzeSessionProfessions(currentSession)
    self.sessionProfessionType = dominantProfession
  end
end

-- Function to analyze all existing sessions
function GH:AnalyzeAllSessions()
  if not GatherHeroDB or not GatherHeroDB.goldTracking or not GatherHeroDB.goldTracking.sessionHistory then
    return
  end

  local count = 0
  for i, session in ipairs(GatherHeroDB.goldTracking.sessionHistory) do
    if session and session.items and next(session.items) then
      self:AnalyzeSessionProfessions(session)
      count = count + 1
    end
  end
end

-- Add auto-save function
function GH:AutoSaveSession()
  -- Skip if auto-save is disabled or no active session
  if not GatherHeroDB.autoSave.enabled or self.sessionState ~= "active" then
    return
  end

  -- Skip if we recently saved
  local currentTime = GetTime()
  if (currentTime - (GatherHeroDB.autoSave.lastSave or 0)) < GatherHeroDB.autoSave.interval then
    return
  end

  -- Create temporary session data (similar to what's in StopSession)
  local totalSessionTime = 0

  if self.sessionStartTime then
    totalSessionTime = currentTime - self.sessionStartTime - self.totalPausedTime
  end

  -- Only save if the session is longer than a minimum time (e.g., 30 seconds)
  if totalSessionTime < 30 then
    return
  end

  -- Initialize item collection if it doesn't exist
  if not self.sessionItems then
    self.sessionItems = {}
  end

  -- Create a backup of the current session
  local sessionBackup = {
    id = self.currentSessionId,
    startTime = self.sessionStartTime,
    lastSaveTime = currentTime,
    duration = totalSessionTime,
    gold = self.sessionGold,
    goldPerHour = (totalSessionTime > 0) and (self.sessionGold * 3600 / totalSessionTime) or 0,
    date = date("%Y-%m-%d %H:%M:%S"),
    character = UnitName("player") .. "-" .. GetRealmName(),
    nodeCount = self.nodeCount,
    zone = self.currentSessionZone,
    warmode = self.currentSessionWarmode,

    -- Detailed data fields
    items = self:DeepCopyTable(self.sessionItems),
    professionType = self.sessionProfessionType or "Unknown",
    zoneBreakdown = self:DeepCopyTable(self.sessionZoneBreakdown or {}),
    timeSpent = totalSessionTime,

    -- Flag as an auto-saved session
    isAutoSaved = true
  }

  -- Store the backup in the saved variables
  GatherHeroDB.currentSessionBackup = sessionBackup
  GatherHeroDB.autoSave.lastSave = currentTime

  if self.debugMode then
    print("|cFF00FF00Gather Hero:|r Session auto-saved")
  end
end

-- Helper function to create deep copies of tables
function GH:DeepCopyTable(orig)
  if type(orig) ~= "table" then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    if type(v) == "table" then
      copy[k] = self:DeepCopyTable(v)
    else
      copy[k] = v
    end
  end
  return copy
end

-- Recovery function to load a crashed session
function GH:CheckForCrashedSession()
  -- Check if there's a backed-up session
  if not GatherHeroDB.currentSessionBackup then
    return
  end

  -- Confirm the backed-up session is for this character
  local currentCharacter = UnitName("player") .. "-" .. GetRealmName()
  if GatherHeroDB.currentSessionBackup.character ~= currentCharacter then
    return
  end

  -- Ask the user if they want to recover
  StaticPopupDialogs["GH_RECOVER_SESSION"] = {
    text = "Gather Hero detected an unsaved gathering session. Would you like to recover it?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
      GH:RecoverSession(GatherHeroDB.currentSessionBackup)
    end,
    OnCancel = function()
      -- Clear the backed-up session
      GatherHeroDB.currentSessionBackup = nil
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  -- Show the dialog
  StaticPopup_Show("GH_RECOVER_SESSION")
end

-- Function to recover a crashed session
function GH:RecoverSession(sessionBackup)
  if not sessionBackup then return end

  -- Check if we're already in a session
  if self.sessionState ~= "idle" then
    print("|cFFFF0000Gather Hero:|r Cannot recover session - already in an active session.")
    return
  end

  -- Add the session to history
  if GatherHeroDB.sessionSettings.saveHistory then
    -- Initialize session history if needed
    if not GatherHeroDB.goldTracking.sessionHistory then
      GatherHeroDB.goldTracking.sessionHistory = {}
    end

    -- Insert at the beginning of the table (most recent first)
    table.insert(GatherHeroDB.goldTracking.sessionHistory, 1, sessionBackup)

    -- Keep only the last 50 sessions
    while #GatherHeroDB.goldTracking.sessionHistory > 50 do
      table.remove(GatherHeroDB.goldTracking.sessionHistory)
    end

    -- Update tracking data
    -- Add to today's total
    local today = date("%Y-%m-%d")
    if GatherHeroDB.goldTracking.todayDate ~= today then
      GatherHeroDB.goldTracking.todayTotal = 0
      GatherHeroDB.goldTracking.todayDate = today
    end

    -- Add to today's total
    GatherHeroDB.goldTracking.todayTotal = GatherHeroDB.goldTracking.todayTotal + (sessionBackup.gold or 0)

    -- Update best session if applicable
    if (sessionBackup.gold or 0) > (GatherHeroDB.goldTracking.bestSessionGold or 0) then
      GatherHeroDB.goldTracking.bestSessionGold = sessionBackup.gold
    end

    -- Update best GPH if applicable
    if (sessionBackup.goldPerHour or 0) > (GatherHeroDB.goldTracking.bestGPH or 0) then
      GatherHeroDB.goldTracking.bestGPH = sessionBackup.goldPerHour
    end

    print("|cFF00FF00Gather Hero:|r Recovered session has been saved to history.")
  end

  -- Clear the backed-up session
  GatherHeroDB.currentSessionBackup = nil
end

function GH:LoadBackupSession(sessionBackup)
  if not sessionBackup then
    print("|cFFFF0000Gather Hero:|r No backup session to load.")
    return
  end

  -- If we have an active session, stop it first
  if self.sessionState ~= "idle" then
    self:StopSession()
  end

  -- Now restore the backed-up session state
  self.sessionState = "active"
  self.sessionStartTime = GetTime() - (sessionBackup.duration or 0)
  self.sessionGold = sessionBackup.gold or 0
  self.nodeCount = sessionBackup.nodeCount or 0
  self.timerActive = true
  self.totalPausedTime = 0
  self.pauseStartTime = nil
  self.currentSessionId = sessionBackup.id or tostring(time()) .. "-" .. math.random(1000, 9999)
  self.currentSessionZone = sessionBackup.zone or GetZoneText() or "Unknown"
  self.currentSessionWarmode = sessionBackup.warmode or false

  -- Restore detailed session data
  self.sessionItems = GH:DeepCopyTable(sessionBackup.items or {})
  self.sessionProfessionType = sessionBackup.professionType or "Unknown"
  self.sessionZoneBreakdown = GH:DeepCopyTable(sessionBackup.zoneBreakdown or {})

  -- Reset warning flags
  self.phialWarningShown = false
  self.firewaterWarningShown = false

  -- Update UI
  self:UpdateSessionButtons()
  self:UpdateCounter()
  self:UpdateTimer()

  print("|cFF00FF00Gather Hero:|r Loaded auto-saved session from " .. (sessionBackup.date or "unknown date"))

  -- Note: We don't clear the backup here so it can be loaded again if needed
end

-- slash commands for testing and controls
SLASH_GATHERHERO1 = "/gh"
SLASH_GATHERHERO2 = "/gatherhero"
SlashCmdList["GATHERHERO"] = function(msg)
  local cmd, arg = strsplit(" ", msg:lower(), 2)

  if cmd == "config" or cmd == "options" then
    GH:OpenSettings()
  elseif cmd == "show" then
    if GH.counterFrame then
      GH.counterFrame:Show()
    else
      GH:InitializeUI()
    end
  elseif cmd == "hide" then
    if GH.counterFrame then
      GH.counterFrame:Hide()
    end
  else
    print("|cFF00FF00Gather Hero:|r Commands:")
    print("  /gh config - Open the configuration panel")
    print("  /gh show - Show the counter")
    print("  /gh hide - Hide the counter")
  end
end

SLASH_GHMAILBOX1 = "/ghmailbox"
SlashCmdList["GHMAILBOX"] = function()
  print("|cFF00FF00Gather Hero:|r Mailbox state:", GH.atMailbox)
  print("|cFF00FF00Gather Hero:|r Session state:", GH.sessionState)
  print("|cFF00FF00Gather Hero:|r Auto-start setting:", GatherHeroDB.sessionSettings.autoStart)
end
function GH:DebugLoot(message)
  if self.lootDebug then
    print("|cFFFF9900Gather Hero Debug:|r " .. message)
  end
end

-- Add this slash command to easily toggle loot debugging
SLASH_GHLOOTDEBUG1 = "/ghlootdebug"
SlashCmdList["GHLOOTDEBUG"] = function(msg)
  if msg == "on" then
    GH.lootDebug = true
    print("|cFFFF9900Gather Hero:|r Loot debugging enabled")
  elseif msg == "off" then
    GH.lootDebug = false
    print("|cFFFF9900Gather Hero:|r Loot debugging disabled")
  else
    print("|cFFFF9900Gather Hero:|r Loot debug commands:")
    print("  /ghlootdebug on - Enable loot debugging")
    print("  /ghlootdebug off - Disable loot debugging")
  end
end
