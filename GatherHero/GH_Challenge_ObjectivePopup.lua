-- GH_Challenge_ObjectivePopup.lua
-- Provides quest objective popups that stack above floating gold text

local _, GH = ...

-- Create namespace for objective popups
GH.ObjectivePopup = {}

-- Initialize popup frame
function GH.ObjectivePopup:Initialize()
  -- Create the main frame for objective popups
  local frame = CreateFrame("Frame", "GatherHeroObjectivePopup", UIParent)
  frame:SetSize(400, 40)
  -- Position it significantly higher to completely avoid conflict with floating gold text
  frame:SetPoint("TOP", UIParent, "TOP", 0, -100) -- Position near top of screen
  frame:SetFrameStrata("DIALOG")                  -- Use highest strata to be above everything
  frame:Hide()

  -- Create text that looks like Blizzard's quest updates
  local text = frame:CreateFontString(nil, "OVERLAY")
  text:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE") -- Back to 16pt size
  text:SetPoint("CENTER", frame, "CENTER")
  text:SetTextColor(1, 0.82, 0)                   -- Gold color like Blizzard quest updates
  text:SetText("Objective details here")
  frame.text = text

  -- Remove background - no longer using this
  -- local bg = frame:CreateTexture(nil, "BACKGROUND")
  -- bg:SetAllPoints()
  -- bg:SetColorTexture(0, 0, 0, 0.3)

  -- Create animations
  frame.fadeIn = frame:CreateAnimationGroup()
  local fadeIn = frame.fadeIn:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0)
  fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(0.3)
  fadeIn:SetOrder(1)

  frame.fadeOut = frame:CreateAnimationGroup()
  local fadeOut = frame.fadeOut:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(1)
  fadeOut:SetToAlpha(0)
  fadeOut:SetDuration(0.7)
  fadeOut:SetOrder(1)

  frame.fadeOut:SetScript("OnFinished", function()
    frame:Hide()
  end)

  -- Store frame reference
  self.frame = frame

  -- Create a hook to ensure this display is not affected by other UI elements
  -- Whenever the frame is shown, force it to stay shown
  frame:HookScript("OnShow", function()
    -- Re-show it next frame to ensure it stays visible
    C_Timer.After(0.01, function()
      if frame.forcedVisible then
        frame:Show()
      end
    end)
  end)

  -- Store last update time to limit sound frequency
  self.lastSoundTime = 0
end

-- Show objective popup
function GH.ObjectivePopup:Show(text, duration)
  if not self.frame then
    self:Initialize()
  end

  -- Set text and ensure it's visible
  self.frame.text:SetText(text)
  self.frame.forcedVisible = true

  -- Play Blizzard's quest update sound (only once every 3 seconds)
  local currentTime = GetTime()
  if currentTime - self.lastSoundTime > 3 then
    PlaySoundFile("Sound\\Interface\\UI_QuestLogUpdate_QuestComplete.ogg", "Master")
    self.lastSoundTime = currentTime
  end

  -- Cancel any existing fadeout timer
  if self.fadeTimer then
    self.fadeTimer:Cancel()
    self.fadeTimer = nil
  end

  -- Show and fade in
  self.frame:Show()
  self.frame:SetAlpha(1) -- Set full alpha to ensure visibility

  -- Schedule fade out after duration
  self.fadeTimer = C_Timer.NewTimer(duration or 2.5, function()
    self.frame.forcedVisible = false
    if self.frame:IsShown() then
      self.frame.fadeOut:Play()
    end
  end)
end

-- Helper method to show node count challenge progress
function GH.ObjectivePopup:ShowNodeCountProgress(current, total)
  self:Show(
    string.format("Nodes collected: %d/%d", current, total),
    2.5 -- Reduced to 2.5 seconds
  )
end

-- Helper method to show high value node challenge progress
function GH.ObjectivePopup:ShowHighValueProgress(highestValue, targetValue)
  local function FormatGold(amount)
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    return gold .. "g " .. silver .. "s"
  end

  self:Show(
    string.format("High Value Node: %s / %s", FormatGold(highestValue), FormatGold(targetValue)),
    2.5 -- Reduced to 2.5 seconds
  )
end

-- Called when challenge is completed
function GH.ObjectivePopup:ShowCompletion(challengeType)
  local text = "Challenge Complete!"

  if GH.ChallengeMode and GH.ChallengeMode.CHALLENGE_TYPES then
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
      text = "Node Count Challenge Complete!"
    elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
      text = "High Value Node Challenge Complete!"
    end
  end

  self:Show(text, 4) -- Reduced to 4 seconds for completions (still longer than regular updates)

  -- Play a special sound for completion
  PlaySoundFile("Sound\\Interface\\LevelUp", "Master")
end

-- Initialize when addon loads
GH.ObjectivePopup:Initialize()
