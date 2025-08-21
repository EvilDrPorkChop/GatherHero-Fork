-- GH_UI.lua
-- UI components for GatherHero

local _, GH = ...

-- Create the UI elements with improved layout and top buttons
function GH:InitializeUI()
  -- Get panel dimensions from saved settings or use defaults
  local panelWidth = 200
  local panelHeight = 140 -- Increased height to accommodate node text

  if GatherHeroDB and GatherHeroDB.displaySettings then
    panelWidth = GatherHeroDB.displaySettings.width or panelWidth
    panelHeight = GatherHeroDB.displaySettings.height or panelHeight
  end

  -- Create main counter frame
  self.counterFrame = CreateFrame("Frame", "GatherHeroFrame", UIParent, "BackdropTemplate")
  self.counterFrame:SetSize(panelWidth, panelHeight)

  -- Set position from saved variables if available
  if GatherHeroDB and GatherHeroDB.position then
    self.counterFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
      GatherHeroDB.position.x,
      GatherHeroDB.position.y)
  else
    -- Default position if no saved position
    self.counterFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  end

  self.counterFrame:SetMovable(true)
  self.counterFrame:EnableMouse(true)
  self.counterFrame:SetClampedToScreen(true)
  self.counterFrame:RegisterForDrag("LeftButton")
  self.counterFrame:SetFrameStrata("MEDIUM")

  -- Apply saved scale if available
  if GatherHeroDB and GatherHeroDB.displaySettings and
      GatherHeroDB.displaySettings.scale then
    self.counterFrame:SetScale(GatherHeroDB.displaySettings.scale)
  end

  -- Set visibility based on saved settings
  if GatherHeroDB and GatherHeroDB.displaySettings and
      GatherHeroDB.displaySettings.showCounter == false then
    self.counterFrame:Hide()
  else
    self.counterFrame:Show()
  end

  -- Get colors from settings or use defaults
  local bgColor = { r = 0, g = 0, b = 0, a = 0.8 }
  local borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
  local showBorder = true

  if GatherHeroDB and GatherHeroDB.displaySettings then
    -- Set opacity
    if GatherHeroDB.displaySettings.opacity then
      bgColor.a = GatherHeroDB.displaySettings.opacity
    end

    -- Set background color if defined
    if GatherHeroDB.displaySettings.backgroundColor then
      bgColor.r = GatherHeroDB.displaySettings.backgroundColor.r
      bgColor.g = GatherHeroDB.displaySettings.backgroundColor.g
      bgColor.b = GatherHeroDB.displaySettings.backgroundColor.b
    end

    -- Set border color if defined
    if GatherHeroDB.displaySettings.borderColor then
      borderColor.r = GatherHeroDB.displaySettings.borderColor.r
      borderColor.g = GatherHeroDB.displaySettings.borderColor.g
      borderColor.b = GatherHeroDB.displaySettings.borderColor.b
    end

    -- Check if border should be shown
    if GatherHeroDB.displaySettings.showBorder ~= nil then
      showBorder = GatherHeroDB.displaySettings.showBorder
    end
  end

  -- Add background color and border
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
    -- Fallback for 11.1.0 if SetBackdrop isn't available
    local bg = self.counterFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    self.counterFrame.background = bg -- Store reference for later updates

    -- Only create border if it should be shown
    if showBorder then
      local border = CreateFrame("Frame", nil, self.counterFrame, "BackdropTemplate")
      border:SetAllPoints()
      border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
      border:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
      self.counterFrame.border = border -- Store reference for later updates
    end
  end

  -- Create top buttons - Close (X) button and Settings button
  -- Close button
  local closeButton = CreateFrame("Button", nil, self.counterFrame)
  closeButton:SetSize(16, 16)
  closeButton:SetPoint("TOPRIGHT", self.counterFrame, "TOPRIGHT", -8, -8)
  closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
  closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")

  closeButton:SetScript("OnClick", function()
    self.counterFrame:Hide()
    if GatherHeroDB and GatherHeroDB.displaySettings then
      GatherHeroDB.displaySettings.showCounter = false
    end
  end)

  closeButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Close")
    GameTooltip:Show()
  end)

  closeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Settings button
  local settingsButton = CreateFrame("Button", nil, self.counterFrame)
  settingsButton:SetSize(16, 16)
  settingsButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -4, 0)
  settingsButton:SetNormalTexture("Interface\\GossipFrame\\HealerGossipIcon")
  settingsButton:SetHighlightTexture("Interface\\GossipFrame\\HealerGossipIcon", "ADD")

  settingsButton:SetScript("OnClick", function()
    -- Use the simplified OpenSettings function
    self:OpenSettings()
  end)

  settingsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Settings")
    GameTooltip:Show()
  end)

  settingsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- History button
  local historyButton = CreateFrame("Button", nil, self.counterFrame)
  historyButton:SetSize(16, 16)
  historyButton:SetPoint("TOPLEFT", self.counterFrame, "TOPLEFT", 8, -8)
  historyButton:SetNormalTexture("Interface\\FriendsFrame\\UI-FriendsList-Small-Up")
  historyButton:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsList-Small-Up", "ADD")

  historyButton:SetScript("OnClick", function()
    -- Display session history window
    self:ShowHistoryWindow()
  end)

  historyButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Session History")
    GameTooltip:Show()
  end)

  historyButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  -- Create title text (adjusted to leave space for buttons)
  local title = self.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -8)
  title:SetText("Gather Hero")

  -- Create timer text (just below title with good spacing)
  self.timerText = self.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.timerText:SetPoint("TOP", title, "BOTTOM", 0, -8)
  self.timerText:SetText("00:00:00")

  -- Create gold counter text (below timer with good spacing)
  self.goldText = self.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.goldText:SetPoint("TOP", self.timerText, "BOTTOM", 0, -8)
  self.goldText:SetText(
    "Session: 0|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t 0|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t 0|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t")

  -- Initialize the counters table once
  self.counters = self.counters or {}

  -- Create node counter text (below gold text)
  self.nodeText = self.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.nodeText:SetPoint("TOP", self.goldText, "BOTTOM", 0, -4)
  self.nodeText:SetText("Nodes: 0 (0g/node)")
  -- Store the node text reference
  self.counters.nodeText = self.nodeText

  -- Create gold per hour text (below node text)
  self.goldPerHourText = self.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.goldPerHourText:SetPoint("TOP", self.nodeText, "BOTTOM", 0, -4)
  self.goldPerHourText:SetText("0|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t/hr")
  -- Store the gold per hour text reference
  self.counters.goldPerHourText = self.goldPerHourText

  -- Only hide gold per hour if explicitly disabled in settings
  if GatherHeroDB and GatherHeroDB.displaySettings and
      GatherHeroDB.displaySettings.showGoldPerHour == false then
    self.goldPerHourText:Hide()
  else
    self.goldPerHourText:Show()
  end

  -- Create session status text AFTER the gold per hour text
  self.sessionStatusText = self.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  self.sessionStatusText:SetPoint("TOP", self.goldPerHourText, "BOTTOM", 0, -4)
  self.sessionStatusText:SetText("Status: |cFFCCCCCCIdle|r")
  self.counters.sessionStatusText = self.sessionStatusText

  -- Create a container frame for the buttons
  local buttonContainerHeight = 24
  local buttonContainerWidth = panelWidth - 20 -- Margins on both sides
  local buttonContainerHorizontalOffset = 10

  local buttonContainer = CreateFrame("Frame", nil, self.counterFrame)
  buttonContainer:SetSize(buttonContainerWidth, buttonContainerHeight)
  buttonContainer:SetPoint("BOTTOM", self.counterFrame, "BOTTOM", 0, 10)

  -- Calculate individual button dimensions
  local buttonCount = 3
  local buttonSpacing = 5
  local buttonWidth = (buttonContainerWidth - (buttonSpacing * (buttonCount - 1))) / buttonCount
  local buttonHeight = buttonContainerHeight

  -- Create Start button
  self.startButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
  self.startButton:SetSize(buttonWidth, buttonHeight)
  self.startButton:SetPoint("LEFT", buttonContainer, "LEFT", 0, 0)
  self.startButton:SetText("Start")
  self.startButton:SetScript("OnClick", function() self:StartSession() end)

  -- Create Pause button
  self.pauseButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
  self.pauseButton:SetSize(buttonWidth, buttonHeight)
  self.pauseButton:SetPoint("LEFT", self.startButton, "RIGHT", buttonSpacing, 0)
  self.pauseButton:SetText("Pause")
  self.pauseButton:SetScript("OnClick", function() self:PauseSession() end)
  self.pauseButton:Disable() -- Disabled by default

  -- Create Stop button
  self.stopButton = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
  self.stopButton:SetSize(buttonWidth, buttonHeight)
  self.stopButton:SetPoint("LEFT", self.pauseButton, "RIGHT", buttonSpacing, 0)
  self.stopButton:SetText("Stop")
  self.stopButton:SetScript("OnClick", function()
    if GatherHeroDB.sessionSettings.confirmStop and self.sessionGold > 0 then
      StaticPopupDialogs["GH_CONFIRM_STOP_SESSION"] = {
        text = "Stop the current gathering session?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() self:StopSession() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      StaticPopup_Show("GH_CONFIRM_STOP_SESSION")
    else
      self:StopSession()
    end
  end)
  self.stopButton:Disable() -- Disabled by default

  -- Update button states based on initial session state
  self:UpdateSessionButtons()

  -- Initialize timer variables but don't start counting yet
  self.timerUpdateFrame = CreateFrame("Frame")
  self.timerUpdateFrame:SetScript("OnUpdate", function(_, elapsed)
    if GH.timerActive then
      GH:UpdateTimer()
    end
  end)

  -- Set up tooltip functionality
  self.counterFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Gather Hero")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Drag: Move frame", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Commands:")
    GameTooltip:AddLine("/gh config - Open the configuration panel", 1, 1, 1)
    GameTooltip:AddLine("/gh show - Show the counter", 1, 1, 1)
    GameTooltip:AddLine("/gh hide - Hide the counter", 1, 1, 1)
    GameTooltip:Show()
  end)

  self.counterFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Set up drag functionality with position saving
  self.counterFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
    GameTooltip:Hide() -- Hide tooltip when dragging
  end)

  self.counterFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    -- Save position to saved variables
    local x, y = self:GetLeft(), self:GetTop()
    GatherHeroDB.position = { x = x, y = y }
  end)

  -- Initial update
  self:UpdateCounter()
  self:UpdateTimer()
end

-- Update the counter display
function GH:UpdateCounter()
  if not self.goldText then return end

  -- Use our utility function to format money
  local formattedMoney = self:FormatMoney(self.sessionGold)

  -- Update the main gold text
  self.goldText:SetText("Session: " .. formattedMoney)

  -- Calculate gold per node for the node text
  local goldPerNodeText = "0g"
  if self.nodeCount and self.nodeCount > 0 then
    local goldPerNode = self.sessionGold / self.nodeCount
    local goldPerNodeValue = math.floor(goldPerNode / 100) / 100 -- Round to 2 decimal places
    goldPerNodeText = goldPerNodeValue .. "g"
  end

  -- Create or update the node text element
  if not self.nodeText then
    self.nodeText = self.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.nodeText:SetPoint("TOP", self.goldText, "BOTTOM", 0, -4)
    -- Store reference to prevent garbage collection
    self.counters = self.counters or {}
    self.counters.nodeText = self.nodeText
  end

  -- Update the node text display (on a separate line)
  self.nodeText:SetText("Nodes: " .. (self.nodeCount or 0) .. " (" .. goldPerNodeText .. "/node)")

  -- Reposition the gold per hour text to be below the node text
  if self.goldPerHourText then
    self.goldPerHourText:ClearAllPoints()
    self.goldPerHourText:SetPoint("TOP", self.nodeText, "BOTTOM", 0, -4)
  end

  -- Reposition the session status text if it exists
  if self.sessionStatusText then
    self.sessionStatusText:ClearAllPoints()
    self.sessionStatusText:SetPoint("TOP", self.goldPerHourText, "BOTTOM", 0, -4)
  end

  -- Ensure goldTracking exists before comparing
  if not GatherHeroDB.goldTracking then
    GatherHeroDB.goldTracking = {
      bestSessionGold = 0,
      bestGPH = 0,
      todayTotal = 0,
      todayDate = date("%Y-%m-%d"),
      sessionHistory = {}
    }
  end

  -- Save current session gold to track best sessions
  if self.sessionGold > (GatherHeroDB.goldTracking.bestSessionGold or 0) then
    GatherHeroDB.goldTracking.bestSessionGold = self.sessionGold
  end

  -- Update today's total (handle nil case)
  if not GatherHeroDB.goldTracking.todayTotal then
    GatherHeroDB.goldTracking.todayTotal = 0
  end
  GatherHeroDB.goldTracking.todayTotal = GatherHeroDB.goldTracking.todayTotal + self.sessionGold
end

-- Update the session timer display
-- Override the UpdateTimer function to account for paused time
function GH:UpdateTimer()
  if not self.timerText then return end

  if not self.timerActive or not self.sessionStartTime then
    self.timerText:SetText("00:00:00")
    -- Make sure goldPerHourText exists before trying to use it
    if self.goldPerHourText then
      self.goldPerHourText:SetText("0|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t/hr")
    end
    return
  end

  local currentTime = GetTime()
  local pauseTime = self.totalPausedTime or 0

  -- If currently paused, add the current pause duration
  if self.sessionState == "paused" and self.pauseStartTime then
    pauseTime = pauseTime + (currentTime - self.pauseStartTime)
  end

  local sessionTime = currentTime - self.sessionStartTime - pauseTime

  -- Format time
  self.timerText:SetText(self:FormatTime(sessionTime))

  -- Calculate and update gold per hour (only if session is active and time is sufficient)
  if self.sessionState == "active" and sessionTime > 30 then
    -- Only update display every 5 seconds to avoid flickering
    if math.floor(sessionTime) % 5 == 0 then
      local goldPerHour = self.sessionGold * (3600 / sessionTime)
      local gph_gold = math.floor(goldPerHour / 10000)

      -- Format gold per hour with gold icon (make sure it's showing the full gold amount)
      if self.goldPerHourText then
        self.goldPerHourText:SetText(string.format("%d|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t/hr", gph_gold))
      end

      -- Track best GPH
      if goldPerHour > GatherHeroDB.goldTracking.bestGPH then
        GatherHeroDB.goldTracking.bestGPH = goldPerHour
      end
    end
  end

  -- Auto-save functionality: Only run if we're in an active session
  if self.sessionState == "active" and sessionTime > 30 then
    -- Check if auto-save is enabled
    if GatherHeroDB.autoSave and GatherHeroDB.autoSave.enabled then
      -- Get the last auto-save time (default to 0 if not set)
      local lastSaveTime = GatherHeroDB.autoSave.lastSave or 0
      local saveInterval = GatherHeroDB.autoSave.interval or 60   -- Default to 60 seconds

      -- If it's time to auto-save (based on interval)
      if (currentTime - lastSaveTime) >= saveInterval then
        -- Create a backup of the current session
        local sessionBackup = {
          id = self.currentSessionId,
          startTime = self.sessionStartTime,
          lastSaveTime = currentTime,
          duration = sessionTime,
          gold = self.sessionGold,
          goldPerHour = (sessionTime > 0) and (self.sessionGold * 3600 / sessionTime) or 0,
          date = date("%Y-%m-%d %H:%M:%S"),
          character = UnitName("player") .. "-" .. GetRealmName(),
          nodeCount = self.nodeCount,
          zone = self.currentSessionZone,
          warmode = self.currentSessionWarmode,

          -- Detailed data fields
          items = self:DeepCopyTable(self.sessionItems or {}),
          professionType = self.sessionProfessionType or "Unknown",
          zoneBreakdown = self:DeepCopyTable(self.sessionZoneBreakdown or {}),
          timeSpent = sessionTime,

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
    end
  end
end

-- Show floating gold text over player's head - with queue system
function GH:ShowFloatingGold(value)
  -- Check if floating text is disabled in settings
  if GatherHeroDB and GatherHeroDB.displaySettings and
      not GatherHeroDB.displaySettings.showFloatingText then
    return
  end

  local currentTime = GetTime()

  -- If this loot happened within our combine window and combining is enabled, add it to the current queued value
  local shouldCombine = GatherHeroDB and GatherHeroDB.displaySettings and
      GatherHeroDB.displaySettings.combineLoots
  if shouldCombine and currentTime - self.lastLootTimestamp < self.LOOT_COMBINE_WINDOW then
    self.queuedGoldValue = self.queuedGoldValue + value
    self.lastLootTimestamp = currentTime

    -- If we're not already processing the queue, wait for more potential loot
    if not self.isProcessingQueue then
      self.isProcessingQueue = true
      C_Timer.After(self.LOOT_COMBINE_WINDOW, function() GH:ProcessFloatingTextQueue() end)
    end
    return
  end

  -- This is a new loot event outside the combine window
  self.queuedGoldValue = value
  self.lastLootTimestamp = currentTime

  -- Set timer to process the queue
  if not self.isProcessingQueue then
    self.isProcessingQueue = true
    C_Timer.After(self.LOOT_COMBINE_WINDOW, function() GH:ProcessFloatingTextQueue() end)
  end
end

-- Process the floating text queue
function GH:ProcessFloatingTextQueue()
  local value = self.queuedGoldValue
  self.queuedGoldValue = 0
  self.isProcessingQueue = false

  local gold = math.floor(value / 10000)
  local silver = math.floor((value % 10000) / 100)
  local copper = math.floor(value % 100)

  -- Format simplified text with just gold and gold icon
  local displayText
  if gold > 0 then
    displayText = string.format("+%d|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t", gold)
  elseif silver > 0 then
    -- Convert silver to a decimal gold value (e.g., 0.5g)
    displayText = string.format("+%.1f|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t", silver / 100)
  else
    -- For tiny amounts, at least show 0.1g
    displayText = string.format("+0.1|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t")
  end

  -- Create the floating text frame
  local floater = CreateFrame("Frame", nil, UIParent)
  floater:SetFrameStrata("HIGH")
  floater:SetSize(120, 40)

  -- Position above player in center of screen
  floater:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

  -- Create text
  local text = floater:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  text:SetPoint("CENTER")
  text:SetText(displayText)
  text:SetTextColor(1, 0.84, 0) -- Gold color

  -- Make it larger and add glow for visibility
  text:SetFont(text:GetFont(), 20, "THICKOUTLINE")

  -- Animation
  floater.elapsed = 0
  floater.fadeInTime = 0.3
  floater.holdTime = 1.5
  floater.fadeOutTime = 0.7
  floater.totalTime = floater.fadeInTime + floater.holdTime + floater.fadeOutTime

  floater:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed

    -- Calculate alpha and position
    local progress = self.elapsed / self.totalTime
    local yOffset = 100 + (progress * 40) -- Move upward

    if progress <= self.fadeInTime / self.totalTime then
      -- Fade in phase
      local alpha = progress / (self.fadeInTime / self.totalTime)
      text:SetAlpha(math.max(0, math.min(1, alpha)))
    elseif progress <= (self.fadeInTime + self.holdTime) / self.totalTime then
      -- Hold phase
      text:SetAlpha(1)
    else
      -- Fade out phase
      local fadeOutProgress = (progress - (self.fadeInTime + self.holdTime) / self.totalTime) /
          (self.fadeOutTime / self.totalTime)
      text:SetAlpha(math.max(0, math.min(1, 1 - fadeOutProgress)))
    end

    -- Move upward
    floater:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)

    -- Remove when done
    if self.elapsed >= self.totalTime then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      C_Timer.After(0.1, function() self:SetParent(nil) end)
    end
  end)
end

-- Show warning about missing Phial of Truesight
function GH:ShowPhialWarning()
  -- Create warning frame
  local warning = CreateFrame("Frame", "GatherHeroPhialWarning", UIParent, "BackdropTemplate")
  warning:SetSize(380, 150) -- Slightly taller to fit new button
  warning:SetPoint("CENTER", UIParent, "CENTER")
  warning:SetFrameStrata("DIALOG")
  warning:SetFrameLevel(100)
  warning:SetMovable(true)
  warning:EnableMouse(true)
  warning:SetClampedToScreen(true)
  warning:RegisterForDrag("LeftButton")

  -- Add background
  if warning.SetBackdrop then
    warning:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    warning:SetBackdropColor(0, 0, 0, 0.9)
  else
    local bg = warning:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.9)

    local border = CreateFrame("Frame", nil, warning, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
  end

  -- Warning title
  local titleText = warning:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleText:SetPoint("TOP", 0, -10)
  titleText:SetText("|cFFFF0000Warning!|r")

  -- Warning message
  local msgText = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  msgText:SetPoint("TOP", titleText, "BOTTOM", 0, -5)
  msgText:SetWidth(280)
  msgText:SetText(
    "You are gathering without Phial of Truesight!\n\nThis buff significantly increases your herb and ore gathering results.")

  -- Dismiss button (keeps existing functionality)
  local dismissButton = CreateFrame("Button", nil, warning, "UIPanelButtonTemplate")
  dismissButton:SetSize(130, 24)
  dismissButton:SetPoint("BOTTOMLEFT", warning, "BOTTOM", 0, 15)
  dismissButton:SetText("Dismiss")
  dismissButton:SetScript("OnClick", function()
    warning:Hide()
    GH.phialWarningShown = false -- Allow warning to appear again later
  end)

  -- Ignore for session button (new functionality)
  local ignoreButton = CreateFrame("Button", nil, warning, "UIPanelButtonTemplate")
  ignoreButton:SetSize(130, 24)
  ignoreButton:SetPoint("BOTTOMRIGHT", warning, "BOTTOM", 0, 15)
  ignoreButton:SetText("Ignore for Session")
  ignoreButton:SetScript("OnClick", function()
    warning:Hide()
    GH.phialWarningShown = true -- Remember that user dismissed the warning for this session
  end)

  -- Make draggable
  warning:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)

  warning:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  -- Play warning sound
  PlaySound(SOUNDKIT.RAID_WARNING, "Master", false)

  -- Mark that we've shown the warning this session (temporary until user clicks a button)
  -- We're now setting this based on which button the user clicks
  GH.phialWarningShown = true
end
