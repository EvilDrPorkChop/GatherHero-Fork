-- GH_ChallengeMode.lua
-- Challenge Mode for Gather Hero addon

local _, GH = ...

-- Create namespace for Challenge Mode
GH.ChallengeMode = {}

-- Define challenge types (add this here)
GH.ChallengeMode.CHALLENGE_TYPES = {
  NODE_COUNT = 1,      -- Loot X nodes within Y minutes
  HIGH_VALUE_NODE = 2, -- Loot a node worth X times the average
  TIMED_GATHER = 3,    -- Loot gold every X seconds
  COMBAT_GATHER = 4,   -- Loot while in combat
  ZONE_HOPPER = 5,     -- Gather in multiple zones
  FINAL_GOLD = 6       -- Gather 1.5x total gold earned in same time spent
}

-- Initialize challenge mode saved variables
function GH.ChallengeMode:InitDB()
    -- Ensure the main DB exists
    if not GatherHeroDB then
        GatherHeroDB = {}
    end

    -- Ensure the challenges table exists
    if not GatherHeroDB.challenges then
        GatherHeroDB.challenges = {
            enabled = false,            -- Is challenge mode enabled
            activeChallenge = nil,      -- Currently active challenge
            challengeStartTime = nil,   -- When the current challenge started
            challengeProgress = 0,      -- Progress toward completion
            challengeGoal = 0,          -- Goal to reach
            challengeCompleted = false, -- Has the challenge been completed
            history = {},               -- Past challenges history
            settings = {}               -- Challenge settings (start empty)
        }
    end

    local challenges = GatherHeroDB.challenges

    -- Ensure the settings table exists
    if not challenges.settings then
        challenges.settings = {}
    end

    local settings = challenges.settings

    -- Ensure the High Value Node challenge settings exist
    if not settings.highValueNode then
        settings.highValueNode = {
            multiplier = 2.5, -- Target node value is 2.5x the average by default
            allowedProfessions = {
                ["Herbalism"] = true,
                ["Mining"] = true,
                ["Skinning"] = true,
                ["Fishing"] = true
            }
        }
    end

    -- You can add other challenge types here with the same pattern
    -- if not settings.otherChallenge then settings.otherChallenge = { ... } end

    self.dbInitialized = true
end                                                                                                                                                                          

-- Initialize challenge mode
function GH.ChallengeMode:OnInitialize()
  self:InitDB()

  if not self.dbInitialized then
    C_Timer.After(1, function() self:OnInitialize() end)
    return
  end

  -- Create instruction frame
  self:CreateInstructionFrame()

  -- Create completion frame
  self:CreateCompletionFrame()

  -- Create challenge button
  C_Timer.After(1, function() self:CreateChallengeButton() end)
end

-- Raid-style countdown function
function GH.ChallengeMode:StartCountdown(onCompleteCallback)
  local count = 5 -- 5 second countdown

  -- Create countdown frame if needed
  if not self.countdownFrame then
    local frame = CreateFrame("Frame", "GatherHeroChallengeCountdown", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:SetSize(200, 200)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(GameFontNormalHuge:GetFont(), 72, "THICKOUTLINE")
    text:SetPoint("CENTER", frame, "CENTER")
    text:SetTextColor(1, 0.82, 0)
    frame.text = text

    self.countdownFrame = frame
  end

  -- Show initial count
  self.countdownFrame:Show()
  self.countdownFrame.text:SetText(count)

  -- Play countdown sound if available
  if PlaySoundFile and WeakAuras and WeakAuras.PowerAurasSoundPath then
    PlaySoundFile(WeakAuras.PowerAurasSoundPath .. "pullcount.ogg", "Master")
  end

  -- Timer function for countdown
  local function CountdownTimer()
    count = count - 1

    if count > 0 then
      -- Update countdown text
      self.countdownFrame.text:SetText(count)

      -- Play tick sound if available
      if PlaySoundFile and WeakAuras and WeakAuras.PowerAurasSoundPath then
        PlaySoundFile(WeakAuras.PowerAurasSoundPath .. "tick.ogg", "Master")
      end

      -- Continue countdown
      C_Timer.After(1, CountdownTimer)
    else
      -- Play "GO" sound if available
      if PlaySoundFile and WeakAuras and WeakAuras.PowerAurasSoundPath then
        PlaySoundFile(WeakAuras.PowerAurasSoundPath .. "pewpew.ogg", "Master")
      end

      -- Flash green "GO" text
      self.countdownFrame.text:SetText("GO!")
      self.countdownFrame.text:SetTextColor(0, 1, 0)

      -- Hide countdown after a moment
      C_Timer.After(1, function()
        self.countdownFrame:Hide()
        self.countdownFrame.text:SetTextColor(1, 0.82, 0) -- Reset to gold color

        -- Execute callback
        if onCompleteCallback then
          onCompleteCallback()
        end
      end)
    end
  end

  -- Start countdown
  C_Timer.After(1, CountdownTimer)
end

-- Function to process the complete node value (called when all items from a node are gathered)
function GH.ChallengeMode:ProcessCompleteNode(totalNodeValue, professionType, itemCount)
  -- Use this complete node value for the High Value Node challenge
  if GatherHeroDB.challenges.enabled and
      GatherHeroDB.challenges.activeChallenge == self.CHALLENGE_TYPES.HIGH_VALUE_NODE then
    -- Update progress (for HIGH_VALUE_NODE, progress is the highest value found)
    if totalNodeValue > GatherHeroDB.challenges.challengeProgress then
      GatherHeroDB.challenges.challengeProgress = totalNodeValue

      -- Show progress popup
      if GH.ObjectivePopup then
        GH.ObjectivePopup:ShowHighValueProgress(totalNodeValue, GatherHeroDB.challenges.challengeGoal)
      end

      -- Update UI
      self:UpdateChallengeUI()

      -- Check if challenge completed and we have a valid goal
      if GatherHeroDB.challenges.challengeGoal > 0 and totalNodeValue >= GatherHeroDB.challenges.challengeGoal then
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        self:ShowCompletionMessage(
          "High Value Node Challenge Complete!",
          string.format("You found a node worth %s, exceeding the target of %s!",
            self:FormatGold(totalNodeValue),
            self:FormatGold(GatherHeroDB.challenges.challengeGoal))
        )

        -- Also show as an objective popup for more visibility
        if GH.ObjectivePopup then
          GH.ObjectivePopup:Show(
            string.format("Challenge Complete! Found a node worth %s!", self:FormatGold(totalNodeValue)),
            5 -- Show for 5 seconds
          )
        end

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Complete the challenge
        self:CompleteChallenge(true)

        -- Start next challenge in the series
        C_Timer.After(2, function()
          -- Start Timed Gather challenge
          local params = {
            timeWindow = GatherHeroDB.challenges.settings.timedGather.timeWindow,
            totalDuration = GatherHeroDB.challenges.settings.timedGather.totalDuration,
            requiredGathers = GatherHeroDB.challenges.settings.timedGather.requiredGathers
          }
          self:StartNextChallenge(self.CHALLENGE_TYPES.TIMED_GATHER, params)
        end)
      end
    end
  end
end

-- Create instruction frame for challenge instructions
function GH.ChallengeMode:CreateInstructionFrame()
  if not self.instructionFrame then
    local frame = CreateFrame("Frame", "GatherHeroChallengeInstructions", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:SetSize(600, 200)

    -- Create title text
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(GameFontNormalHuge:GetFont(), 24, "THICKOUTLINE")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    -- Create instruction text
    local instruction = frame:CreateFontString(nil, "OVERLAY")
    instruction:SetFont(GameFontNormalLarge:GetFont(), 18, "OUTLINE")
    instruction:SetPoint("TOP", title, "BOTTOM", 0, -20)
    instruction:SetWidth(580)
    instruction:SetTextColor(1, 1, 1)
    frame.instruction = instruction

    -- Hide by default
    frame:Hide()

    self.instructionFrame = frame

    -- Add fade-out animation
    self.instructionFrame.fadeOut = self.instructionFrame:CreateAnimationGroup()
    local fadeOut = self.instructionFrame.fadeOut:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.0)
    fadeOut:SetDuration(1.0)
    fadeOut:SetOrder(1)

    self.instructionFrame.fadeOut:SetScript("OnFinished", function()
      self.instructionFrame:Hide()
    end)
  end
end

-- Show challenge instructions
function GH.ChallengeMode:ShowChallengeInstructions(title, instruction)
  if not self.instructionFrame then
    self:CreateInstructionFrame()
  end

  -- Set text
  self.instructionFrame.title:SetText(title)
  self.instructionFrame.instruction:SetText(instruction)

  -- Show frame
  self.instructionFrame:Show()
  self.instructionFrame:SetAlpha(1.0)

  -- Fade out after 5 seconds
  C_Timer.After(5, function()
    if self.instructionFrame:IsShown() then
      self.instructionFrame.fadeOut:Play()
    end
  end)
end

-- Create completion frame for challenge completion
function GH.ChallengeMode:CreateCompletionFrame()
  if not self.completionFrame then
    local frame = CreateFrame("Frame", "GatherHeroChallengeCompletion", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:SetSize(600, 200)

    -- Create title text
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(GameFontNormalHuge:GetFont(), 24, "THICKOUTLINE")
    title:SetPoint("TOP", frame, "TOP", 0, -20)
    title:SetTextColor(0, 1, 0)
    frame.title = title

    -- Create result text
    local result = frame:CreateFontString(nil, "OVERLAY")
    result:SetFont(GameFontNormalLarge:GetFont(), 18, "OUTLINE")
    result:SetPoint("TOP", title, "BOTTOM", 0, -20)
    result:SetWidth(580)
    result:SetTextColor(1, 1, 1)
    frame.result = result

    -- Hide by default
    frame:Hide()

    self.completionFrame = frame

    -- Add fade-out animation
    self.completionFrame.fadeOut = self.completionFrame:CreateAnimationGroup()
    local fadeOut = self.completionFrame.fadeOut:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.0)
    fadeOut:SetDuration(1.0)
    fadeOut:SetOrder(1)

    self.completionFrame.fadeOut:SetScript("OnFinished", function()
      self.completionFrame:Hide()
    end)
  end
end

-- Show challenge completion message
function GH.ChallengeMode:ShowCompletionMessage(title, result)
  if not self.completionFrame then
    self:CreateCompletionFrame()
  end

  -- Set text
  self.completionFrame.title:SetText(title)
  self.completionFrame.result:SetText(result)

  -- Show frame
  self.completionFrame:Show()
  self.completionFrame:SetAlpha(1.0)

  -- Fade out after 2 seconds instead of 5 seconds
  C_Timer.After(2, function()
    if self.completionFrame:IsShown() then
      self.completionFrame.fadeOut:Play()
    end
  end)
end

-- Complete a challenge
function GH.ChallengeMode:CompleteChallenge(success)
  if not GatherHeroDB.challenges.enabled or not GatherHeroDB.challenges.activeChallenge then
    return
  end

  local challengeType = GatherHeroDB.challenges.activeChallenge
  local duration = GetTime() - (GatherHeroDB.challenges.challengeStartTime or GetTime())
  local goal = GatherHeroDB.challenges.challengeGoal
  local progress = GatherHeroDB.challenges.challengeProgress

  -- Record challenge completion with points
  local points = 0
  if GH.PointSystem then
    points = GH.PointSystem:RecordChallengeCompletion(challengeType, success, duration, goal, progress)
  end

  -- Record challenge in history
  local historyEntry = {
    type = challengeType,
    success = success,
    duration = duration,
    goal = goal,
    progress = progress,
    date = date("%Y-%m-%d %H:%M:%S"),
    character = UnitName("player") .. "-" .. GetRealmName(),
    points = points -- Add points to the history entry
  }

  table.insert(GatherHeroDB.challenges.history, 1, historyEntry)

  -- Limit history size
  while #GatherHeroDB.challenges.history > 20 do
    table.remove(GatherHeroDB.challenges.history)
  end

  -- Display points earned (if successful)
  if success and points > 0 and GH.ObjectivePopup then
    GH.ObjectivePopup:Show(
      string.format("Challenge Complete! +%d points", points),
      3
    )
  end

  -- Reset current challenge
  GatherHeroDB.challenges.enabled = false
  GatherHeroDB.challenges.activeChallenge = nil
  GatherHeroDB.challenges.challengeStartTime = nil
  GatherHeroDB.challenges.challengeProgress = 0
  GatherHeroDB.challenges.challengeGoal = 0
  GatherHeroDB.challenges.challengeCompleted = false

  -- Update UI
  self:UpdateChallengeUI()

  -- Hide challenge text
  if GH.challengeText then
    GH.challengeText:Hide()
  end
end

-- Check node value for HIGH_VALUE_NODE challenge
function GH.ChallengeMode:CheckNodeValue(nodeValue, professionType)
  if not GatherHeroDB.challenges.enabled or
      GatherHeroDB.challenges.activeChallenge ~= self.CHALLENGE_TYPES.HIGH_VALUE_NODE then
    return
  end

  -- Check if this profession is allowed for the challenge
  local settings = GatherHeroDB.challenges.settings.highValueNode
  if not settings.allowedProfessions[professionType or "Unknown"] then
    return
  end

  -- Calculate average node value - use max(1, nodeCount) to avoid division by zero
  local avgNodeValue = GH.nodeCount > 0 and (GH.sessionGold / GH.nodeCount) or 0

  -- If goal is not set yet, set it based on the multiplier
  if GatherHeroDB.challenges.challengeGoal <= 0 then
    local multiplier = settings.currentMultiplier or settings.multiplier
    GatherHeroDB.challenges.challengeGoal = avgNodeValue * multiplier

    print(string.format("|cFF00FF00Gather Hero Challenge:|r Target: Find a node worth at least %s (%sx average)",
      self:FormatGold(GatherHeroDB.challenges.challengeGoal),
      multiplier))
  end

  -- Add a check to ensure we have a valid nodeValue
  if nodeValue <= 0 then
    return
  end

  -- Update progress (for HIGH_VALUE_NODE, progress is the highest value found)
  if nodeValue > GatherHeroDB.challenges.challengeProgress then
    GatherHeroDB.challenges.challengeProgress = nodeValue

    if GH.ObjectivePopup then
      GH.ObjectivePopup:ShowHighValueProgress(nodeValue, GatherHeroDB.challenges.challengeGoal)
    end

    -- Update UI
    self:UpdateChallengeUI()

    -- Check if challenge completed and we have a valid goal
    if GatherHeroDB.challenges.challengeGoal > 0 and nodeValue >= GatherHeroDB.challenges.challengeGoal then
      GatherHeroDB.challenges.challengeCompleted = true

      -- Show completion message
      self:ShowCompletionMessage(
        "High Value Node Challenge Complete!",
        string.format("You found a node worth %s, exceeding the target of %s!",
          self:FormatGold(nodeValue),
          self:FormatGold(GatherHeroDB.challenges.challengeGoal))
      )

      -- Also show as an objective popup for more visibility
      if GH.ObjectivePopup then
        GH.ObjectivePopup:Show(
          string.format("Challenge Complete! Found a node worth %s!", self:FormatGold(nodeValue)),
          5 -- Show for 5 seconds
        )
      end

      -- Play completion sound
      PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

      -- Complete the challenge
      self:CompleteChallenge(true)

      -- Start next challenge in the series
      C_Timer.After(2, function()
        -- Start Timed Gather challenge
        local params = {
          timeWindow = GatherHeroDB.challenges.settings.timedGather.timeWindow,
          totalDuration = GatherHeroDB.challenges.settings.timedGather.totalDuration,
          requiredGathers = GatherHeroDB.challenges.settings.timedGather.requiredGathers
        }
        self:StartNextChallenge(self.CHALLENGE_TYPES.TIMED_GATHER, params)
      end)
    else
      -- Only show progress message if we have a valid goal
      if GatherHeroDB.challenges.challengeGoal > 0 then
        print(string.format("|cFFFFFF00Gather Hero Challenge:|r Found a node worth %s! Need %s to complete.",
          self:FormatGold(nodeValue),
          self:FormatGold(GatherHeroDB.challenges.challengeGoal)))
      end
    end
  end
  -- Make sure the high value node settings have the correct multiplier
  function GH.ChallengeMode:RegisterDefaultSettings()
    -- Initialize saved variables if needed
    if not GatherHeroDB then return end
    if not GatherHeroDB.challenges then GatherHeroDB.challenges = {} end
    if not GatherHeroDB.challenges.settings then GatherHeroDB.challenges.settings = {} end

    -- High Value Node challenge settings
    if not GatherHeroDB.challenges.settings.highValueNode then
      GatherHeroDB.challenges.settings.highValueNode = {
        multiplier = 2.6, -- Target node value is 2.6x the average by default (updated from 2.5)
        allowedProfessions = {
          ["Herbalism"] = true,
          ["Mining"] = true,
          ["Skinning"] = true,
          ["Fishing"] = true
        }
      }
    end
  end
end

-- Format gold value for display
function GH.ChallengeMode:FormatGold(amount)
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)

  if silver == 0 then
    return gold .. "g"
  else
    return gold .. "g " .. silver .. "s"
  end
end

-- Update Challenge UI elements
function GH.ChallengeMode:UpdateChallengeUI()
  -- Create challengeText if it doesn't exist (to avoid nil errors elsewhere)
  if not GH.challengeText and GH.counterFrame then
    GH.challengeText = GH.counterFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

    -- Position it under session status text
    if GH.sessionStatusText then
      GH.challengeText:SetPoint("TOP", GH.sessionStatusText, "BOTTOM", 0, -4)
    else
      -- Fallback position if session status text doesn't exist
      GH.challengeText:SetPoint("BOTTOM", GH.counterFrame, "BOTTOM", 0, 40)
    end

    -- Store reference
    GH.counters = GH.counters or {}
    GH.counters.challengeText = GH.challengeText
  end

  -- Always hide it - we use the dedicated Challenge UI instead
  if GH.challengeText then
    GH.challengeText:Hide()
  end
end

-- Create challenge button in main UI
function GH.ChallengeMode:CreateChallengeButton()
  if not GH.counterFrame then return end

  local challengeButton = CreateFrame("Button", nil, GH.counterFrame)
  challengeButton:SetSize(16, 16)
  challengeButton:SetPoint("TOPLEFT", GH.counterFrame, "TOPLEFT", 32, -8) -- Position next to history button
  challengeButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
  challengeButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight", "ADD")

  challengeButton:SetScript("OnClick", function()
    self:ShowChallengeWindow()
  end)

  challengeButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Challenge Mode")
    GameTooltip:Show()
  end)

  challengeButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Store reference
  GH.challengeButton = challengeButton
end

-- Show challenge mode window
function GH.ChallengeMode:ShowChallengeWindow()
  -- If the window already exists, just show it
  if self.challengeFrame and self.challengeFrame:IsShown() then
    self.challengeFrame:Hide()
    return
  elseif self.challengeFrame then
    self.challengeFrame:Show()
    return
  end

  -- Main frame
  local frame = CreateFrame("Frame", "GatherHeroChallengeFrame", UIParent, "BackdropTemplate")
  frame:SetSize(500, 400)
  frame:SetPoint("CENTER", UIParent, "CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")

  -- Background and border
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
  else
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 0.8)

    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
  end

  -- Title
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText("Gather Hero - Challenge Mode")

  -- Close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", -5, -5)

  -- Create start challenge button
  local startButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  startButton:SetSize(150, 30)
  startButton:SetPoint("CENTER", frame, "CENTER", 0, 0)
  startButton:SetText("Start Challenge Series")

  startButton:SetScript("OnClick", function()
    -- Close the window
    frame:Hide()

    -- Start the first challenge (Node Count)
    local params = {
      nodeTarget = 10,
      timeLimit = 5
    }
    -- Find the actual function from the GH.Challenge.NodeCount module
    if GH.Challenge and GH.Challenge.NodeCount then
      GH.ChallengeMode:StartChallenge(GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT, params)
    else
      print("|cFFFF0000Gather Hero Challenge:|r Node Count challenge module not found!")
    end
  end)

  -- Challenge description
  local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  desc:SetPoint("TOP", title, "BOTTOM", 0, -20)
  desc:SetWidth(460)
  desc:SetText(
    "Begin a series of challenges that will test your gathering skills. Each challenge must be completed to unlock the next one.")

  -- Allowed professions section
  local profLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  profLabel:SetPoint("TOP", desc, "BOTTOM", 0, -20)
  profLabel:SetText("Allowed Professions")

  -- Create profession checkboxes
  local professions = { "Herbalism", "Mining", "Skinning", "Fishing" }
  local checkboxes = {}

  for i, profession in ipairs(professions) do
    local checkbox = CreateFrame("CheckButton", "GatherHeroChallenge" .. profession .. "CB",
      frame, "InterfaceOptionsCheckButtonTemplate")

    if i <= 2 then
      -- First row
      checkbox:SetPoint("TOP", profLabel, "BOTTOM", i == 1 and -80 or 80, -10)
    else
      -- Second row
      checkbox:SetPoint("TOP", checkboxes[i - 2], "BOTTOM", 0, -10)
    end

    local checkboxLabel = _G[checkbox:GetName() .. "Text"]
    checkboxLabel:SetText(profession)

    -- Initialize checkbox state from saved settings
    if GatherHeroDB and GatherHeroDB.challenges and GatherHeroDB.challenges.settings then
      local checked = true

      -- Check if the profession is allowed in any challenge
      if GatherHeroDB.challenges.settings.nodeCount and
          GatherHeroDB.challenges.settings.nodeCount.allowedProfessions then
        checked = checked and GatherHeroDB.challenges.settings.nodeCount.allowedProfessions[profession]
      end

      if GatherHeroDB.challenges.settings.highValueNode and
          GatherHeroDB.challenges.settings.highValueNode.allowedProfessions then
        checked = checked and GatherHeroDB.challenges.settings.highValueNode.allowedProfessions[profession]
      end

      checkbox:SetChecked(checked)
    else
      checkbox:SetChecked(true)
    end

    -- When checkbox state changes, update all challenge settings
    checkbox:SetScript("OnClick", function(self)
      local isChecked = self:GetChecked()

      -- Update Node Count challenge settings
      if GatherHeroDB.challenges.settings.nodeCount and
          GatherHeroDB.challenges.settings.nodeCount.allowedProfessions then
        GatherHeroDB.challenges.settings.nodeCount.allowedProfessions[profession] = isChecked
      end

      -- Update High Value Node challenge settings
      if GatherHeroDB.challenges.settings.highValueNode and
          GatherHeroDB.challenges.settings.highValueNode.allowedProfessions then
        GatherHeroDB.challenges.settings.highValueNode.allowedProfessions[profession] = isChecked
      end
    end)

    checkboxes[i] = checkbox
  end

  -- Make frame draggable
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  -- Store reference
  self.challengeFrame = frame
end

-- Start a challenge
function GH.ChallengeMode:StartChallenge(challengeType, params)
  -- This function will be overridden by specific challenge modules
  if challengeType == self.CHALLENGE_TYPES.HIGH_VALUE_NODE then
    -- This is handled by the original ChallengeMode module
    -- Start the countdown
    self:StartCountdown(function()
      -- Stop any existing session and start a fresh one
      if GH.sessionState ~= "idle" then
        GH:StopSession()
      end

      -- Start a new session
      GH:StartSession()

      -- Setup the challenge
      GatherHeroDB.challenges.enabled = true
      GatherHeroDB.challenges.activeChallenge = challengeType
      GatherHeroDB.challenges.challengeStartTime = GetTime()
      GatherHeroDB.challenges.challengeProgress = 0

      -- For HIGH_VALUE_NODE, set goal based on multiplier (calculated when first node is gathered)
      local multiplier = params and params.multiplier or
          GatherHeroDB.challenges.settings.highValueNode.multiplier

      GatherHeroDB.challenges.settings.highValueNode.currentMultiplier = multiplier
      -- Goal will be set to 0 initially and updated when first node is gathered
      GatherHeroDB.challenges.challengeGoal = 0

      GatherHeroDB.challenges.challengeCompleted = false

      -- Update UI
      self:UpdateChallengeUI()

      -- Show challenge instructions
      self:ShowChallengeInstructions(
        "High Value Node Challenge",
        string.format("Find a node worth at least %.1fx your average node value!", multiplier)
      )

      -- Log challenge info to console
      print(string.format(
        "|cFF00FF00Gather Hero Challenge:|r High Value Node: Find a node worth at least %.1fx your average node value!",
        multiplier))
    end)

    return true
  end

  -- If we reach here, the challenge type wasn't handled
  print("|cFFFF0000Gather Hero Challenge:|r Unknown challenge type: " .. tostring(challengeType))
  return false
end

-- Add this helper function to your main addon file or the GH_ChallengeMode.lua file
function GH:EnsureChallengeTimeTracking()
  if not GatherHeroDB.challenges then
    GatherHeroDB.challenges = {}
  end

  if not GatherHeroDB.challenges.firstChallengeStartTime then
    GatherHeroDB.challenges.firstChallengeStartTime = GetTime()
  end
end

-- Initialize the challenge mode
GH.ChallengeMode:OnInitialize()
