-- GH_HighScorePanel.lua
-- High Score Panel for Gather Hero challenges
-- Shows past performance and challenge scores

local _, GH = ...

-- Create namespace for High Score Panel
GH.HighScorePanel = {}

-- Helper function to format gold values
function GH.HighScorePanel:FormatGold(amount)
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)
  if silver == 0 then
    return gold .. "g"
  else
    return gold .. "g " .. silver .. "s"
  end
end

-- Initialize High Score Panel
function GH.HighScorePanel:Initialize()

end

-- Create High Score Panel
function GH.HighScorePanel:CreatePanel()
  if self.frame and self.frame:IsShown() then
    self.frame:Hide()
    return
  elseif self.frame then
    self.frame:Show()
    self:UpdatePanel()
    return
  end

  -- Main frame
  local frame = CreateFrame("Frame", "GatherHeroHighScorePanel", UIParent, "BackdropTemplate")
  frame:SetSize(600, 450)
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
  title:SetText("Gather Hero - High Scores")

  -- Close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", -5, -5)

  -- Make frame draggable
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  -- Tab buttons
  local tabWidth = 150
  local tabHeight = 24

  -- Summary Tab
  local summaryTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  summaryTab:SetSize(tabWidth, tabHeight)
  summaryTab:SetPoint("TOPLEFT", 25, -45)
  summaryTab:SetText("Summary")
  summaryTab:SetScript("OnClick", function()
    self:ShowTab("summary")
  end)

  -- History Tab
  local historyTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  historyTab:SetSize(tabWidth, tabHeight)
  historyTab:SetPoint("LEFT", summaryTab, "RIGHT", 5, 0)
  historyTab:SetText("Run History")
  historyTab:SetScript("OnClick", function()
    self:ShowTab("history")
  end)

  -- Leaderboards Tab
  local leaderboardTab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  leaderboardTab:SetSize(tabWidth, tabHeight)
  leaderboardTab:SetPoint("LEFT", historyTab, "RIGHT", 5, 0)
  leaderboardTab:SetText("Leaderboards")
  leaderboardTab:SetScript("OnClick", function()
    self:ShowTab("leaderboard")
  end)

  -- Tab containers
  local contentFrame = CreateFrame("Frame", nil, frame)
  contentFrame:SetPoint("TOPLEFT", 20, -75)
  contentFrame:SetPoint("BOTTOMRIGHT", -20, 20)

  -- Summary content
  local summaryContent = CreateFrame("Frame", nil, contentFrame)
  summaryContent:SetAllPoints()

  -- Create summary widgets
  self:CreateSummaryWidgets(summaryContent)

  -- History content
  local historyContent = CreateFrame("Frame", nil, contentFrame)
  historyContent:SetAllPoints()
  historyContent:Hide()

  -- Create history widgets
  self:CreateHistoryWidgets(historyContent)

  -- Leaderboard content
  local leaderboardContent = CreateFrame("Frame", nil, contentFrame)
  leaderboardContent:SetAllPoints()
  leaderboardContent:Hide()

  -- Create leaderboard widgets
  self:CreateLeaderboardWidgets(leaderboardContent)

  -- Store references
  frame.tabs = {
    summary = summaryContent,
    history = historyContent,
    leaderboard = leaderboardContent
  }

  frame.tabButtons = {
    summary = summaryTab,
    history = historyTab,
    leaderboard = leaderboardTab
  }

  self.frame = frame

  -- Show the summary tab by default
  self:ShowTab("summary")
end

-- Create summary widgets
function GH.HighScorePanel:CreateSummaryWidgets(parent)
  -- Top scores section
  local topScoresTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  topScoresTitle:SetPoint("TOPLEFT", 10, -10)
  topScoresTitle:SetText("Top Scores")

  -- Top Score Categories
  local categories = {
    { label = "Highest Total Score:",     valueType = "score", key = "highestTotal" },
    { label = "Fastest Completion Time:", valueType = "time",  key = "fastestTime" },
    { label = "Most Gold Collected:",     valueType = "gold",  key = "mostGold" }
  }

  local yOffset = -40
  for i, category in ipairs(categories) do
    -- Label
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 30, yOffset)
    label:SetText(category.label)

    -- Value
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("TOPLEFT", 200, yOffset)
    value:SetText("None")

    -- Date
    local date = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    date:SetPoint("TOPLEFT", 350, yOffset)
    date:SetText("")

    -- Store widget references
    parent[category.key .. "Label"] = label
    parent[category.key .. "Value"] = value
    parent[category.key .. "Date"] = date

    yOffset = yOffset - 25
  end

  -- Points Breakdown Section
  local breakdownTitle = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  breakdownTitle:SetPoint("TOPLEFT", 10, -120)
  breakdownTitle:SetText("Points System")

  -- Points explanation text
  local explanationFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  explanationFrame:SetPoint("TOPLEFT", 20, -150)
  explanationFrame:SetPoint("BOTTOMRIGHT", -30, 20)

  local explanationText = CreateFrame("EditBox", nil, explanationFrame)
  explanationText:SetMultiLine(true)
  explanationText:SetFontObject(GameFontNormal)
  explanationText:SetWidth(explanationFrame:GetWidth() - 20)
  explanationText:SetHeight(300)
  explanationText:SetPoint("TOPLEFT", 0, 0)
  explanationText:SetAutoFocus(false)
  explanationText:SetEnabled(false)
  explanationText:SetText(
    "Points are awarded for each challenge as follows:\n\n" ..
    "Node Count Challenge:\n" ..
    "• 100 base points for completion\n" ..
    "• Up to 100 bonus points for speed\n\n" ..
    "High Value Node Challenge:\n" ..
    "• 100 base points for completion\n" ..
    "• Up to 100 bonus points based on how much the node value exceeded the target\n\n" ..
    "Timed Gather Challenge:\n" ..
    "• 20 points per successful gather\n\n" ..
    "Combat Gather Challenge:\n" ..
    "• 150 base points for completion\n" ..
    "• 10 points per gather while in combat\n\n" ..
    "Zone Hopper Challenge:\n" ..
    "• 50 points per zone completed\n\n" ..
    "Final Gold Challenge:\n" ..
    "• 200 base points for completion\n" ..
    "• Up to 300 bonus points based on percentage of gold target achieved\n\n" ..
    "Series Completion Bonuses:\n" ..
    "• 500 points for completing all challenges\n" ..
    "• Gold efficiency bonus: gold per minute × 0.5"
  )

  explanationFrame:SetScrollChild(explanationText)
end

-- Create history widgets
function GH.HighScorePanel:CreateHistoryWidgets(parent)
  -- Create scrollframe for the history
  local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 10, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetWidth(scrollFrame:GetWidth() - 20)
  content:SetHeight(500) -- Will adjust height based on content
  scrollFrame:SetScrollChild(content)

  -- Store reference
  parent.content = content
  parent.scrollFrame = scrollFrame
end

-- Create leaderboard widgets
function GH.HighScorePanel:CreateLeaderboardWidgets(parent)
  -- Create a tab frame for different leaderboards
  local challengeTypes = {
    { text = "Node Count",    value = GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT },
    { text = "High Value",    value = GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE },
    { text = "Timed Gather",  value = GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER },
    { text = "Combat Gather", value = GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER },
    { text = "Zone Hopper",   value = GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER },
    { text = "Final Gold",    value = GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD }
  }

  local buttonWidth = 80
  local buttonHeight = 24
  local xOffset = 10

  for i, challenge in ipairs(challengeTypes) do
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(buttonWidth, buttonHeight)
    button:SetPoint("TOPLEFT", xOffset, -10)
    button:SetText(challenge.text)
    button.challengeType = challenge.value

    button:SetScript("OnClick", function(self)
      GH.HighScorePanel:ShowLeaderboard(self.challengeType)
    end)

    xOffset = xOffset + buttonWidth + 5
  end

  -- Create a frame to show the leaderboard content
  local contentFrame = CreateFrame("Frame", nil, parent)
  contentFrame:SetPoint("TOPLEFT", 10, -40)
  contentFrame:SetPoint("BOTTOMRIGHT", -10, 10)

  parent.leaderboardContent = contentFrame
end

-- Show a specific tab
function GH.HighScorePanel:ShowTab(tabName)
  if not self.frame then return end

  -- Hide all tabs
  for name, tab in pairs(self.frame.tabs) do
    tab:Hide()
  end

  -- Highlight active button
  for name, button in pairs(self.frame.tabButtons) do
    if name == tabName then
      button:SetEnabled(false)
    else
      button:SetEnabled(true)
    end
  end

  -- Show the selected tab
  if self.frame.tabs[tabName] then
    self.frame.tabs[tabName]:Show()

    -- Update content for the tab
    if tabName == "summary" then
      self:UpdateSummaryTab()
    elseif tabName == "history" then
      self:UpdateHistoryTab()
    elseif tabName == "leaderboard" then
      -- Default to showing first challenge type
      self:ShowLeaderboard(GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT)
    end
  end
end

-- Update summary tab
function GH.HighScorePanel:UpdateSummaryTab()
  local tab = self.frame.tabs.summary
  if not tab then return end

  -- Update top scores
  if GatherHeroDB and GatherHeroDB.highScores and GatherHeroDB.highScores.topScores then
    local topScores = GatherHeroDB.highScores.topScores

    -- Highest Total
    if topScores.highestTotal and topScores.highestTotal.score > 0 then
      tab.highestTotalValue:SetText(topScores.highestTotal.score .. " points")
      tab.highestTotalDate:SetText(topScores.highestTotal.character .. " on " ..
        self:GetShortDate(topScores.highestTotal.date))
    else
      tab.highestTotalValue:SetText("No record")
      tab.highestTotalDate:SetText("")
    end

    -- Fastest Time
    if topScores.fastestTime and topScores.fastestTime.time < 99999 then
      tab.fastestTimeValue:SetText(self:FormatTime(topScores.fastestTime.time))
      tab.fastestTimeDate:SetText(topScores.fastestTime.character .. " on " ..
        self:GetShortDate(topScores.fastestTime.date))
    else
      tab.fastestTimeValue:SetText("No record")
      tab.fastestTimeDate:SetText("")
    end

    -- Most Gold
    if topScores.mostGold and topScores.mostGold.gold > 0 then
      tab.mostGoldValue:SetText(self:FormatGold(topScores.mostGold.gold))
      tab.mostGoldDate:SetText(topScores.mostGold.character .. " on " ..
        self:GetShortDate(topScores.mostGold.date))
    else
      tab.mostGoldValue:SetText("No record")
      tab.mostGoldDate:SetText("")
    end
  end
end

-- Update history tab
function GH.HighScorePanel:UpdateHistoryTab()
  local tab = self.frame.tabs.history
  if not tab or not tab.content then return end

  -- Clear previous content
  for _, child in pairs({ tab.content:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end

  -- Check if we have any run history
  if not GatherHeroDB or not GatherHeroDB.highScores or not GatherHeroDB.highScores.challengeRuns or
      #GatherHeroDB.highScores.challengeRuns == 0 then
    local noData = tab.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noData:SetPoint("CENTER", 0, 0)
    noData:SetText("No challenge runs recorded yet. Complete a challenge series to see your history.")
    return
  end

  -- Create a section for each run
  local yOffset = 0
  local runHeight = 200 -- Approximate height per run

  for i, run in ipairs(GatherHeroDB.highScores.challengeRuns) do
    -- Run container
    local runFrame = CreateFrame("Frame", nil, tab.content, "BackdropTemplate")
    runFrame:SetSize(tab.content:GetWidth() - 20, runHeight)
    runFrame:SetPoint("TOPLEFT", 10, -yOffset)

    if runFrame.SetBackdrop then
      runFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
    end

    -- Run header
    local header = runFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, -10)
    header:SetText(string.format("Run #%d: %s - %d points",
      i, self:GetShortDate(run.date), run.totalPoints or 0))

    -- Run details
    local details = runFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    details:SetPoint("TOPLEFT", 10, -35)

    local challengesSummary = string.format(
      "Character: %s\nCompleted Challenges: %d/6\nTotal Time: %s",
      run.character or "Unknown",
      run.completedChallenges or 0,
      self:FormatTime(run.totalTime or 0)
    )
    details:SetText(challengesSummary)

    -- Challenge details
    local chOffset = 90
    for j, challenge in ipairs(run.challenges or {}) do
      local status = challenge.success and "|cFF00FF00✓|r" or "|cFFFF0000✗|r"
      local challengeText = string.format(
        "%s %s: %d points",
        status,
        challenge.name or "Unknown",
        challenge.points or 0
      )

      local challengeDetail = runFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      challengeDetail:SetPoint("TOPLEFT", 25, -chOffset)
      challengeDetail:SetText(challengeText)

      chOffset = chOffset + 18
    end

    -- Update the run height based on content
    runHeight = math.max(runHeight, chOffset + 20)
    runFrame:SetHeight(runHeight)

    yOffset = yOffset + runHeight + 10
  end

  -- Update the content frame height
  tab.content:SetHeight(math.max(500, yOffset))
end

-- Show leaderboard for a specific challenge type
function GH.HighScorePanel:ShowLeaderboard(challengeType)
  local tab = self.frame.tabs.leaderboard
  if not tab or not tab.leaderboardContent then return end

  -- Clear previous content
  for _, child in pairs({ tab.leaderboardContent:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end

  -- Create leaderboard header
  local header = tab.leaderboardContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 0, 0)
  header:SetText(self:GetChallengeName(challengeType) .. " Leaderboard")

  -- Create column headers
  local columns = {
    { text = "Rank",      width = 50,  align = "LEFT" },
    { text = "Character", width = 150, align = "LEFT" },
    { text = "Points",    width = 80,  align = "RIGHT" },
    { text = "Progress",  width = 120, align = "RIGHT" },
    { text = "Date",      width = 100, align = "RIGHT" }
  }

  local xOffset = 10
  local headers = {}
  for i, col in ipairs(columns) do
    local colHeader = tab.leaderboardContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colHeader:SetWidth(col.width)
    colHeader:SetJustifyH(col.align)
    colHeader:SetPoint("TOPLEFT", xOffset, -30)
    colHeader:SetText(col.text)

    headers[i] = colHeader
    xOffset = xOffset + col.width + 5
  end

  -- Get and sort entries for this challenge type
  local entries = {}
  if GatherHeroDB and GatherHeroDB.highScores and GatherHeroDB.highScores.challengeRuns then
    for _, run in ipairs(GatherHeroDB.highScores.challengeRuns) do
      for _, challenge in ipairs(run.challenges or {}) do
        if challenge.type == challengeType then
          table.insert(entries, {
            character = run.character or "Unknown",
            points = challenge.points or 0,
            progress = challenge.progress or 0,
            goal = challenge.goal or 0,
            date = challenge.date or "",
            success = challenge.success or false,
            type = challenge.type
          })
          break
        end
      end
    end
  end

  -- Sort by points descending
  table.sort(entries, function(a, b) return (a.points or 0) > (b.points or 0) end)

  -- Show entries
  local yOffset = 50
  for i, entry in ipairs(entries) do
    if i > 20 then break end -- Limit to top 20

    -- Format progress based on challenge type
    local progressText = tostring(entry.progress)
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
      progressText = entry.progress .. " nodes"
    elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
      progressText = self:FormatGold(entry.progress)
    elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
      progressText = entry.progress .. " gathers"
    elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
      progressText = entry.progress .. " combat nodes"
    elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
      progressText = entry.progress .. " zones"
    elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
      progressText = self:FormatGold(entry.progress)
    end

    -- Color for rank
    local rankColor = "|cFFFFFFFF"
    if i == 1 then
      rankColor = "|cFFFFD700" -- Gold
    elseif i == 2 then
      rankColor = "|cFFC0C0C0" -- Silver
    elseif i == 3 then
      rankColor = "|cFFCD7F32" -- Bronze
    end

    -- Create row
    local row = {
      rankColor .. i .. "|r",
      entry.character,
      tostring(entry.points),
      progressText,
      self:GetShortDate(entry.date)
    }

    -- Display row
    xOffset = 10
    for j, text in ipairs(row) do
      local cell = tab.leaderboardContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      cell:SetWidth(columns[j].width)
      cell:SetJustifyH(columns[j].align)
      cell:SetPoint("TOPLEFT", xOffset, -yOffset)
      cell:SetText(text)

      xOffset = xOffset + columns[j].width + 5
    end

    yOffset = yOffset + 20
  end

  -- Show message if no entries
  if #entries == 0 then
    local noData = tab.leaderboardContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noData:SetPoint("CENTER", 0, 0)
    noData:SetText("No data available for this challenge type yet.")
  end
end

-- Update the entire panel
function GH.HighScorePanel:UpdatePanel()
  if not self.frame or not self.frame:IsShown() then return end

  -- Find which tab is currently shown
  for name, tab in pairs(self.frame.tabs) do
    if tab:IsShown() then
      if name == "summary" then
        self:UpdateSummaryTab()
      elseif name == "history" then
        self:UpdateHistoryTab()
      elseif name == "leaderboard" then
        -- Maintain current leaderboard view
      end
      break
    end
  end
end

-- Helper function to format time
function GH.HighScorePanel:FormatTime(seconds)
  local minutes = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)

  if minutes >= 60 then
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60
    return string.format("%d:%02d:%02d", hours, minutes, secs)
  else
    return string.format("%d:%02d", minutes, secs)
  end
end

-- Helper function to get short date
function GH.HighScorePanel:GetShortDate(dateString)
  if not dateString or dateString == "" then return "Unknown" end

  -- Extract date part only
  local datePart = dateString:match("(%d%d%d%d%-%d%d%-%d%d)")
  if datePart then
    return datePart
  end

  return dateString
end

-- Helper function to get challenge name
function GH.HighScorePanel:GetChallengeName(challengeType)
  if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
    return "Node Count"
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
    return "High Value Node"
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
    return "Timed Gather"
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    return "Combat Gather"
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
    return "Zone Hopper"
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
    return "Final Gold"
  else
    return "Unknown Challenge"
  end
end

-- Initialize
GH.HighScorePanel:Initialize()
