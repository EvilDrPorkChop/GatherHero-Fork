-- GH_Challenge_ZoneHopper.lua
-- Zone Hopper Challenge for Gather Hero addon
-- Challenge: Gather nodes in X different zones within time limit

local _, GH = ...

-- Create a namespace for the challenge
GH.Challenge = GH.Challenge or {}
GH.Challenge.ZoneHopper = {}

-- Initialize ZoneHopper challenge
function GH.Challenge.ZoneHopper:Initialize()
  -- Wait until main addon is loaded
  if not GH.ChallengeMode then
    C_Timer.After(1, function() self:Initialize() end)
    return
  end

  -- Make sure challenge types are registered
  if not GH.ChallengeMode.CHALLENGE_TYPES then
    C_Timer.After(1, function() self:Initialize() end)
    return
  end

  -- Register the zone hopper challenge type if not already registered
  self:EnsureChallengeTypeRegistered()

  -- Register default settings
  self:RegisterDefaultSettings()

  -- Register challenge handlers
  self:RegisterChallengeHandlers()
end

-- Make sure challenge type is registered
function GH.Challenge.ZoneHopper:EnsureChallengeTypeRegistered()
  if not GH.ChallengeMode or not GH.ChallengeMode.CHALLENGE_TYPES then
    -- Try again later
    C_Timer.After(1, function() self:EnsureChallengeTypeRegistered() end)
    return
  end

  -- Types are available, no need to register our own
  return true
end

-- Register default settings
function GH.Challenge.ZoneHopper:RegisterDefaultSettings()
  -- Initialize saved variables if needed
  if not GatherHeroDB then return end
  if not GatherHeroDB.challenges then GatherHeroDB.challenges = {} end
  if not GatherHeroDB.challenges.settings then GatherHeroDB.challenges.settings = {} end

  -- Default settings for zone hopper challenge
  if not GatherHeroDB.challenges.settings.zoneHopper then
    GatherHeroDB.challenges.settings.zoneHopper = {
      requiredZones = 3,     -- Need to gather in 3 different zones
      nodesPerZone = 3,      -- Need to gather at least 3 nodes in each zone
      timeLimit = 600,       -- Within 10 minutes
      allowedProfessions = { -- Allowed professions
        ["Herbalism"] = true,
        ["Mining"] = true,
        ["Skinning"] = true,
        ["Fishing"] = true
      }
    }
  end
end

-- Register challenge handlers
function GH.Challenge.ZoneHopper:RegisterChallengeHandlers()
  -- Hook into the main challenge system
  if not GH.ChallengeMode.StartChallenge then
    -- Function doesn't exist yet, try again later
    C_Timer.After(1, function() self:RegisterChallengeHandlers() end)
    return
  end

  -- Override the existing challenge start function
  local originalStartChallenge = GH.ChallengeMode.StartChallenge
  GH.ChallengeMode.StartChallenge = function(self, challengeType, params)
    -- Handle Zone Hopper challenge
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
      -- Start countdown
      GH.ChallengeMode:StartCountdown(function()
        -- Stop any existing session
        if GH.sessionState ~= "idle" then
          GH:StopSession()
        end

        -- Start a new session
        GH:StartSession()

        -- Set up the challenge
        GatherHeroDB.challenges.enabled = true
        GatherHeroDB.challenges.activeChallenge = challengeType
        GatherHeroDB.challenges.challengeStartTime = GetTime()

        -- Get parameters
        local requiredZones = params and params.requiredZones or
            GatherHeroDB.challenges.settings.zoneHopper.requiredZones
        local nodesPerZone = params and params.nodesPerZone or
            GatherHeroDB.challenges.settings.zoneHopper.nodesPerZone
        local timeLimit = params and params.timeLimit or
            GatherHeroDB.challenges.settings.zoneHopper.timeLimit

        -- Store challenge data
        GatherHeroDB.challenges.zoneHopperData = {
          requiredZones = requiredZones,
          nodesPerZone = nodesPerZone,
          timeLimit = timeLimit,
          endTime = GetTime() + timeLimit,
          zoneData = {},     -- Will store zones and nodes gathered in each
          completedZones = 0 -- Number of zones with required nodes gathered
        }

        -- Set up progress tracking (for challenge UI)
        GatherHeroDB.challenges.challengeProgress = 0
        GatherHeroDB.challenges.challengeGoal = requiredZones
        GatherHeroDB.challenges.challengeCompleted = false

        -- Show challenge instructions
        GH.ChallengeMode:ShowChallengeInstructions(
          "Zone Hopper Challenge",
          string.format("Gather %d nodes in each of %d different zones!", nodesPerZone, requiredZones)
        )

        -- Log challenge info to console
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Zone Hopper: Gather %d nodes in each of %d different zones!",
          nodesPerZone, requiredZones))

        -- Update UI immediately
        if GH.ChallengeUI and GH.ChallengeUI.Update then
          GH.ChallengeUI:Update()
        end

        -- Start challenge timer
        C_Timer.After(1, function() GH.Challenge.ZoneHopper:CheckProgress() end)
      end)

      return true
    else
      -- Pass other challenge types to the original function
      return originalStartChallenge(self, challengeType, params)
    end
  end

  -- Hook into the StartNextChallenge function to add Zone Hopper as the next challenge
  if GH.ChallengeMode.StartNextChallenge then
    local originalStartNextChallenge = GH.ChallengeMode.StartNextChallenge
    GH.ChallengeMode.StartNextChallenge = function(self, challengeType, params)
      if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
        -- Set up the challenge data for Zone Hopper
        GatherHeroDB.challenges.enabled = true
        GatherHeroDB.challenges.activeChallenge = challengeType
        GatherHeroDB.challenges.challengeStartTime = GetTime()

        -- Get parameters
        local requiredZones = params and params.requiredZones or
            GatherHeroDB.challenges.settings.zoneHopper.requiredZones
        local nodesPerZone = params and params.nodesPerZone or
            GatherHeroDB.challenges.settings.zoneHopper.nodesPerZone
        local timeLimit = params and params.timeLimit or
            GatherHeroDB.challenges.settings.zoneHopper.timeLimit

        -- Store challenge data
        GatherHeroDB.challenges.zoneHopperData = {
          requiredZones = requiredZones,
          nodesPerZone = nodesPerZone,
          timeLimit = timeLimit,
          endTime = GetTime() + timeLimit,
          zoneData = {},     -- Will store zones and nodes gathered in each
          completedZones = 0 -- Number of zones with required nodes gathered
        }

        -- Set up progress tracking
        GatherHeroDB.challenges.challengeProgress = 0
        GatherHeroDB.challenges.challengeGoal = requiredZones
        GatherHeroDB.challenges.challengeCompleted = false

        -- Show challenge instructions
        GH.ChallengeMode:ShowChallengeInstructions(
          "Zone Hopper Challenge",
          string.format("Gather %d nodes in each of %d different zones!", nodesPerZone, requiredZones)
        )

        -- Log challenge info to console
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Zone Hopper: Gather %d nodes in each of %d different zones!",
          nodesPerZone, requiredZones))

        -- Start challenge timer
        C_Timer.After(1, function() GH.Challenge.ZoneHopper:CheckProgress() end)
      else
        -- Call original function for other challenge types
        originalStartNextChallenge(self, challengeType, params)
      end
    end
  end

  -- Hook into ProcessLootMessage to track gathering in different zones
  local originalProcessLootMessage = GH.ProcessLootMessage
  GH.ProcessLootMessage = function(self, msg)
    -- Call original function first
    originalProcessLootMessage(self, msg)

    -- Check if zone hopper challenge is active
    if GatherHeroDB.challenges and
        GatherHeroDB.challenges.enabled and
        GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
      -- Get challenge data
      local data = GatherHeroDB.challenges.zoneHopperData
      if not data then return end

      -- Get current zone
      local currentZone = GetZoneText() or GetMinimapZoneText() or "Unknown"

      -- Check if this node was already counted this frame (prevent double-counting)
      if data.lastProcessedNode and (GetTime() - data.lastProcessedNode) < 0.1 then
        return -- Skip this to prevent double counting
      end

      -- Record this gather
      data.lastProcessedNode = GetTime()

      -- Initialize zone in tracking data if it doesn't exist
      if not data.zoneData[currentZone] then
        data.zoneData[currentZone] = {
          nodesGathered = 0,
          completed = false
        }
      end

      -- Increment nodes gathered in this zone
      data.zoneData[currentZone].nodesGathered = data.zoneData[currentZone].nodesGathered + 1

      -- Check if this zone is now complete
      if not data.zoneData[currentZone].completed and
          data.zoneData[currentZone].nodesGathered >= data.nodesPerZone then
        -- Mark zone as completed
        data.zoneData[currentZone].completed = true
        data.completedZones = data.completedZones + 1

        -- Update progress
        GatherHeroDB.challenges.challengeProgress = data.completedZones

        -- Show zone completion message
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Zone '%s' completed! (%d/%d zones)",
          currentZone, data.completedZones, data.requiredZones))

        -- Show progress popup
        if GH.ObjectivePopup then
          GH.ObjectivePopup:Show(
            string.format("Zone '%s' completed! (%d/%d zones)",
              currentZone, data.completedZones, data.requiredZones),
            3
          )
        end

        -- Play sound for zone completion
        PlaySoundFile("Sound\\Interface\\LevelUp.ogg", "Master")
      else
        -- Show progress in this zone
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Node gathered in '%s': %d/%d",
          currentZone, data.zoneData[currentZone].nodesGathered, data.nodesPerZone))
      end

      -- Force update the UI
      if GH.Challenge.ZoneHopper.UpdateUI then
        GH.Challenge.ZoneHopper:UpdateUI()
      end

      -- Check if challenge is complete
      if data.completedZones >= data.requiredZones then
        -- Challenge completed!
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        GH.ChallengeMode:ShowCompletionMessage(
          "Zone Hopper Challenge Complete!",
          string.format("You've successfully gathered in %d different zones!", data.completedZones)
        )

        -- Also show as an objective popup
        if GH.ObjectivePopup then
          GH.ObjectivePopup:Show(
            "Zone Hopper Challenge Complete!",
            4
          )
        end

        -- Log to console
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Zone Hopper Challenge Complete! You've gathered in %d different zones!",
          data.completedZones))

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Complete the challenge
        GH.ChallengeMode:CompleteChallenge(true)

        -- Start the final challenge
        C_Timer.After(3, function()
          -- Debug output
          print("|cFFFF00FFGather Hero Debug:|r Starting Final Gold challenge...")

          -- Calculate total time spent and gold earned
          local firstStart = GatherHeroDB.challenges.firstChallengeStartTime or GatherHeroDB.challengeStartTime or
              GetTime()
          local totalTimeSpent = (GetTime() - firstStart) / 60 -- in minutes
          local totalGoldEarned = GH.sessionGold or 0

          print("|cFFFF00FFGather Hero Debug:|r Time spent: " ..
            totalTimeSpent .. " minutes, Gold earned: " .. totalGoldEarned)

          -- Create parameters
          local params = {
            timeSpent = totalTimeSpent,
            goldEarned = totalGoldEarned
          }

          -- Start challenge directly, bypassing StartNextChallenge
          GH.ChallengeMode:StartChallenge(GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD, params)
        end)
      end
    end
  end

  -- Add challenge UI integration
  if GH.ChallengeUI and GH.ChallengeUI.Update then
    local originalChallengeUIUpdate = GH.ChallengeUI.Update
    GH.ChallengeUI.Update = function(self)
      -- Call original function first
      originalChallengeUIUpdate(self)

      -- Let our UpdateUI function handle the rest
      if GH.Challenge and GH.Challenge.ZoneHopper and GH.Challenge.ZoneHopper.UpdateUI then
        GH.Challenge.ZoneHopper:UpdateUI()
      end
    end
  end
end

-- Check challenge progress
function GH.Challenge.ZoneHopper:CheckProgress()
  -- Only process if the challenge is active
  if not GatherHeroDB.challenges or
      not GatherHeroDB.challenges.enabled or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
    return
  end

  local data = GatherHeroDB.challenges.zoneHopperData
  if not data then return end

  local currentTime = GetTime()
  -- Update the UI with current status
  self:UpdateUI()

  -- Check if time limit has been reached
  if currentTime >= data.endTime then
    -- Time's up!
    if not GatherHeroDB.challenges.challengeCompleted then
      -- Check if actually completed (in case the event handling missed it)
      if data.completedZones >= data.requiredZones then
        -- Actually completed!
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        GH.ChallengeMode:ShowCompletionMessage(
          "Zone Hopper Challenge Complete!",
          string.format("You've successfully gathered in %d different zones!", data.completedZones)
        )

        -- Log to console
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Zone Hopper Challenge Complete! You've gathered in %d different zones!",
          data.completedZones))

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Complete the challenge
        GH.ChallengeMode:CompleteChallenge(true)
      else
        -- Challenge failed
        GH.ChallengeMode:ShowCompletionMessage(
          "Challenge Failed!",
          string.format("Time's up! You completed %d/%d zones.",
            data.completedZones, data.requiredZones)
        )

        -- Log to console
        print(string.format("|cFFFF0000Gather Hero Challenge:|r Failed! Time's up! You completed %d/%d zones.",
          data.completedZones, data.requiredZones))

        -- Play failure sound
        PlaySoundFile("Sound\\Interface\\LevelUp", "Master")

        -- Complete the challenge (failed)
        GH.ChallengeMode:CompleteChallenge(false)
      end
    end
    return
  end

  -- Update UI to show progress
  self:UpdateUI()

  -- Check again in 1 second
  C_Timer.After(1, function() GH.Challenge.ZoneHopper:CheckProgress() end)
end

-- Update UI elements
function GH.Challenge.ZoneHopper:UpdateUI()
  -- Only update if Challenge UI exists
  if not GH.ChallengeUI or not GH.ChallengeUI.frame then return end

  -- Only update if we're the active challenge
  if not GatherHeroDB or not GatherHeroDB.challenges or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
    return
  end

  -- Get challenge data
  local data = GatherHeroDB.challenges.zoneHopperData
  if not data then return end

  -- Get current zone
  local currentZone = GetZoneText() or GetMinimapZoneText() or "Unknown"
  local currentZoneNodes = 0

  if data.zoneData[currentZone] then
    currentZoneNodes = data.zoneData[currentZone].nodesGathered
  end

  -- Update UI elements
  local frame = GH.ChallengeUI.frame
  frame.title:SetText("Zone Hopper Challenge")
  frame.challengeType:SetText("Zone Exploration")

  -- Update objective text
  frame.objective:SetText(string.format("Gather in %d different zones (%d nodes each)",
    data.requiredZones, data.nodesPerZone))

  -- Update progress text and bar
  frame.progress:SetText(string.format("%d/%d zones completed",
    data.completedZones, data.requiredZones))

  -- Update progress bar
  local progressPercent = (data.completedZones / data.requiredZones) * 100
  frame.progressBar:SetValue(progressPercent)

  -- Update time remaining
  local timeLeft = math.max(0, data.endTime - GetTime())
  local minutes = math.floor(timeLeft / 60)
  local seconds = math.floor(timeLeft % 60)

  -- Build a string showing current zone progress
  local zoneProgress = string.format("Current zone: %d/%d", currentZoneNodes, data.nodesPerZone)

  -- Combine time and zone progress information
  frame.timeRemaining:SetText(string.format("Time: %d:%02d | %s",
    minutes, seconds, zoneProgress))

  -- Change color based on time left
  if timeLeft < 30 then
    frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 30 seconds
  elseif timeLeft < 60 then
    frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 1 minute
  else
    frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
  end
end

-- Helper function to get a comma-separated list of completed zones
function GH.Challenge.ZoneHopper:GetCompletedZonesList()
  local data = GatherHeroDB.challenges.zoneHopperData
  if not data or not data.zoneData then return "None" end

  local completedZones = {}
  for zone, zoneInfo in pairs(data.zoneData) do
    if zoneInfo.completed then
      table.insert(completedZones, zone)
    end
  end

  if #completedZones == 0 then
    return "None"
  else
    return table.concat(completedZones, ", ")
  end
end

-- Initialize the challenge
GH.Challenge.ZoneHopper:Initialize()
