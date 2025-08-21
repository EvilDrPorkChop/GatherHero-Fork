-- GH_SessionDetails.lua
-- Detailed session breakdown window for Gather Hero

local _, GH = ...

-- Show detailed breakdown for a specific session
function GH:ShowSessionDetailsWindow(session)
  if not session then
    print("|cFFFF0000GatherHero:|r Invalid session data.")
    return
  end

  -- If the window already exists, close it
  if self.detailsFrame and self.detailsFrame:IsShown() then
    self.detailsFrame:Hide()
    self.detailsFrame = nil
    return
  end

  -- Create main frame
  local frame = CreateFrame("Frame", "GatherHeroDetailsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(800, 600)
  frame:SetPoint("CENTER", UIParent, "CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(100)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")

  -- Enable mouse to prevent click-through
  frame:EnableMouse(true)

  -- Background and border - fully opaque
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1.0) -- Fully opaque
  else
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0, 0, 0, 1.0) -- Fully opaque background

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
  title:SetText("Session Details: " .. (session.date or "Unknown"))

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

  -- Session summary section
  local summaryFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  summaryFrame:SetSize(760, 120)
  summaryFrame:SetPoint("TOP", frame, "TOP", 0, -50)

  if summaryFrame.SetBackdrop then
    summaryFrame:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    summaryFrame:SetBackdropColor(0.1, 0.1, 0.1, 1.0) -- Fully opaque
    summaryFrame:SetBackdropBorderColor(0.8, 0.8, 0.5, 0.7)
  end

  -- Session summary title
  local summaryTitle = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  summaryTitle:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", 15, -15)
  summaryTitle:SetText("Session Summary")
  summaryTitle:SetTextColor(1, 0.82, 0)

  -- Format summary data
  local goldAmount = math.floor((session.gold or 0) / 10000)
  local gphAmount = math.floor((session.goldPerHour or 0) / 10000)
  local goldPerNode = 0
  if session.nodeCount and session.nodeCount > 0 then
    goldPerNode = (session.gold or 0) / session.nodeCount
    goldPerNode = math.floor(goldPerNode / 100) / 100 -- Round to 2 decimal places
  end

  -- Analyze session professions if not already done
  if not session.professionTypes then
    self:AnalyzeSessionProfessions(session)
  end

  -- Format profession string
  local professionStr = ""
  if session.professionTypes and #session.professionTypes > 0 then
    -- Build a string showing all professions with percentages
    for i, prof in ipairs(session.professionTypes) do
      if i > 1 then
        professionStr = professionStr .. ", "
      end
      professionStr = professionStr .. string.format("%s (%.1f%%)", prof.name, prof.percentage)
    end
  else
    professionStr = session.professionType or "Unknown"
  end

  -- Create summary lines
  local summaryLines = {
    { label = "Character:",     value = session.character or "Unknown" },
    { label = "Zone:",          value = session.zone or "Unknown" },
    { label = "War Mode:",      value = session.warmode and "On" or "Off" },
    { label = "Duration:",      value = session.duration and self:FormatTime(session.duration) or "Unknown" },
    { label = "Total Gold:",    value = goldAmount .. "g" },
    { label = "Gold Per Hour:", value = gphAmount .. "g/hr" },
    { label = "Total Nodes:",   value = session.nodeCount or 0 },
    { label = "Gold Per Node:", value = goldPerNode .. "g" },
    { label = "Profession:",    value = professionStr }
  }

  -- Layout summary data in 3 columns with fixed widths to prevent overlap
  local cols = 3
  local colWidth = 240
  local lineHeight = 20
  local startY = -45
  local labelWidth = 100

  for i, data in ipairs(summaryLines) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)

    local labelText = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", 20 + (col * colWidth), startY - (row * lineHeight))
    labelText:SetText(data.label)
    labelText:SetTextColor(1, 1, 1)

    local valueText = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPLEFT", labelText, "TOPLEFT", labelWidth, 0)
    valueText:SetWidth(colWidth - labelWidth - 20)
    valueText:SetText(data.value)
    valueText:SetJustifyH("LEFT")
  end

  -- Create tabs
  local tabs = {}
  local tabFrames = {}
  local tabButtons = {}
  local tabHeight = 400

  -- Create tab container
  local tabContainer = CreateFrame("Frame", nil, frame)
  tabContainer:SetSize(760, tabHeight)
  tabContainer:SetPoint("TOP", summaryFrame, "BOTTOM", 0, -20)

  -- Define tabs
  tabs = {
    { name = "Items",       id = "items" },
    { name = "Professions", id = "professions" },
    { name = "Zones",       id = "zones" }
  }

  -- Create tab buttons
  local tabButtonWidth = 100
  local tabButtonHeight = 30
  local tabButtonSpacing = 5

  for i, tab in ipairs(tabs) do
    -- Create tab button
    local button = CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
    button:SetSize(tabButtonWidth, tabButtonHeight)
    button:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 10 + ((i - 1) * (tabButtonWidth + tabButtonSpacing)), 0)
    button:SetText(tab.name)

    -- Create tab frame
    local tabFrame = CreateFrame("Frame", nil, tabContainer, "BackdropTemplate")
    tabFrame:SetSize(760, tabHeight - tabButtonHeight - 10)
    tabFrame:SetPoint("TOP", tabContainer, "TOP", 0, -tabButtonHeight - 5)

    -- Make sure each tabFrame also blocks mouse events
    tabFrame:EnableMouse(true)

    if tabFrame.SetBackdrop then
      tabFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
      tabFrame:SetBackdropColor(0.1, 0.1, 0.1, 1.0)
      tabFrame:SetBackdropBorderColor(0.8, 0.8, 0.5, 0.7)
    end

    tabFrame:Hide() -- Hide all tabs initially

    tabFrames[tab.id] = tabFrame
    tabButtons[i] = button

    -- Tab button click handler
    button:SetScript("OnClick", function()
      -- Hide all tab frames
      for _, frame in pairs(tabFrames) do
        frame:Hide()
      end

      -- Reset all button textures
      for _, btn in ipairs(tabButtons) do
        btn:SetButtonState("NORMAL")
      end

      -- Show selected tab
      tabFrame:Show()
      button:SetButtonState("PUSHED", true)
    end)
  end

  -- Populate the Items tab
  if tabFrames.items then
    self:PopulateItemsTab(tabFrames.items, session)
  end

  -- Populate the NEW Professions tab
  if tabFrames.professions then
    self:PopulateProfessionsTab(tabFrames.professions, session)
  end

  -- Populate the Zones tab
  if tabFrames.zones then
    self:PopulateZonesTab(tabFrames.zones, session)
  end

  -- Show first tab by default
  if tabButtons[1] then
    tabButtons[1]:Click()
  end

  -- Store references
  self.detailsFrame = frame
end

-- Add a new tab to session details for profession breakdown
function GH:PopulateProfessionsTab(frame, session)
  if not frame or not session then return end

  -- Ensure we've analyzed the session's professions
  if not session.professionTypes then
    self:AnalyzeSessionProfessions(session)
  end

  -- Check if we have profession data
  if not session.professionBreakdown or not next(session.professionBreakdown) then
    local noDataText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noDataText:SetPoint("CENTER", frame, "CENTER")
    noDataText:SetText("No detailed profession data available for this session.")
    noDataText:SetTextColor(1, 0.5, 0.5)
    return
  end

  -- Create scrollable area for professions
  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(scrollFrame:GetWidth(), 1)
  scrollFrame:SetScrollChild(content)

  -- Enable mouse on content to prevent click-through
  content:EnableMouse(true)

  -- Create headers
  local headers = {
    { text = "Profession", width = 0.4 },
    { text = "Gold",       width = 0.2 },
    { text = "% of Total", width = 0.2 },
    { text = "Est. Nodes", width = 0.2 }
  }

  local headerY = -5
  local prevHeader

  for i, header in ipairs(headers) do
    local headerText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if i == 1 then
      headerText:SetPoint("TOPLEFT", content, "TOPLEFT", 5, headerY)
    else
      headerText:SetPoint("TOPLEFT", prevHeader, "TOPRIGHT", 10, 0)
    end
    headerText:SetWidth(header.width * (content:GetWidth() - 40))
    headerText:SetJustifyH("CENTER")
    headerText:SetText(header.text)
    headerText:SetTextColor(1, 0.82, 0) -- Gold color
    prevHeader = headerText
  end

  -- Sort professions by gold amount
  local sortedProfessions = {}
  for profName, goldAmount in pairs(session.professionBreakdown) do
    -- Only include professions with gold value
    if goldAmount > 0 then
      -- Calculate percentage
      local percentOfTotal = 0
      if session.gold and session.gold > 0 then
        percentOfTotal = (goldAmount / session.gold) * 100
      end

      -- Calculate estimated nodes
      local estNodes = 0
      if session.nodeCount and session.gold and session.gold > 0 then
        estNodes = session.nodeCount * (goldAmount / session.gold)
      end

      table.insert(sortedProfessions, {
        profession = profName,
        gold = goldAmount,
        percent = percentOfTotal,
        nodes = estNodes
      })
    end
  end

  table.sort(sortedProfessions, function(a, b)
    return a.gold > b.gold
  end)

  -- Display professions
  local profY = -30
  local rowHeight = 25
  local rowSpacing = 5

  -- Colors for different professions
  local professionColors = {
    ["Herbalism"] = { r = 0.2, g = 0.8, b = 0.2 }, -- Green
    ["Mining"] = { r = 0.8, g = 0.6, b = 0.0 },    -- Orange-brown
    ["Skinning"] = { r = 0.6, g = 0.4, b = 0.2 },  -- Brown
    ["Fishing"] = { r = 0.2, g = 0.6, b = 0.8 },   -- Blue
    ["Unknown"] = { r = 0.5, g = 0.5, b = 0.5 }    -- Gray
  }

  for i, profData in ipairs(sortedProfessions) do
    -- Calculate values
    local goldAmount = math.floor(profData.gold / 10000)

    -- Profession name with colored text
    local profText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    profText:SetPoint("TOPLEFT", content, "TOPLEFT", 5, profY)
    profText:SetWidth(headers[1].width * (content:GetWidth() - 40))
    profText:SetJustifyH("LEFT")
    profText:SetText(profData.profession)

    -- Set profession color
    local color = professionColors[profData.profession] or professionColors["Unknown"]
    profText:SetTextColor(color.r, color.g, color.b)

    -- Gold amount
    local goldText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldText:SetPoint("TOPLEFT", profText, "TOPRIGHT", 10, 0)
    goldText:SetWidth(headers[2].width * (content:GetWidth() - 40))
    goldText:SetJustifyH("CENTER")
    goldText:SetText(goldAmount .. "g")

    -- Percent of total
    local percentText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    percentText:SetPoint("TOPLEFT", goldText, "TOPRIGHT", 10, 0)
    percentText:SetWidth(headers[3].width * (content:GetWidth() - 40))
    percentText:SetJustifyH("CENTER")
    percentText:SetText(string.format("%.2f%%", profData.percent))

    -- Estimated nodes
    local nodesText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nodesText:SetPoint("TOPLEFT", percentText, "TOPRIGHT", 10, 0)
    nodesText:SetWidth(headers[4].width * (content:GetWidth() - 40))
    nodesText:SetJustifyH("CENTER")
    nodesText:SetText(string.format("%.1f", profData.nodes))

    -- Update position for next row
    profY = profY - rowHeight - rowSpacing
  end

  -- Set content height
  content:SetHeight(math.abs(profY) + 20)

  -- Add pie chart visualization
  if #sortedProfessions > 1 then
    -- Create a simple bar chart visualization
    local chartFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    chartFrame:SetSize(content:GetWidth() - 40, 150)
    chartFrame:SetPoint("TOP", content, "TOP", 0, profY - 30)

    if chartFrame.SetBackdrop then
      chartFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
      chartFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.3)
      chartFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    end

    local chartTitle = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chartTitle:SetPoint("TOP", chartFrame, "TOP", 0, -5)
    chartTitle:SetText("Profession Breakdown")

    -- Draw simple horizontal bars
    local barHeight = 20
    local barGap = 5
    local barMaxWidth = chartFrame:GetWidth() - 100
    local startX = 50
    local startY = -30

    for i, profData in ipairs(sortedProfessions) do
      local yPos = startY - ((i - 1) * (barHeight + barGap))

      -- Label
      local labelText = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      labelText:SetPoint("TOPLEFT", chartFrame, "TOPLEFT", 5, yPos)
      labelText:SetText(profData.profession)

      local color = professionColors[profData.profession] or professionColors["Unknown"]

      -- Bar background
      local barBg = chartFrame:CreateTexture(nil, "ARTWORK")
      barBg:SetSize(barMaxWidth, barHeight)
      barBg:SetPoint("TOPLEFT", chartFrame, "TOPLEFT", startX, yPos)
      barBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)

      -- Bar fill
      local barWidth = (profData.percent / 100) * barMaxWidth
      local barFill = chartFrame:CreateTexture(nil, "ARTWORK")
      barFill:SetSize(barWidth, barHeight)
      barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 0)
      barFill:SetColorTexture(color.r, color.g, color.b, 0.7)

      -- Percentage text
      local percentText = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      percentText:SetPoint("LEFT", barFill, "RIGHT", 5, 0)
      percentText:SetText(string.format("%.1f%%", profData.percent))
    end

    -- Update content height to include the chart
    content:SetHeight(content:GetHeight() + chartFrame:GetHeight() + 40)
  end
end

-- Populate the items tab
function GH:PopulateItemsTab(frame, session)
  if not frame or not session then return end

  -- Create scrollable area for items
  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(scrollFrame:GetWidth(), 1)
  scrollFrame:SetScrollChild(content)

  -- Enable mouse on content to prevent click-through
  content:EnableMouse(true)

  -- Create headers
  local headers = {
    { text = "Item",        width = 0.35 },
    { text = "Count",       width = 0.10 },
    { text = "Unit Value",  width = 0.15 },
    { text = "Total Value", width = 0.20 },
    { text = "% of Total",  width = 0.20 }
  }

  local headerY = -5
  local prevHeader

  for i, header in ipairs(headers) do
    local headerText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if i == 1 then
      headerText:SetPoint("TOPLEFT", content, "TOPLEFT", 5, headerY)
    else
      headerText:SetPoint("TOPLEFT", prevHeader, "TOPRIGHT", 10, 0)
    end
    headerText:SetWidth(header.width * (content:GetWidth() - 40))
    headerText:SetJustifyH("CENTER")
    headerText:SetText(header.text)
    headerText:SetTextColor(1, 0.82, 0) -- Gold color
    prevHeader = headerText
  end

  -- Check if we have item data
  if not session.items or not next(session.items) then
    local noDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noDataText:SetPoint("TOP", content, "TOP", 0, -50)
    noDataText:SetText("No detailed item data available for this session.")
    noDataText:SetTextColor(1, 0.5, 0.5)
    content:SetHeight(100)
    return
  end

  -- Sort items by value (highest to lowest)
  local sortedItems = {}
  for itemLink, itemData in pairs(session.items) do
    table.insert(sortedItems, { link = itemLink, data = itemData })
  end

  table.sort(sortedItems, function(a, b)
    return (a.data.value or 0) > (b.data.value or 0)
  end)

  -- Display items
  local itemY = -30
  local rowHeight = 20
  local rowSpacing = 2

  for i, item in ipairs(sortedItems) do
    local itemData = item.data
    local itemLink = item.link

    -- Only process items with a name
    if itemData.name then
      -- Calculate values for display
      local unitValue = math.floor((itemData.unitValue or 0) / 100) / 100
      local totalValue = math.floor((itemData.value or 0) / 10000)
      local percentOfTotal = 0
      if session.gold and session.gold > 0 then
        percentOfTotal = math.floor(((itemData.value or 0) / session.gold) * 10000) / 100
      end

      -- Item name/icon
      local nameText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      nameText:SetPoint("TOPLEFT", content, "TOPLEFT", 5, itemY)
      nameText:SetWidth(headers[1].width * (content:GetWidth() - 40))
      nameText:SetJustifyH("LEFT")

      -- Use item link if possible
      if itemData.itemID then
        local itemName, _, itemQuality = GetItemInfo(itemData.itemID)
        if itemName then
          nameText:SetText(itemLink)
        else
          nameText:SetText(itemData.name or "Unknown Item")
        end
      else
        nameText:SetText(itemData.name or "Unknown Item")
      end

      -- Color based on quality if available
      if itemData.quality then
        local r, g, b = GetItemQualityColor(itemData.quality)
        nameText:SetTextColor(r, g, b)
      end

      -- Count
      local countText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      countText:SetPoint("TOPLEFT", nameText, "TOPRIGHT", 10, 0)
      countText:SetWidth(headers[2].width * (content:GetWidth() - 40))
      countText:SetJustifyH("CENTER")
      countText:SetText(itemData.count or 0)

      -- Unit value
      local unitValueText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      unitValueText:SetPoint("TOPLEFT", countText, "TOPRIGHT", 10, 0)
      unitValueText:SetWidth(headers[3].width * (content:GetWidth() - 40))
      unitValueText:SetJustifyH("CENTER")
      unitValueText:SetText(string.format("%.2fg", unitValue))

      -- Total value
      local valueText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      valueText:SetPoint("TOPLEFT", unitValueText, "TOPRIGHT", 10, 0)
      valueText:SetWidth(headers[4].width * (content:GetWidth() - 40))
      valueText:SetJustifyH("CENTER")
      valueText:SetText(totalValue .. "g")

      -- Percent of total
      local percentText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      percentText:SetPoint("TOPLEFT", valueText, "TOPRIGHT", 10, 0)
      percentText:SetWidth(headers[5].width * (content:GetWidth() - 40))
      percentText:SetJustifyH("CENTER")
      percentText:SetText(string.format("%.2f%%", percentOfTotal))

      -- Update position for next item
      itemY = itemY - rowHeight - rowSpacing
    end
  end

  -- Set content height
  content:SetHeight(math.abs(itemY) + 20)
end

-- Populate the zones tab
function GH:PopulateZonesTab(frame, session)
  if not frame or not session then return end

  -- Check if we have zone data
  if not session.zoneBreakdown or not next(session.zoneBreakdown) then
    local noDataText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noDataText:SetPoint("CENTER", frame, "CENTER")
    noDataText:SetText("No detailed zone data available for this session.")
    noDataText:SetTextColor(1, 0.5, 0.5)
    return
  end

  -- Create scrollable area for zones
  local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(scrollFrame:GetWidth(), 1)
  scrollFrame:SetScrollChild(content)

  -- Enable mouse on content to prevent click-through
  content:EnableMouse(true)

  -- Create headers
  local headers = {
    { text = "Zone",       width = 0.5 },
    { text = "Gold",       width = 0.25 },
    { text = "% of Total", width = 0.25 }
  }

  local headerY = -5
  local prevHeader

  for i, header in ipairs(headers) do
    local headerText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if i == 1 then
      headerText:SetPoint("TOPLEFT", content, "TOPLEFT", 5, headerY)
    else
      headerText:SetPoint("TOPLEFT", prevHeader, "TOPRIGHT", 10, 0)
    end
    headerText:SetWidth(header.width * (content:GetWidth() - 40))
    headerText:SetJustifyH("CENTER")
    headerText:SetText(header.text)
    headerText:SetTextColor(1, 0.82, 0) -- Gold color
    prevHeader = headerText
  end

  -- Sort zones by gold amount
  local sortedZones = {}
  for zoneName, goldAmount in pairs(session.zoneBreakdown) do
    table.insert(sortedZones, { zone = zoneName, gold = goldAmount })
  end

  table.sort(sortedZones, function(a, b)
    return a.gold > b.gold
  end)

  -- Display zones
  local zoneY = -30
  local rowHeight = 25
  local rowSpacing = 5

  for i, zoneData in ipairs(sortedZones) do
    -- Calculate values
    local goldAmount = math.floor(zoneData.gold / 10000)
    local percentOfTotal = 0
    if session.gold and session.gold > 0 then
      percentOfTotal = math.floor((zoneData.gold / session.gold) * 10000) / 100
    end

    -- Zone name
    local zoneText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    zoneText:SetPoint("TOPLEFT", content, "TOPLEFT", 5, zoneY)
    zoneText:SetWidth(headers[1].width * (content:GetWidth() - 40))
    zoneText:SetJustifyH("LEFT")
    zoneText:SetText(zoneData.zone)

    -- Gold amount
    local goldText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goldText:SetPoint("TOPLEFT", zoneText, "TOPRIGHT", 10, 0)
    goldText:SetWidth(headers[2].width * (content:GetWidth() - 40))
    goldText:SetJustifyH("CENTER")
    goldText:SetText(goldAmount .. "g")

    -- Percent of total
    local percentText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    percentText:SetPoint("TOPLEFT", goldText, "TOPRIGHT", 10, 0)
    percentText:SetWidth(headers[3].width * (content:GetWidth() - 40))
    percentText:SetJustifyH("CENTER")
    percentText:SetText(string.format("%.2f%%", percentOfTotal))

    -- Update position for next row
    zoneY = zoneY - rowHeight - rowSpacing
  end

  -- Set content height
  content:SetHeight(math.abs(zoneY) + 20)
end
