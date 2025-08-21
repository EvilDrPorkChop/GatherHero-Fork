-- GH_Challenge_UI.lua
-- Dedicated UI for challenge tracking

local _, GH = ...

-- Create namespace for Challenge UI
GH.ChallengeUI = {}
-- Add a guard against too frequent updates
GH.ChallengeUI.lastUpdateTime = 0
GH.ChallengeUI.updateCooldown = 0.3


-- Initialize the challenge UI
function GH.ChallengeUI:Initialize()
  -- Create the main frame
  local frame = CreateFrame("Frame", "GatherHeroChallengeUI", UIParent, "BackdropTemplate")
  frame:SetSize(250, 120)
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -200)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)

  -- Add close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
  closeButton:SetSize(20, 20)

  -- Set up the click handler to stop the challenge
  closeButton:SetScript("OnClick", function()
    -- Hide the frame
    frame:Hide()

    -- If there's an active challenge, stop it
    if GatherHeroDB and GatherHeroDB.challenges and
        GatherHeroDB.challenges.enabled and
        GatherHeroDB.challenges.activeChallenge then
      print("|cFF00FF00Gather Hero:|r Challenge canceled by user.")

      -- Get the challenge type name for better messaging
      local challengeTypeName = "Unknown"
      local challengeType = GatherHeroDB.challenges.activeChallenge

      if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
        challengeTypeName = "Node Count"
      elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
        challengeTypeName = "High Value Node"
      elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
        challengeTypeName = "Timed Gather"
      elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
        challengeTypeName = "Combat Gather"
      elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
        challengeTypeName = "Zone Hopper"
      elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
        challengeTypeName = "Final Gold"
      end

      -- Show cancellation message
      if GH.ObjectivePopup then
        GH.ObjectivePopup:Show(
          string.format("%s Challenge Canceled", challengeTypeName),
          3
        )
      end

      -- Reset challenge state but don't stop the session
      GatherHeroDB.challenges.enabled = false
      GatherHeroDB.challenges.activeChallenge = nil
      GatherHeroDB.challenges.challengeStartTime = nil
      GatherHeroDB.challenges.challengeProgress = 0
      GatherHeroDB.challenges.challengeGoal = 0
      GatherHeroDB.challenges.challengeCompleted = false
    end
  end)

  -- Add tooltip
  closeButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Cancel Challenge")
    GameTooltip:Show()
  end)

  closeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  frame.closeButton = closeButton

  -- Add background and border
  if frame.SetBackdrop then -- Check for API availability
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
  else
    -- Alternative for newer versions
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)

    -- Create border frame
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -5, 5)
    border:SetPoint("BOTTOMRIGHT", 5, -5)
    if border.SetBackdrop then
      border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
    end
  end

  -- Make frame draggable
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position for future sessions
    local point, _, _, xOfs, yOfs = self:GetPoint(1)
    if not GatherHeroDB.challengeUI then GatherHeroDB.challengeUI = {} end
    GatherHeroDB.challengeUI.position = { point = point, x = xOfs, y = yOfs }
  end)

  -- Add title
  local title = frame:CreateFontString(nil, "OVERLAY")
  title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
  title:SetPoint("TOP", frame, "TOP", 0, -8)
  title:SetText("Active Challenge")
  title:SetTextColor(1, 0.82, 0) -- Gold color
  frame.title = title

  -- Add challenge type
  local challengeType = frame:CreateFontString(nil, "OVERLAY")
  challengeType:SetFont(STANDARD_TEXT_FONT, 12, "NONE")
  challengeType:SetPoint("TOP", title, "BOTTOM", 0, -5)
  challengeType:SetText("No active challenge")
  challengeType:SetTextColor(1, 1, 1)
  frame.challengeType = challengeType

  -- Add separator line
  local line = frame:CreateTexture(nil, "ARTWORK")
  line:SetTexture("Interface\\FriendsFrame\\UI-FriendsFrame-DropDown-Separator")
  line:SetHeight(8)
  line:SetPoint("TOPLEFT", challengeType, "BOTTOMLEFT", -20, -2)
  line:SetPoint("TOPRIGHT", challengeType, "BOTTOMRIGHT", 20, -2)
  line:SetTexCoord(0, 1, 0, 0.5)

  -- Add objective
  local objective = frame:CreateFontString(nil, "OVERLAY")
  objective:SetFont(STANDARD_TEXT_FONT, 11, "NONE")
  objective:SetPoint("TOP", line, "BOTTOM", 0, -2)
  objective:SetWidth(230)
  objective:SetJustifyH("CENTER")
  objective:SetText("Complete challenge objectives")
  objective:SetTextColor(0.8, 0.8, 0.8)
  frame.objective = objective

  -- Add progress
  local progress = frame:CreateFontString(nil, "OVERLAY")
  progress:SetFont(STANDARD_TEXT_FONT, 11, "NONE")
  progress:SetPoint("TOP", objective, "BOTTOM", 0, -5)
  progress:SetWidth(230)
  progress:SetJustifyH("CENTER")
  progress:SetText("0 / 0")
  progress:SetTextColor(0, 1, 0)
  frame.progress = progress

  -- Add progress bar
  local progressBar = CreateFrame("StatusBar", nil, frame)
  progressBar:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 10, -5)
  progressBar:SetPoint("TOPRIGHT", progress, "BOTTOMRIGHT", -10, -5)
  progressBar:SetHeight(12)
  progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  progressBar:SetStatusBarColor(0, 0.7, 0)
  progressBar:SetMinMaxValues(0, 100)
  progressBar:SetValue(0)

  -- Add progress bar background
  local progressBg = progressBar:CreateTexture(nil, "BACKGROUND")
  progressBg:SetAllPoints()
  progressBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
  progressBg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

  -- Add progress bar border
  local progressBorder = CreateFrame("Frame", nil, progressBar, "BackdropTemplate")
  progressBorder:SetPoint("TOPLEFT", -2, 2)
  progressBorder:SetPoint("BOTTOMRIGHT", 2, -2)
  progressBorder:SetFrameStrata("MEDIUM")

  -- Check if SetBackdrop method exists (compatibility with newer versions)
  if progressBorder.SetBackdrop then
    progressBorder:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    progressBorder:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
  else
    -- Alternative for newer API versions
    local border = progressBorder:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.6, 0.6, 0.6, 0.8)
  end

  -- Add time remaining (for timed challenges)
  local timeRemaining = frame:CreateFontString(nil, "OVERLAY")
  timeRemaining:SetFont(STANDARD_TEXT_FONT, 10, "NONE")
  timeRemaining:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
  timeRemaining:SetText("Time: --:--")
  timeRemaining:SetTextColor(1, 1, 0)
  frame.timeRemaining = timeRemaining

  -- Store frame reference
  self.frame = frame
  frame.progressBar = progressBar

  -- Initially hide the frame
  frame:Hide()

  -- Restore position from saved variables if available
  if GatherHeroDB and GatherHeroDB.challengeUI and GatherHeroDB.challengeUI.position then
    local pos = GatherHeroDB.challengeUI.position
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
  end
end

-- Add this helper function at the beginning
function GH.ChallengeUI:FormatGold(amount)
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)
  return gold .. "g " .. silver .. "s"
end

-- Update UI based on challenge data
function GH.ChallengeUI:Update()
  -- Prevent UI flickering by limiting update frequency
  local currentTime = GetTime()
  if currentTime - self.lastUpdateTime < self.updateCooldown then
    return
  end
  self.lastUpdateTime = currentTime

  if not self.frame then
    self:Initialize()
  end

  -- Get challenge data
  local challengeData = GatherHeroDB and GatherHeroDB.challenges

  -- Hide UI if no active challenge
  if not challengeData or not challengeData.enabled or not challengeData.activeChallenge then
    if self.frame:IsShown() then
      self.frame:Hide()
    end
    return
  end

  -- Show UI for active challenge
  if not self.frame:IsShown() then
    self.frame:Show()
  end

  -- Format gold value helper function
  local function FormatGold(amount)
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    return gold .. "g " .. silver .. "s"
  end

  -- Update fields based on challenge type
  local challengeType = challengeData.activeChallenge

  if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
    -- Node Count Challenge
    self.frame.title:SetText("Node Count Challenge")
    self.frame.challengeType:SetText("Gathering Speed")

    -- Get challenge data
    local data = challengeData.nodeCountData
    if not data then return end

    -- Update objective and progress
    self.frame.objective:SetText(string.format("Gather %d nodes within %d minutes",
      data.nodeTarget, data.timeLimit))

    self.frame.progress:SetText(string.format("%d/%d nodes gathered",
      data.nodesGathered, data.nodeTarget))

    -- Update progress bar
    local progress = data.nodesGathered / data.nodeTarget * 100
    self.frame.progressBar:SetValue(math.min(100, progress))

    -- Update time remaining
    local timeLeft = math.max(0, data.endTime - GetTime())
    local minutes = math.floor(timeLeft / 60)
    local seconds = math.floor(timeLeft % 60)
    self.frame.timeRemaining:SetText(string.format("Time: %d:%02d", minutes, seconds))

    -- Change color based on time left
    if timeLeft < 30 then
      self.frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 30 seconds
    elseif timeLeft < 60 then
      self.frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 1 minute
    else
      self.frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
    end
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
    -- HIGH VALUE NODE CHALLENGE
    self.frame.title:SetText("High Value Node Challenge")
    self.frame.challengeType:SetText("Quality Gathering")

    -- Update objective and progress
    local multiplier = challengeData.settings and challengeData.settings.highValueNode and
        (challengeData.settings.highValueNode.currentMultiplier or
          challengeData.settings.highValueNode.multiplier) or 2.6

    self.frame.objective:SetText(string.format("Find a node worth %.1fx average value",
      multiplier))

    if challengeData.challengeGoal <= 0 then
      self.frame.progress:SetText("Gathering data...")
      self.frame.progressBar:SetValue(10) -- Show a bit of progress while waiting
    else
      -- Use our local FormatGold function for formatting both values consistently
      self.frame.progress:SetText(string.format("%s / %s",
        self:FormatGold(challengeData.challengeProgress),
        self:FormatGold(challengeData.challengeGoal)))

      -- Calculate progress percentage (capped at 100%)
      local progressPercent = 0
      if challengeData.challengeGoal > 0 then
        progressPercent = math.min(100, (challengeData.challengeProgress / challengeData.challengeGoal) * 100)
      end
      self.frame.progressBar:SetValue(progressPercent)
    end

    -- No time limit for this challenge
    self.frame.timeRemaining:SetText("No time limit")
    self.frame.timeRemaining:SetTextColor(0, 1, 0) -- Green
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
    -- Timed Gather Challenge
    self.frame.title:SetText("Timed Gather Challenge")
    self.frame.challengeType:SetText("Time Pressure")

    -- Get challenge data
    local data = challengeData.timedGatherData
    if not data then return end

    -- Update objective and progress
    self.frame.objective:SetText(string.format("Gather every %d seconds",
      data.timeWindow))

    self.frame.progress:SetText(string.format("%d/%d gathers completed",
      data.gathersCompleted, data.requiredGathers))

    -- Update progress bar
    local progress = data.gathersCompleted / data.requiredGathers * 100
    self.frame.progressBar:SetValue(math.min(100, progress))

    -- Update time remaining
    local timeToNextGather = math.max(0, data.nextGatherTime - GetTime())
    local overallTimeLeft = math.max(0, data.endTime - GetTime())

    -- Show the most important time (whichever is shorter)
    if timeToNextGather < overallTimeLeft then
      self.frame.timeRemaining:SetText(string.format("Next gather: %.1fs", timeToNextGather))

      -- Color based on urgency
      if timeToNextGather < 3 then
        self.frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 3 seconds
      elseif timeToNextGather < 5 then
        self.frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 5 seconds
      else
        self.frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
      end
    else
      -- Show overall time remaining
      self.frame.timeRemaining:SetText(string.format("Time left: %.1fs", overallTimeLeft))
      self.frame.timeRemaining:SetTextColor(1, 1, 0) -- Yellow
    end
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    -- Combat Gather Challenge
    self.frame.title:SetText("Combat Gather Challenge")
    self.frame.challengeType:SetText("Combat Gathering")

    -- Get challenge data
    local data = challengeData.combatGatherData
    if not data then return end

    -- Update objective and progress
    self.frame.objective:SetText(string.format("Gather %d nodes while in combat",
      data.requiredGathers))

    self.frame.progress:SetText(string.format("%d/%d nodes gathered in combat",
      data.gathersCompleted, data.requiredGathers))

    -- Update progress bar
    local progress = data.gathersCompleted / data.requiredGathers * 100
    self.frame.progressBar:SetValue(math.min(100, progress))

    -- Update time remaining
    local timeLeft = math.max(0, data.endTime - GetTime())
    local minutes = math.floor(timeLeft / 60)
    local seconds = math.floor(timeLeft % 60)
    self.frame.timeRemaining:SetText(string.format("Time: %d:%02d", minutes, seconds))

    -- Change color based on time left
    if timeLeft < 30 then
      self.frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 30 seconds
    elseif timeLeft < 60 then
      self.frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 1 minute
    else
      self.frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
    end

    -- Highlight if player is in combat
    if UnitAffectingCombat("player") then
      self.frame.progress:SetTextColor(0, 1, 0)   -- Green when in combat
    else
      self.frame.progress:SetTextColor(1, 0.5, 0) -- Orange when not in combat
    end
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
    -- Zone Hopper Challenge
    self.frame.title:SetText("Zone Hopper Challenge")
    self.frame.challengeType:SetText("Zone Exploration")

    -- Get challenge data
    local data = challengeData.zoneHopperData
    if not data then return end

    -- Get current zone
    local currentZone = GetZoneText() or GetMinimapZoneText() or "Unknown"
    local currentZoneNodes = 0

    if data.zoneData[currentZone] then
      currentZoneNodes = data.zoneData[currentZone].nodesGathered
    end

    -- Update objective text
    self.frame.objective:SetText(string.format("Gather in %d different zones (%d nodes each)",
      data.requiredZones, data.nodesPerZone))

    -- Update progress text and bar
    self.frame.progress:SetText(string.format("%d/%d zones completed",
      data.completedZones, data.requiredZones))

    -- Update progress bar
    local progressPercent = (data.completedZones / data.requiredZones) * 100
    self.frame.progressBar:SetValue(progressPercent)

    -- Update time remaining
    local timeLeft = math.max(0, data.endTime - GetTime())
    local minutes = math.floor(timeLeft / 60)
    local seconds = math.floor(timeLeft % 60)

    -- Build a string showing current zone progress
    local zoneProgress = string.format("Current zone: %d/%d", currentZoneNodes, data.nodesPerZone)

    -- Combine time and zone progress information
    self.frame.timeRemaining:SetText(string.format("Time: %d:%02d | %s",
      minutes, seconds, zoneProgress))

    -- Change color based on time left
    if timeLeft < 30 then
      self.frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 30 seconds
    elseif timeLeft < 60 then
      self.frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 1 minute
    else
      self.frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
    end
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
    -- Final Gold Challenge
    self.frame.title:SetText("Final Gold Challenge")
    self.frame.challengeType:SetText("Gold Rush")

    -- Get challenge data
    local data = challengeData.finalGoldData
    if not data then return end

    -- Calculate current gold collected during this challenge
    local currentGold = (GH.sessionGold or 0) - data.startingGold

    -- Update objective text
    self.frame.objective:SetText(string.format("Gather %s gold",
      self:FormatGold(data.targetGold)))

    -- Update progress text and bar
    self.frame.progress:SetText(string.format("%s/%s gold collected",
      self:FormatGold(currentGold), self:FormatGold(data.targetGold)))

    -- Update progress bar
    local progressPercent = (currentGold / data.targetGold) * 100
    self.frame.progressBar:SetValue(math.min(100, progressPercent))

    -- Update time remaining
    local timeLeft = math.max(0, data.endTime - GetTime())
    local minutes = math.floor(timeLeft / 60)
    local seconds = math.floor(timeLeft % 60)
    self.frame.timeRemaining:SetText(string.format("Time: %d:%02d", minutes, seconds))

    -- Change color based on time left
    if timeLeft < 30 then
      self.frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 30 seconds
    elseif timeLeft < 60 then
      self.frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 1 minute
    else
      self.frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
    end
  else
    -- Unknown or other challenge type
    self.frame.title:SetText("Active Challenge")
    self.frame.challengeType:SetText("Challenge in progress")
    self.frame.objective:SetText("Complete the objectives")
    self.frame.progress:SetText("In progress")
    self.frame.progressBar:SetValue(50)
    self.frame.timeRemaining:SetText("")
  end
end

-- Start a timer to update UI regularly
function GH.ChallengeUI:StartUpdates()
  if self.updateTimer then return end

  self.updateTimer = C_Timer.NewTicker(0.5, function()
    self:Update()
  end)
end

-- Stop regular updates
function GH.ChallengeUI:StopUpdates()
  if self.updateTimer then
    self.updateTimer:Cancel()
    self.updateTimer = nil
  end
end

-- Toggle UI visibility
function GH.ChallengeUI:Toggle()
  if not self.frame then
    self:Initialize()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
  else
    -- Temporarily show the frame
    self.frame:Show()
    -- Let the update function handle actual visibility based on challenge status
    self:Update()
  end
end

-- Initialize when addon loads
GH.ChallengeUI:Initialize()
GH.ChallengeUI:StartUpdates()
