-- GH_MetricsPanel.lua - Final fixed version with all errors resolved

local _, GH = ...

-- Add metrics tab to the existing history window
function GH:InitializeMetricsTab()
  -- If history window doesn't exist yet, do nothing
  if not self.historyFrame then return end

  -- If metrics tab already initialized, do nothing
  if self.metricsTabInitialized then return end

  -- Remove any old "Show Metrics" button from previous version
  if self.historyFrame.metricsButton then
    self.historyFrame.metricsButton:Hide()
    self.historyFrame.metricsButton = nil
  end

  -- Metrics tab should already be created by ShowHistoryWindow
  -- We just need to make sure our tab objects exist
  if not self.historyTabs or not self.historyTabs.metrics then
    -- Log an error if the tab structure is not as expected
    if self.debugMode then
      print("|cFFFF0000Gather Hero Error:|r Metrics tab frame not found.")
    end
    return
  end

  self.metricsTabInitialized = true
end

-- Populate the metrics tab with period selector and content
function GH:PopulateMetricsTab(frame)
  -- Clear previous content more thoroughly
  for _, child in pairs({ frame:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end

  -- Create time period selector
  local periodSelector = CreateFrame("Frame", "GH_MetricsPeriodSelector", frame)
  periodSelector:SetSize(frame:GetWidth() - 20, 30)
  periodSelector:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)

  -- Create period buttons
  local periodButtons = {}
  local periods = {
    { text = "Daily",    id = "daily" },
    { text = "Weekly",   id = "weekly" },
    { text = "Monthly",  id = "monthly" },
    { text = "All Time", id = "alltime" }
  }

  -- Create content frames for each period
  local periodFrames = {}
  local buttonWidth = 100

  for i, period in ipairs(periods) do
    local button = CreateFrame("Button", "GH_MetricsPeriodButton_" .. period.id, periodSelector, "UIPanelButtonTemplate")
    button:SetSize(buttonWidth, 25)
    button:SetPoint("LEFT", periodSelector, "LEFT", (i - 1) * (buttonWidth + 5), 0)
    button:SetText(period.text)

    -- Create content frame with a unique name
    local contentFrame = CreateFrame("Frame", "GH_MetricsPeriodContent_" .. period.id, frame)
    contentFrame:SetSize(frame:GetWidth() - 20, frame:GetHeight() - 50)
    contentFrame:SetPoint("TOPLEFT", periodSelector, "BOTTOMLEFT", 0, -10)
    contentFrame:Hide()

    -- Store frame reference
    periodFrames[period.id] = contentFrame

    -- Set click handler
    button:SetScript("OnClick", function()
      -- Hide all period frames
      for _, pframe in pairs(periodFrames) do
        pframe:Hide()
      end

      -- Show selected period
      contentFrame:Show()

      -- Update button states
      for _, btn in ipairs(periodButtons) do
        btn:SetButtonState("NORMAL")
      end
      button:SetButtonState("PUSHED", true)

      -- IMPORTANT: Clear the content frame before calculating metrics
      for _, child in pairs({ contentFrame:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
      end

      -- Calculate metrics for the period using pcall to catch errors
      local success, errorMessage = pcall(function()
        self:CalculateMetrics(period.id, contentFrame)
      end)

      if not success then
        -- Create error message if calculation fails
        local errorText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        errorText:SetPoint("CENTER", contentFrame, "CENTER")
        errorText:SetText("Error calculating metrics: " .. (errorMessage or "Unknown error"))

        if self.debugMode then
          print("|cFFFF0000Gather Hero Error:|r", errorMessage)
        end
      end
    end)

    table.insert(periodButtons, button)
  end

  -- Store references
  self.metricsPeriodFrames = periodFrames
  self.metricsPeriodButtons = periodButtons

  -- Select daily by default
  if periodButtons[1] then
    periodButtons[1]:Click()
  end
end

-- Improved CalculateMetrics function with better cleanup and two-column profession display
-- Improved CalculateMetrics function with better cleanup
function GH:CalculateMetrics(timePeriod, frame)
  -- Clear previous content thoroughly
  for _, child in pairs({ frame:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end

  -- Create a new scroll frame each time to avoid issues with reuse
  local scrollFrame = CreateFrame("ScrollFrame", "GH_MetricsScrollFrame_" .. timePeriod, frame,
    "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 0)

  local content = CreateFrame("Frame", "GH_MetricsContent_" .. timePeriod, scrollFrame)
  content:SetSize(scrollFrame:GetWidth(), 800) -- Start with a default height
  scrollFrame:SetScrollChild(content)

  -- Check if we have session history to analyze
  if not GatherHeroDB or not GatherHeroDB.goldTracking or not GatherHeroDB.goldTracking.sessionHistory or #GatherHeroDB.goldTracking.sessionHistory == 0 then
    local noDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noDataText:SetPoint("CENTER", content, "CENTER")
    noDataText:SetText("No session history available to calculate metrics.")
    content:SetHeight(100)
    return
  end

  -- Get the timestamp range based on selected time period
  local currentTime = time()
  local startTime = 0 -- Default to all time

  if timePeriod == "daily" then
    -- Last 24 hours
    startTime = currentTime - (24 * 60 * 60)
  elseif timePeriod == "weekly" then
    -- Last 7 days
    startTime = currentTime - (7 * 24 * 60 * 60)
  elseif timePeriod == "monthly" then
    -- Last 30 days
    startTime = currentTime - (30 * 24 * 60 * 60)
  end

  -- Filter sessions based on time period
  local filteredSessions = {}
  for _, session in ipairs(GatherHeroDB.goldTracking.sessionHistory) do
    -- Convert session date string to timestamp for comparison
    local sessionTime = self:DateStringToTimestamp(session.date)
    if sessionTime and sessionTime >= startTime then
      table.insert(filteredSessions, session)
    end
  end

  -- If no sessions in the time period
  if #filteredSessions == 0 then
    local noDataText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noDataText:SetPoint("CENTER", content, "CENTER")
    noDataText:SetText("No gathering sessions found for this time period.")
    content:SetHeight(100)
    return
  end

  -- Calculate overall metrics
  local metrics = self:CalculateOverallMetrics(filteredSessions)

  -- Create header
  local headerText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  headerText:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)

  -- Set appropriate header based on time period
  local periodTitle
  if timePeriod == "daily" then
    periodTitle = "Last 24 Hours"
  elseif timePeriod == "weekly" then
    periodTitle = "Last 7 Days"
  elseif timePeriod == "monthly" then
    periodTitle = "Last 30 Days"
  else
    periodTitle = "All Time"
  end

  headerText:SetText(periodTitle .. " Gathering Metrics")

  -- Create summary section - ADJUSTED POSITION
  local summaryFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
  summaryFrame:SetSize(content:GetWidth() - 30, 200)
  summaryFrame:SetPoint("TOPLEFT", headerText, "BOTTOMLEFT", 0, -10)

  if summaryFrame.SetBackdrop then
    summaryFrame:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    summaryFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
    summaryFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
  end

  -- Summary title
  local summaryTitle = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  summaryTitle:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", 15, -15)
  summaryTitle:SetText("Summary")
  summaryTitle:SetTextColor(1, 0.82, 0) -- Gold color

  -- Display metrics in a table format - FIXED POSITIONING
  local y = -120 -- Changed from -40 to -90 to push text down significantly
  local statGap = 20
  local colWidth = 320
  local rowsPerCol = 5
  local leftMargin = 30

  local stats = {
    { label = "Total Gold Earned:",      value = self:FormatGold(metrics.totalGold) },
    { label = "Total Gathering Time:",   value = self:FormatTime(metrics.totalTime) },
    { label = "Average Gold Per Hour:",  value = self:FormatGold(metrics.avgGoldPerHour) .. "/hr" },
    { label = "Total Nodes Gathered:",   value = metrics.totalNodes },
    { label = "Average Gold Per Node:",  value = self:FormatGold(metrics.avgGoldPerNode) .. "/node" },
    { label = "Best Gold Per Hour:",     value = self:FormatGold(metrics.bestGoldPerHour) .. "/hr" },
    { label = "Best Session Gold:",      value = self:FormatGold(metrics.bestSessionGold) },
    { label = "Number of Sessions:",     value = #filteredSessions },
    { label = "Average Session Length:", value = self:FormatTime(metrics.avgSessionLength) },
    { label = "Average Session Gold:",   value = self:FormatGold(metrics.avgSessionGold) }
  }

  -- Create a separate container for stats inside the summary frame
  local statsContainer = CreateFrame("Frame", nil, summaryFrame)
  statsContainer:SetSize(summaryFrame:GetWidth() - 20, 160)
  statsContainer:SetPoint("TOPLEFT", summaryTitle, "BOTTOMLEFT", 0, -10) -- Position below the title

  for i, stat in ipairs(stats) do
    local col = math.floor((i - 1) / rowsPerCol)
    local row = (i - 1) % rowsPerCol

    local labelText = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", summaryFrame, "TOPLEFT", leftMargin + (col * colWidth), y + (row * statGap))
    labelText:SetText(stat.label)

    local valueText = summaryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPLEFT", labelText, "TOPLEFT", 170, 0)
    valueText:SetText(tostring(stat.value or "--"))
  end


  -- Check if we have profession data before creating the profession breakdown
  local hasProfessionData = false

  if metrics.professionStats then
    for profession, data in pairs(metrics.professionStats) do
      if profession ~= "Unknown" and (data.gold or 0) > 0 then
        hasProfessionData = true
        break
      end
    end
  end

  -- Create profession breakdown if we have data
  if hasProfessionData then
    local professionFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    professionFrame:SetSize(content:GetWidth() - 30, 230) -- Increased height for pie chart
    professionFrame:SetPoint("TOPLEFT", summaryFrame, "BOTTOMLEFT", 0, -20)

    if professionFrame.SetBackdrop then
      professionFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
      })
      professionFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
      professionFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    end

    local professionTitle = professionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    professionTitle:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 15, -15)
    professionTitle:SetText("Profession Breakdown")
    professionTitle:SetTextColor(1, 0.82, 0) -- Gold color

    -- Create simple bar-based breakdown (restored)
    local barChartContainer = CreateFrame("Frame", nil, professionFrame)
    barChartContainer:SetSize(500, 150)
    barChartContainer:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 30, -40)

    -- Colors for different professions
    local professionColors = {
      ["Herbalism"] = { r = 0.2, g = 0.8, b = 0.2 }, -- Green
      ["Mining"] = { r = 0.8, g = 0.6, b = 0.0 },    -- Orange-brown
      ["Skinning"] = { r = 0.6, g = 0.4, b = 0.2 },  -- Brown
      ["Fishing"] = { r = 0.2, g = 0.6, b = 0.8 },   -- Blue
      ["Other"] = { r = 0.5, g = 0.5, b = 0.5 }      -- Gray for Other (changed from Unknown)
    }

    -- Calculate percentages and determine "Other" gold
    local professions = {}
    local totalGold = metrics.totalGold or 1 -- Prevent division by zero
    if totalGold <= 0 then totalGold = 1 end -- Extra safety

    local knownProfessionGold = 0

    -- First pass: calculate known profession gold
    for profession, data in pairs(metrics.professionStats) do
      if profession ~= "Unknown" and profession ~= "Other" then -- Skip "Unknown" category
        local gold = data.gold or 0
        if gold > 0 then
          knownProfessionGold = knownProfessionGold + gold
          table.insert(professions, {
            name = profession,
            gold = gold,
            percent = (gold / totalGold) * 100,
            color = professionColors[profession] or { r = 0.5, g = 0.5, b = 0.5 }
          })
        end
      end
    end

    -- Add "Other" gold (including Unknown gold) as the difference
    local otherGold = totalGold - knownProfessionGold
    if otherGold > 0 then
      table.insert(professions, {
        name = "Other",
        gold = otherGold,
        percent = (otherGold / totalGold) * 100,
        color = professionColors["Other"]
      })
    end

    -- Sort professions by gold amount (descending)
    table.sort(professions, function(a, b) return a.gold > b.gold end)

    -- Draw horizontal bars (restored from original)
    local barHeight = 25
    local barGap = 5
    local barMaxWidth = 300

    -- First, find the longest profession name to properly align all bars
    local maxNameWidth = 0
    for _, profession in ipairs(professions) do
      -- Create a temporary fontstring to measure text width
      local tempText = barChartContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      tempText:SetText(profession.name)
      local width = tempText:GetStringWidth()
      if width > maxNameWidth then
        maxNameWidth = width
      end
      tempText:Hide()
    end

    -- Add some padding
    maxNameWidth = maxNameWidth + 10

    for i, profession in ipairs(professions) do
      local yPos = -10 - ((i - 1) * (barHeight + barGap))

      -- Create label
      local labelText = barChartContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      labelText:SetPoint("TOPLEFT", barChartContainer, "TOPLEFT", 0, yPos)
      labelText:SetText(profession.name)

      -- Create bar background with fixed position based on maxNameWidth
      local barBg = barChartContainer:CreateTexture(nil, "ARTWORK")
      barBg:SetSize(barMaxWidth, barHeight)
      barBg:SetPoint("TOPLEFT", barChartContainer, "TOPLEFT", maxNameWidth, yPos)
      barBg:SetColorTexture(0.1, 0.1, 0.1, 0.4)

      -- Create bar fill
      local barWidth = (profession.percent / 100) * barMaxWidth
      local barFill = barChartContainer:CreateTexture(nil, "ARTWORK")
      barFill:SetSize(barWidth, barHeight)
      barFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", 0, 0)
      barFill:SetColorTexture(profession.color.r, profession.color.g, profession.color.b, 0.7)

      -- Create percentage text
      local percentText = barChartContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      percentText:SetPoint("LEFT", barFill, "RIGHT", 5, 0)
      percentText:SetText(string.format("%.1f%% (%s)",
        profession.percent,
        self:FormatGold(profession.gold)))
    end

    -- Create daily distribution graph if we have data for at least a week
    if (timePeriod == "weekly" or timePeriod == "monthly" or timePeriod == "alltime") and
        #filteredSessions >= 2 then
      local dailyStats = self:CalculateDailyStats(filteredSessions)

      if #dailyStats > 1 then
        local graphFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        graphFrame:SetSize(content:GetWidth() - 30, 200)
        graphFrame:SetPoint("TOPLEFT", professionFrame, "BOTTOMLEFT", 0, -20)

        if graphFrame.SetBackdrop then
          graphFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
          })
          graphFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
          graphFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
        end

        local graphTitle = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        graphTitle:SetPoint("TOPLEFT", graphFrame, "TOPLEFT", 15, -15)
        graphTitle:SetText("Daily Gold Distribution")
        graphTitle:SetTextColor(1, 0.82, 0) -- Gold color

        -- Create simple bar graph
        local barWidth = math.min(50, (graphFrame:GetWidth() - 80) / #dailyStats) -- Max width of 50px per bar
        local maxValue = 0

        -- Find the maximum value for scaling
        for _, stats in ipairs(dailyStats) do
          if (stats.gold or 0) > maxValue then
            maxValue = stats.gold or 0
          end
        end

        if maxValue <= 0 then maxValue = 1 end -- Safety check

        -- Create axis labels
        local yAxisLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        yAxisLabel:SetPoint("TOPLEFT", graphFrame, "TOPLEFT", 15, -40)
        yAxisLabel:SetText("Gold")

        local xAxisLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        xAxisLabel:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT", 50, 15)
        xAxisLabel:SetText("Date")

        -- Draw bars
        local graphHeight = 120
        local barGap = 5
        local xOffset = 50
        local yOffset = 40

        for i, stats in ipairs(dailyStats) do
          -- Calculate bar height based on percentage of max value
          local barHeight = 0
          local gold = stats.gold or 0

          if maxValue > 0 then -- Prevent division by zero
            barHeight = (gold / maxValue) * graphHeight
          end

          if barHeight < 2 and gold > 0 then barHeight = 2 end -- Minimum visible height

          -- Create bar
          local bar = graphFrame:CreateTexture(nil, "ARTWORK")
          bar:SetSize(barWidth - barGap, barHeight)
          bar:SetPoint("BOTTOMLEFT", graphFrame, "BOTTOMLEFT",
            xOffset + ((i - 1) * (barWidth)),
            yOffset)
          bar:SetColorTexture(1, 0.82, 0, 0.8) -- Gold color

          -- Create bar value text
          local valueText = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
          valueText:SetPoint("BOTTOM", bar, "TOP", 0, 2)
          -- Try to set a smaller font if possible
          local font, size, flags = valueText:GetFont()
          if font and size then
            valueText:SetFont(font, math.max(9, size * 0.7), flags)
          end
          valueText:SetText(self:FormatGoldShort(gold))

          -- Date label on x-axis
          local dateText = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
          dateText:SetPoint("TOP", bar, "BOTTOM", 0, -4)
          -- Try to set a smaller font if possible
          if font and size then
            dateText:SetFont(font, math.max(9, size * 0.7), flags)
          end
          dateText:SetText(stats.shortDate or "")
          dateText:SetWidth(barWidth)
          dateText:SetJustifyH("CENTER")
        end

        -- FIXED: Properly get Y coordinate for position calculation
        local _, _, _, _, graphY = graphFrame:GetPoint()
        if graphY then
          content:SetHeight(math.abs(graphY) + graphFrame:GetHeight() + 20)
        else
          -- Fallback if GetPoint doesn't return expected values
          content:SetHeight(700) -- Reasonable default height
        end
      else
        -- No daily distribution data
        -- FIXED: Properly get Y coordinate for position calculation
        local _, _, _, _, professionY = professionFrame:GetPoint()
        if professionY then
          content:SetHeight(math.abs(professionY) + professionFrame:GetHeight() + 20)
        else
          -- Fallback
          content:SetHeight(500)
        end
      end
    else
      -- No graph needed for daily view
      -- FIXED: Properly get Y coordinate for position calculation
      local _, _, _, _, professionY = professionFrame:GetPoint()
      if professionY then
        content:SetHeight(math.abs(professionY) + professionFrame:GetHeight() + 20)
      else
        -- Fallback
        content:SetHeight(500)
      end
    end
  else
    -- No profession data
    -- FIXED: Properly get Y coordinate for position calculation
    local _, _, _, _, summaryY = summaryFrame:GetPoint()
    if summaryY then
      content:SetHeight(math.abs(summaryY) + summaryFrame:GetHeight() + 20)
    else
      -- Fallback
      content:SetHeight(300)
    end
  end
end

function GH:InitializeScrollFrame(parent, contentHeight)
  -- We keep the existing scrollframe if one exists
  local scrollFrame
  local existingScrollFrame

  -- Look for existing scroll frames
  for _, child in pairs({ parent:GetChildren() }) do
    if child:IsObjectType("ScrollFrame") then
      existingScrollFrame = child
      break
    end
  end

  -- Use existing or create new scroll frame
  if existingScrollFrame then
    scrollFrame = existingScrollFrame
    -- Clear the scroll child
    local oldScrollChild = scrollFrame:GetScrollChild()
    if oldScrollChild then
      oldScrollChild:Hide()
    end
  else
    scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 0)
  end

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(scrollFrame:GetWidth(), contentHeight or 500) -- Default height if none provided
  scrollFrame:SetScrollChild(content)

  -- Return content frame so we can add elements to it
  return content
end

function GH:AnalyzeSessionProfessions(session)
  -- If no items, return the existing profession type or "Unknown"
  if not session.items or not next(session.items) then
    return session.professionType or "Unknown"
  end

  -- Create tables to track professions and their gold values
  local professionGold = {
    ["Herbalism"] = 0,
    ["Mining"] = 0,
    ["Skinning"] = 0,
    ["Fishing"] = 0,
    ["Unknown"] = 0
  }

  -- Profession detection mappings
  local herbItems = {
    -- War Within herbs
    ["Mycobloom"] = true,
    ["Arathor's Spear"] = true,
    ["Blessing Blossom"] = true,
    ["Orbinid"] = true,
    ["Luredrop"] = true,
    ["Leyline Residue"] = true,
    ["Viridescent Spores"] = true,

    -- Some other common herbs from previous expansions
    ["Widowbloom"] = true,
    ["Nightshade"] = true,
    ["Rising Glory"] = true,
    ["Marrowroot"] = true,
    ["Vigil's Torch"] = true,
    ["Death Blossom"] = true,
    ["Duskblossom"] = true,
  }

  local miningItems = {
    -- War Within ores
    ["Bismuth"] = true,
    ["Ironclaw Ore"] = true,
    ["Aqirite"] = true,
    ["Null Stone"] = true,

    -- Some other common ores from previous expansions
    ["Laestrite Ore"] = true,
    ["Elethium Ore"] = true,
    ["Phaedrum Ore"] = true,
    ["Sinvyr Ore"] = true,
    ["Oxxein Ore"] = true,
    ["Solenium Ore"] = true,
  }

  local skinningItems = {
    -- War Within skinning materials
    -- Skins
    ["Stormcharged Leather"] = true,
    ["Gloom Chitin"] = true,

    -- Hides
    ["Thunderous Hide"] = true,
    ["Sunless Carapace"] = true,

    -- Species-Specific
    ["Bottled Storm"] = true,
    ["Burning Cinderbee Setae"] = true,
    ["Honed Bone Shards"] = true,
    ["Kaheti Swarm Chitin"] = true,

    -- Previous expansion skinning materials
    ["Heavy Callous Hide"] = true,
    ["Callous Hide"] = true,
    ["Desolate Leather"] = true,
    ["Heavy Desolate Leather"] = true,
    ["Pallid Bone"] = true,
    ["Protogenic Pelt"] = true,
    ["Dense Hide"] = true,
  }

  local fishingItems = {
    -- War Within fish
    ["Bismuth Bitterling"] = true,
    ["Bloody Perch"] = true,
    ["Crystalline Sturgeon"] = true,
    ["Dilly-Dally Dace"] = true,
    ["Arathor Hammerfish"] = true,
    ["Dornish Pike"] = true,
    ["Goldengill Trout"] = true,
    ["Kaheti Slum Shark"] = true,
    ["Nibbling Minnow"] = true,
    ["Pale Huskfish"] = true,
    ["Quiet River Bass"] = true,
    ["Roaring Anglerseeker"] = true,
    ["Specular Rainbowfish"] = true,
    ["Whispering Stargazer"] = true,
    ["\"Gold\" Fish"] = true,
    ["Awoken Coelacanth"] = true,
    ["Cursed Ghoulfish"] = true,
    ["Queen's Lurefish"] = true,
    ["Regal Dottyback"] = true,
    ["Sanguine Dogfish"] = true,
    ["Spiked Sea Raven"] = true,

    -- Typical fishing items
    ["Fish"] = true,
    ["Trout"] = true,
    ["Sturgeon"] = true,
    ["Perch"] = true,
    ["Bass"] = true,
  }

  -- Common materials that can come from multiple professions
  local sharedMaterials = {
    ["Writhing Sample"] = true,    -- Can be from mining or herbalism
    ["Crystalline Powder"] = true, -- Can be from mining or herbalism
    ["Weavercloth"] = true,        -- Can be tucked into ore nodes sometimes
  }

  -- Analyze each item in the session
  for itemLink, itemData in pairs(session.items) do
    local itemName = itemData.name
    if not itemName then
      -- Try to get item name from the itemID if available
      if itemData.itemID then
        itemName = GetItemInfo(itemData.itemID) or "Unknown Item"
      else
        itemName = "Unknown Item"
      end
    end

    -- Track the gold value of this item
    local itemValue = itemData.value or 0
    local professionDetected = false

    -- Check the item against our profession lists
    if herbItems[itemName] then
      professionGold["Herbalism"] = professionGold["Herbalism"] + itemValue
      professionDetected = true
    end

    if miningItems[itemName] then
      professionGold["Mining"] = professionGold["Mining"] + itemValue
      professionDetected = true
    end

    if skinningItems[itemName] then
      professionGold["Skinning"] = professionGold["Skinning"] + itemValue
      professionDetected = true
    end

    if fishingItems[itemName] then
      professionGold["Fishing"] = professionGold["Fishing"] + itemValue
      professionDetected = true
    end

    -- Handle shared materials - only if we have detected other profession items
    if sharedMaterials[itemName] then
      -- Try to determine which profession it belongs to based on context
      -- For example, if we've already detected herbalism items but not mining
      if professionGold["Herbalism"] > 0 and professionGold["Mining"] == 0 then
        professionGold["Herbalism"] = professionGold["Herbalism"] + itemValue
        professionDetected = true
      elseif professionGold["Mining"] > 0 and professionGold["Herbalism"] == 0 then
        professionGold["Mining"] = professionGold["Mining"] + itemValue
        professionDetected = true
      elseif professionGold["Herbalism"] > 0 and professionGold["Mining"] > 0 then
        -- If both herbalism and mining are detected, split the value
        professionGold["Herbalism"] = professionGold["Herbalism"] + (itemValue * 0.5)
        professionGold["Mining"] = professionGold["Mining"] + (itemValue * 0.5)
        professionDetected = true
      end
    end

    -- If we couldn't detect the profession, put it in unknown
    if not professionDetected then
      professionGold["Unknown"] = professionGold["Unknown"] + itemValue
    end
  end

  -- Determine the dominant profession and any secondary professions
  local dominantProfession = "Unknown"
  local highestValue = 0
  local secondaryProfessions = {}

  for profession, gold in pairs(professionGold) do
    if gold > highestValue then
      -- Move previous dominant to secondary if applicable
      if highestValue > 0 then
        table.insert(secondaryProfessions, dominantProfession)
      end

      -- Set new dominant
      highestValue = gold
      dominantProfession = profession
    elseif gold > 0 then
      -- Add as secondary profession
      table.insert(secondaryProfessions, profession)
    end
  end

  -- Update the session with all detected professions
  session.professionTypes = {}

  -- Add dominant profession first
  if dominantProfession ~= "Unknown" or highestValue > 0 then
    table.insert(session.professionTypes, {
      name = dominantProfession,
      gold = professionGold[dominantProfession],
      percentage = 100 * (professionGold[dominantProfession] / (session.gold or 1))
    })
  end

  -- Add secondary professions
  for _, profession in ipairs(secondaryProfessions) do
    if professionGold[profession] > 0 then
      table.insert(session.professionTypes, {
        name = profession,
        gold = professionGold[profession],
        percentage = 100 * (professionGold[profession] / (session.gold or 1))
      })
    end
  end

  -- Keep the dominant profession as the main professionType for backward compatibility
  session.professionType = dominantProfession

  -- Also store the detailed breakdown
  session.professionBreakdown = professionGold

  return dominantProfession, session.professionTypes
end

-- Helper function to calculate overall metrics from a list of sessions
function GH:CalculateOverallMetrics(sessions)
  local metrics = {
    totalGold = 0,
    totalTime = 0,
    totalNodes = 0,
    bestGoldPerHour = 0,
    bestSessionGold = 0,
    avgGoldPerHour = 0,
    avgGoldPerNode = 0,
    avgSessionLength = 0,
    avgSessionGold = 0,
    professionStats = {}
  }

  -- Safety check - don't process if no sessions
  if not sessions or #sessions == 0 then
    return metrics
  end

  for _, session in ipairs(sessions) do
    -- Skip nil sessions
    if session then
      -- Analyze the professions for this session if not already done
      if not session.professionTypes then
        self:AnalyzeSessionProfessions(session)
      end

      -- Total gold (with nil check)
      metrics.totalGold = metrics.totalGold + (session.gold or 0)

      -- Total time (with nil check)
      metrics.totalTime = metrics.totalTime + (session.duration or 0)

      -- Total nodes (with nil check)
      metrics.totalNodes = metrics.totalNodes + (session.nodeCount or 0)

      -- Best gold per hour (with nil check)
      if (session.goldPerHour or 0) > metrics.bestGoldPerHour then
        metrics.bestGoldPerHour = session.goldPerHour or 0
      end

      -- Best session gold (with nil check)
      if (session.gold or 0) > metrics.bestSessionGold then
        metrics.bestSessionGold = session.gold or 0
      end

      -- Track profession stats using the detailed breakdown
      if session.professionBreakdown then
        for profession, gold in pairs(session.professionBreakdown) do
          if gold > 0 then
            if not metrics.professionStats[profession] then
              metrics.professionStats[profession] = {
                gold = 0,
                time = 0, -- We will apportion time based on gold percentage
                nodes = 0 -- We will apportion nodes based on gold percentage
              }
            end

            metrics.professionStats[profession].gold = metrics.professionStats[profession].gold + gold

            -- Apportion time and nodes based on the percentage of gold
            local sessionGoldPercent = gold / (session.gold or 1)
            metrics.professionStats[profession].time = metrics.professionStats[profession].time +
                ((session.duration or 0) * sessionGoldPercent)
            metrics.professionStats[profession].nodes = metrics.professionStats[profession].nodes +
                ((session.nodeCount or 0) * sessionGoldPercent)
          end
        end
      else
        -- Fallback to old method if no detailed breakdown
        local professionType = session.professionType or "Unknown"
        if not metrics.professionStats[professionType] then
          metrics.professionStats[professionType] = {
            gold = 0,
            time = 0,
            nodes = 0
          }
        end

        metrics.professionStats[professionType].gold = metrics.professionStats[professionType].gold + (session.gold or 0)
        metrics.professionStats[professionType].time = metrics.professionStats[professionType].time +
            (session.duration or 0)
        metrics.professionStats[professionType].nodes = metrics.professionStats[professionType].nodes +
            (session.nodeCount or 0)
      end
    end
  end

  -- Calculate averages with safety checks
  if metrics.totalTime > 0 then
    metrics.avgGoldPerHour = (metrics.totalGold / metrics.totalTime) * 3600
  end

  if metrics.totalNodes > 0 then
    metrics.avgGoldPerNode = metrics.totalGold / metrics.totalNodes
  end

  if #sessions > 0 then
    metrics.avgSessionLength = metrics.totalTime / #sessions
    metrics.avgSessionGold = metrics.totalGold / #sessions
  end

  return metrics
end

-- Helper function to calculate daily statistics
function GH:CalculateDailyStats(sessions)
  local dailyStats = {}
  local dateMap = {}

  -- Safety check
  if not sessions or #sessions == 0 then
    return dailyStats
  end

  -- Organize sessions by date
  for _, session in ipairs(sessions) do
    if session and session.date then -- Double safety check
      local dateStr = string.match(session.date, "(%d+%-%d+%-%d+)")
      if dateStr then
        if not dateMap[dateStr] then
          dateMap[dateStr] = {
            gold = 0,
            time = 0,
            nodes = 0,
            date = dateStr
          }
        end

        dateMap[dateStr].gold = dateMap[dateStr].gold + (session.gold or 0)
        dateMap[dateStr].time = dateMap[dateStr].time + (session.duration or 0)
        dateMap[dateStr].nodes = dateMap[dateStr].nodes + (session.nodeCount or 0)
      end
    end
  end

  -- Convert to array and sort by date
  for dateStr, stats in pairs(dateMap) do
    -- Create short date format (MM/DD)
    local year, month, day = string.match(dateStr, "(%d+)%-(%d+)%-(%d+)")
    if year and month and day then -- Add nil check
      stats.shortDate = month .. "/" .. day
      table.insert(dailyStats, stats)
    end
  end

  table.sort(dailyStats, function(a, b)
    -- Safely handle nil values
    local aDate = a.date or ""
    local bDate = b.date or ""
    return aDate < bDate
  end)

  -- Limit to last 14 days to avoid overcrowding
  if #dailyStats > 14 then
    local trimmedStats = {}
    for i = #dailyStats - 13, #dailyStats do
      table.insert(trimmedStats, dailyStats[i])
    end
    dailyStats = trimmedStats
  end

  return dailyStats
end

-- Helper function to convert date string to timestamp
function GH:DateStringToTimestamp(dateStr)
  if not dateStr then return nil end

  local year, month, day, hour, min, sec = string.match(dateStr or "", "(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)")
  if not year or not month or not day or not hour or not min or not sec then return nil end

  -- Convert all values to numbers
  year = tonumber(year)
  month = tonumber(month)
  day = tonumber(day)
  hour = tonumber(hour)
  min = tonumber(min)
  sec = tonumber(sec)

  -- Safety check - make sure all values are valid numbers
  if not year or not month or not day or not hour or not min or not sec then
    return nil
  end

  return time({
    year = year,
    month = month,
    day = day,
    hour = hour,
    min = min,
    sec = sec
  })
end

-- Helper function to format gold amount (short version)
function GH:FormatGoldShort(amount)
  if not amount then return "0g" end

  local gold = math.floor((amount or 0) / 10000)
  if gold >= 1000 then
    return string.format("%.1fk", gold / 1000)
  else
    return gold .. "g"
  end
end

-- Helper function to format gold amount
function GH:FormatGold(amount)
  if not amount then return "0g" end

  local gold = math.floor((amount or 0) / 10000)
  local silver = math.floor(((amount or 0) % 10000) / 100)

  return string.format("%d.%02dg", gold, silver)
end

-- Hook into the ShowHistoryWindow function to add our metrics tab
local originalShowHistoryWindow = GH.ShowHistoryWindow
GH.ShowHistoryWindow = function(self)
  -- Call the original function first
  if originalShowHistoryWindow then
    originalShowHistoryWindow(self)
  end

  -- Add our metrics tab using pcall to catch any errors
  local success, errorMessage = pcall(function()
    self:InitializeMetricsTab()
  end)

  -- Print error message if in debug mode
  if not success and self.debugMode then
    print("|cFFFF0000Gather Hero Error:|r", errorMessage)
  end
end
