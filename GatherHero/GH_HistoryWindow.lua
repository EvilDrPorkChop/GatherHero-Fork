-- GH_HistoryWindow.lua
-- History window for Gather Hero

local _, GH = ...

-- Function to delete a session from history
function GH:DeleteHistorySession(sessionIndex)
  -- Create confirmation dialog
  StaticPopupDialogs["GH_CONFIRM_DELETE_SESSION"] = {
    text = "Delete this session record permanently?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
      -- Remove the session from the history table
      table.remove(GatherHeroDB.goldTracking.sessionHistory, sessionIndex)
      -- Update the display
      self:UpdateHistoryWindow()
      print("|cFF00FF00Gather Hero:|r Session record deleted.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  StaticPopup_Show("GH_CONFIRM_DELETE_SESSION")
end

-- Create and show the session history window
function GH:ShowHistoryWindow()
  -- If the window already exists, just show it
  if self.historyFrame and self.historyFrame:IsShown() then
    self.historyFrame:Hide()
    return
  elseif self.historyFrame then
    self.historyFrame:Show()
    self:UpdateHistoryWindow() -- Refresh the data
    return
  end

  -- Main frame
  local frame = CreateFrame("Frame", "GatherHeroHistory", UIParent, "BackdropTemplate")
  frame:SetSize(900, 500)
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
  title:SetText("Gather Hero - Session History")

  -- Close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", -5, -5)

  -- Create tab container
  local tabContainer = CreateFrame("Frame", nil, frame)
  tabContainer:SetSize(600, 30)
  tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 150, -30) -- Centered at top of window

  -- Create tab buttons
  local tabButtons = {}
  local tabs = {
    { text = "Session History", id = "history" },
    { text = "Metrics",         id = "metrics" }
  }

  -- Create tab content frames
  local tabFrames = {}
  local buttonWidth = 150

  for i, tab in ipairs(tabs) do
    local button = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
    button:SetSize(buttonWidth, 25)
    button:SetPoint("LEFT", tabContainer, "LEFT", (i - 1) * (buttonWidth + 10), 0)
    button:SetText(tab.text)

    -- Create content frame
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetSize(860, 380) -- Slightly smaller than the window
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -80)
    contentFrame:Hide()

    -- Store frame reference
    tabFrames[tab.id] = contentFrame

    -- Set click handler
    button:SetScript("OnClick", function()
      -- Hide all tabs
      for _, frame in pairs(tabFrames) do
        frame:Hide()
      end

      -- Show selected tab
      contentFrame:Show()

      -- Update button states
      for _, btn in ipairs(tabButtons) do
        btn:SetButtonState("NORMAL")
      end
      button:SetButtonState("PUSHED", true)

      -- Special handling for metrics tab
      if tab.id == "metrics" then
        self:PopulateMetricsTab(contentFrame)
      end
    end)

    table.insert(tabButtons, button)
  end

  -- Store tab references
  self.historyTabs = tabFrames
  self.historyTabButtons = tabButtons

  -- =========== HISTORY TAB SETUP ===========
  -- Create headers inside the history tab frame
  local headers = CreateFrame("Frame", nil, tabFrames.history)
  headers:SetPoint("TOPLEFT", tabFrames.history, "TOPLEFT", 0, 0)
  headers:SetPoint("TOPRIGHT", tabFrames.history, "TOPRIGHT", -20, 0)
  headers:SetHeight(30)

  -- Adjusted column widths
  local headersData = {
    { text = "Date",      width = 0.14 },
    { text = "Character", width = 0.11 },
    { text = "Zone",      width = 0.10 },
    { text = "WM",        width = 0.04 },
    { text = "Duration",  width = 0.09 },
    { text = "Gold",      width = 0.09 },
    { text = "GPH",       width = 0.09 },
    { text = "Per Node",  width = 0.09 },
    { text = "Nodes",     width = 0.07 },
    { text = "Actions",   width = 0.12 },
  }

  local prevHeaderText
  for i, header in ipairs(headersData) do
    local headerText = headers:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if i == 1 then
      headerText:SetPoint("TOPLEFT", headers, "TOPLEFT", 5, 0)
    else
      headerText:SetPoint("TOPLEFT", prevHeaderText, "TOPRIGHT", 10, 0)
    end
    headerText:SetWidth(header.width * (headers:GetWidth() - 20))
    headerText:SetJustifyH("CENTER")
    headerText:SetText(header.text)
    headerText:SetTextColor(1, 0.82, 0) -- Gold color
    prevHeaderText = headerText
  end

  -- Create scroll frame for history inside the history tab
  local scrollFrame = CreateFrame("ScrollFrame", "GatherHeroHistoryScroll", tabFrames.history,
    "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", headers, "BOTTOMLEFT", 0, -5)
  scrollFrame:SetPoint("BOTTOMRIGHT", tabFrames.history, "BOTTOMRIGHT", -20, 0)

  local content = CreateFrame("Frame", "GatherHeroHistoryContent", scrollFrame)
  content:SetWidth(scrollFrame:GetWidth()) -- Match the width to the scroll frame
  scrollFrame:SetScrollChild(content)

  -- Make frame draggable
  frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)

  -- Store references
  self.historyFrame = frame
  self.historyContent = content
  self.historyScrollFrame = scrollFrame
  self.historyHeaders = headers -- Store reference to headers

  -- Show the history tab by default
  tabFrames.history:Show()
  if tabButtons[1] then
    tabButtons[1]:SetButtonState("PUSHED", true)
  end

  -- Populate with data
  self:UpdateHistoryWindow()
end

-- Update the history window with latest data
function GH:UpdateHistoryWindow()
  if not self.historyFrame or not self.historyContent then return end

  -- Clear existing content
  for _, child in pairs({ self.historyContent:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end

  -- Check if we have history to display
  if not GatherHeroDB.goldTracking.sessionHistory or #GatherHeroDB.goldTracking.sessionHistory == 0 then
    local noDataText = self.historyContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noDataText:SetPoint("CENTER", 0, 0)
    noDataText:SetText("No session history available.")

    -- Set content height
    self.historyContent:SetHeight(50)
    return
  end

  -- Display history entries
  local yOffset = -25
  local rowHeight = 25
  local rowSpacing = 10


  -- Get the available width - make sure we set a proper width
  local contentWidth = self.historyContent:GetWidth() - 20 -- Account for margins

  for i, session in ipairs(GatherHeroDB.goldTracking.sessionHistory) do
    -- Create row container
    local row = CreateFrame("Frame", nil, self.historyContent)
    row:SetPoint("TOPLEFT", 0, yOffset)
    row:SetWidth(contentWidth)
    row:SetHeight(rowHeight)

    -- Alternate row colors
    if i % 2 == 0 then
      local bg = row:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
    end

    -- Adjusted column widths matching headers
    local columnWidths = {
      date = 0.14,
      char = 0.11,
      zone = 0.10,
      wm = 0.04,
      duration = 0.09,
      gold = 0.09,
      gph = 0.09,
      perNode = 0.09,
      nodes = 0.07,
      actions = 0.12
    }

    -- Date
    local dateText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dateText:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -5)
    dateText:SetWidth(columnWidths.date * contentWidth)
    dateText:SetJustifyH("CENTER")
    dateText:SetText(session.date or "Unknown")

    -- Character name
    local charName = session.character or (UnitName("player") .. "-" .. GetRealmName())
    local charText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    charText:SetPoint("TOPLEFT", dateText, "TOPRIGHT", 10, 0)
    charText:SetWidth(columnWidths.char * contentWidth)
    charText:SetJustifyH("CENTER")
    charText:SetText(charName)

    -- Zone
    local zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneText:SetPoint("TOPLEFT", charText, "TOPRIGHT", 10, 0)
    zoneText:SetWidth(columnWidths.zone * contentWidth)
    zoneText:SetJustifyH("CENTER")
    zoneText:SetText(session.zone or "Unknown")

    -- Warmode
    local warmodeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warmodeText:SetPoint("TOPLEFT", zoneText, "TOPRIGHT", 10, 0)
    warmodeText:SetWidth(columnWidths.wm * contentWidth)
    warmodeText:SetJustifyH("CENTER")

    -- Set text with color based on warmode status
    if session.warmode then
      warmodeText:SetText("On")
      warmodeText:SetTextColor(0, 1, 0) -- Green for On
    else
      warmodeText:SetText("Off")
      warmodeText:SetTextColor(1, 0.3, 0.3) -- Red for Off
    end

    -- Duration
    local durationText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    durationText:SetPoint("TOPLEFT", warmodeText, "TOPRIGHT", 10, 0)
    durationText:SetWidth(columnWidths.duration * contentWidth)
    durationText:SetJustifyH("CENTER")
    durationText:SetText(session.duration and self:FormatTime(session.duration) or "Unknown")

    -- Gold
    local goldAmount = session.gold and math.floor(session.gold / 10000) or 0
    local goldText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldText:SetPoint("TOPLEFT", durationText, "TOPRIGHT", 10, 0)
    goldText:SetWidth(columnWidths.gold * contentWidth)
    goldText:SetJustifyH("CENTER")
    goldText:SetText(goldAmount .. "g")

    -- Gold per hour
    local gphAmount = session.goldPerHour and math.floor(session.goldPerHour / 10000) or 0
    local gphText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gphText:SetPoint("TOPLEFT", goldText, "TOPRIGHT", 10, 0)
    gphText:SetWidth(columnWidths.gph * contentWidth)
    gphText:SetJustifyH("CENTER")
    gphText:SetText(gphAmount .. "g/hr")

    -- Gold per node
    local goldPerNode = 0
    if session.nodeCount and session.nodeCount > 0 then
      goldPerNode = session.gold / session.nodeCount
    end
    local goldPerNodeAmount = math.floor(goldPerNode / 100) / 100 -- Round to 2 decimal places
    local goldPerNodeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldPerNodeText:SetPoint("TOPLEFT", gphText, "TOPRIGHT", 10, 0)
    goldPerNodeText:SetWidth(columnWidths.perNode * contentWidth)
    goldPerNodeText:SetJustifyH("CENTER")
    goldPerNodeText:SetText(goldPerNodeAmount .. "g/node")

    -- Node count
    local nodeCount = session.nodeCount or 0
    local nodeCountText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nodeCountText:SetPoint("TOPLEFT", goldPerNodeText, "TOPRIGHT", 10, 0)
    nodeCountText:SetWidth(columnWidths.nodes * contentWidth)
    nodeCountText:SetJustifyH("CENTER")
    nodeCountText:SetText(nodeCount)

    -- Button dimensions
    local btnWidth = 36
    local btnHeight = 18
    local btnSpacing = 3

    -- Create a container for the buttons with fixed positioning
    local actionContainer = CreateFrame("Frame", nil, row)
    actionContainer:SetPoint("TOPLEFT", nodeCountText, "TOPRIGHT", 10, -3)
    actionContainer:SetSize((btnWidth * 2) + btnSpacing, btnHeight)

    -- Details button
    local detailsBtn = CreateFrame("Button", nil, actionContainer, "UIPanelButtonTemplate")
    detailsBtn:SetSize(btnWidth, btnHeight)
    detailsBtn:SetPoint("LEFT", 0, 0)
    detailsBtn:SetText("Info")

    -- Delete button
    local deleteBtn = CreateFrame("Button", nil, actionContainer, "UIPanelButtonTemplate")
    deleteBtn:SetSize(btnWidth, btnHeight)
    deleteBtn:SetPoint("LEFT", detailsBtn, "RIGHT", btnSpacing, 0)
    deleteBtn:SetText("Del")

    -- Make the delete button text red
    local deleteFont = deleteBtn:GetFontString()
    if deleteFont then
      deleteFont:SetTextColor(1, 0.3, 0.3)
    end

    -- Set up button actions
    detailsBtn:SetScript("OnClick", function()
      self:ShowSessionDetailsWindow(session)
    end)

    deleteBtn:SetScript("OnClick", function()
      self:DeleteHistorySession(i)
    end)

    yOffset = yOffset - rowHeight - rowSpacing
  end

  -- Set content height
  local totalHeight = math.abs(yOffset) + 20
  self.historyContent:SetHeight(totalHeight)

  -- Make sure the parent ScrollFrame has a proper SetScrollChild call
  local scrollFrame = self.historyContent:GetParent()
  if scrollFrame and scrollFrame:IsObjectType("ScrollFrame") then
    scrollFrame:UpdateScrollChildRect()
  end
end

-- Add character name to the saved session data
function GH:AddCharacterToSession(sessionData)
  -- Make sure sessionData exists
  if not sessionData then return sessionData end

  -- Add character name to the session data
  sessionData.character = UnitName("player") .. "-" .. GetRealmName()

  return sessionData
end

-- Call this function when loading to update old session records
function GH:UpdateOldSessionRecords()
  if not GatherHeroDB or not GatherHeroDB.goldTracking or
      not GatherHeroDB.goldTracking.sessionHistory then
    return
  end

  local currentChar = UnitName("player") .. "-" .. GetRealmName()

  for i, session in ipairs(GatherHeroDB.goldTracking.sessionHistory) do
    if not session.character then
      session.character = currentChar
    end
  end
end
