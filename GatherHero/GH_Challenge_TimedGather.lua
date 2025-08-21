-- GH_Challenge_TimedGather.lua
-- Timed Gather Challenge for Gather Hero addon
-- Challenge: Loot gold every X seconds for Y total seconds

local _, GH = ...

-- Create a namespace for the challenge
GH.Challenge = GH.Challenge or {}
GH.Challenge.TimedGather = {}

-- Initialize TimedGather challenge
function GH.Challenge.TimedGather:Initialize()
  -- Force update the settings first thing
  self:ForceUpdateSettings()

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

  -- Register default settings
  self:RegisterDefaultSettings()

  -- Register challenge handlers
  self:RegisterChallengeHandlers()
end

-- Add this new function to force update the settings
function GH.Challenge.TimedGather:ForceUpdateSettings()
  if GatherHeroDB and GatherHeroDB.challenges and GatherHeroDB.challenges.settings and GatherHeroDB.challenges.settings.timedGather then
    -- Force the correct values
    GatherHeroDB.challenges.settings.timedGather.timeWindow = 20
    GatherHeroDB.challenges.settings.timedGather.totalDuration = 200
  end
end

-- Register default settings
function GH.Challenge.TimedGather:RegisterDefaultSettings()
  -- Initialize saved variables if needed
  if not GatherHeroDB then return end
  if not GatherHeroDB.challenges then GatherHeroDB.challenges = {} end
  if not GatherHeroDB.challenges.settings then GatherHeroDB.challenges.settings = {} end

  -- Default settings for timed gather challenge
  if not GatherHeroDB.challenges.settings.timedGather then
    GatherHeroDB.challenges.settings.timedGather = {
      timeWindow = 20,       -- Must gather every 10 seconds
      totalDuration = 200,   -- For a total of 100 seconds
      requiredGathers = 10,  -- Need to gather 10 times
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
function GH.Challenge.TimedGather:RegisterChallengeHandlers()
  -- Hook into the main challenge system
  if not GH.ChallengeMode.StartChallenge then
    -- Function doesn't exist yet, try again later
    C_Timer.After(1, function() self:RegisterChallengeHandlers() end)
    return
  end

  -- Override the existing challenge start function
  local originalStartChallenge = GH.ChallengeMode.StartChallenge
  GH.ChallengeMode.StartChallenge = function(self, challengeType, params)
    -- Handle Timed Gather challenge
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
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
        local timeWindow = 20     -- Force to 20 seconds regardless of settings
        local totalDuration = 200 -- Force to 200 seconds regardless of settings
        local requiredGathers = params and params.requiredGathers or
            GatherHeroDB.challenges.settings.timedGather.requiredGathers

        -- Store challenge data
        GatherHeroDB.challenges.timedGatherData = {
          timeWindow = timeWindow,
          totalDuration = totalDuration,
          requiredGathers = requiredGathers,
          endTime = GetTime() + totalDuration,
          nextGatherTime = GetTime() + timeWindow,
          gathersCompleted = 0,
          lastGatherTime = GetTime()
        }

        -- Set up progress tracking
        GatherHeroDB.challenges.challengeProgress = 0
        GatherHeroDB.challenges.challengeGoal = requiredGathers
        GatherHeroDB.challenges.challengeCompleted = false

        -- Show challenge instructions
        GH.ChallengeMode:ShowChallengeInstructions(
          "Timed Gather Challenge",
          string.format("Gather every %d seconds for a total of %d gathers!", timeWindow, requiredGathers)
        )

        -- Log challenge info to console
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Timed Gather: Gather every %d seconds for a total of %d gathers!",
          timeWindow, requiredGathers))

        -- Make sure the UI is updated immediately to show the challenge
        if GH.ChallengeUI and GH.ChallengeUI.Update then
          GH.ChallengeUI:Update()
        end

        -- Start challenge timer with a short delay to ensure everything is initialized
        C_Timer.After(0.1, function()
          if GH.Challenge and GH.Challenge.TimedGather and GH.Challenge.TimedGather.CheckProgress then
            GH.Challenge.TimedGather:CheckProgress()
          else
            print("|cFFFF0000Gather Hero:|r Error: Could not start Timed Gather challenge timer")
          end
        end)
      end)

      return true
    else
      -- Pass other challenge types to the original function
      return originalStartChallenge(self, challengeType, params)
    end
  end

  -- Hook into the ProcessLootMessage function to track gathering events
  local originalProcessLootMessage = GH.ProcessLootMessage
  GH.ProcessLootMessage = function(self, msg)
    -- Call original function first
    originalProcessLootMessage(self, msg)

    -- Check if timed gather challenge is active
    if GatherHeroDB.challenges and
        GatherHeroDB.challenges.enabled and
        GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
      -- Get challenge data
      local data = GatherHeroDB.challenges.timedGatherData
      if not data then return end

      -- IMPORTANT: Check if this node was already counted this frame
      if data.lastProcessedNode and (GetTime() - data.lastProcessedNode) < 0.1 then
        return -- Skip this to prevent double counting
      end

      -- Record this gather
      data.lastGatherTime = GetTime()
      data.lastProcessedNode = GetTime() -- Track when we last processed a node

      -- Reset the next gather time
      data.nextGatherTime = GetTime() + data.timeWindow

      -- Increment gathers completed if not already reached max
      if data.gathersCompleted < data.requiredGathers then
        data.gathersCompleted = data.gathersCompleted + 1

        -- Update progress
        GatherHeroDB.challenges.challengeProgress = data.gathersCompleted

        -- Show progress popup
        if GH.ObjectivePopup then
          GH.ObjectivePopup:Show(
            string.format("Timed Gather: %d/%d completed",
              data.gathersCompleted, data.requiredGathers),
            2.5
          )
        end

        -- Play sound for successful gather
        PlaySoundFile("Sound\\Interface\\MapPing.ogg", "Master")

        -- Force update the UI
        if GH.Challenge.TimedGather.UpdateUI then
          GH.Challenge.TimedGather:UpdateUI()
        end

        -- Check if challenge is complete
        if data.gathersCompleted >= data.requiredGathers then
          -- Challenge completed!
          GatherHeroDB.challenges.challengeCompleted = true

          -- Show completion message
          GH.ChallengeMode:ShowCompletionMessage(
            "Timed Gather Challenge Complete!",
            string.format("You've gathered %d times within the time limit!", data.gathersCompleted)
          )

          -- Also show as an objective popup
          if GH.ObjectivePopup then
            GH.ObjectivePopup:Show(
              "Timed Gather Challenge Complete!",
              4
            )
          end

          -- Play completion sound
          PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

          -- Complete the challenge
          GH.ChallengeMode:CompleteChallenge(true)


          -- Start the next challenge
          C_Timer.After(3, function()
            -- Start Combat Gather challenge with safety checks
            local requiredGathers = 5 -- Default value
            local timeLimit = 300     -- Default value

            -- Try to get values from settings if they exist
            if GatherHeroDB and GatherHeroDB.challenges and
                GatherHeroDB.challenges.settings and
                GatherHeroDB.challenges.settings.combatGather then
              requiredGathers = GatherHeroDB.challenges.settings.combatGather.requiredGathers or requiredGathers
              timeLimit = GatherHeroDB.challenges.settings.combatGather.timeLimit or timeLimit
            end

            local params = {
              requiredGathers = requiredGathers,
              timeLimit = timeLimit
            }

            -- Make sure the challenge type is defined
            if GH.ChallengeMode.CHALLENGE_TYPES and GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
              GH.ChallengeMode:StartNextChallenge(GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER, params)
            else
              print("|cFFFF0000Gather Hero:|r Could not start Combat Gather challenge - challenge type not registered.")
            end
          end)
        end
      end
    end
  end

  -- Add timed gather to Challenge UI integration if not already covered
  local originalChallengeUIUpdate = GH.ChallengeUI and GH.ChallengeUI.Update
  if GH.ChallengeUI and GH.ChallengeUI.Update then
    GH.ChallengeUI.Update = function(self)
      -- Call original function first
      originalChallengeUIUpdate(self)

      -- Let our UpdateUI function handle the rest
      if GH.Challenge and GH.Challenge.TimedGather and GH.Challenge.TimedGather.UpdateUI then
        GH.Challenge.TimedGather:UpdateUI()
      end
    end
  end
end

-- This ensures the challenge UI is properly updated for the Timed Gather challenge

-- Add this standalone function to GH_Challenge_TimedGather.lua
function GH.Challenge.TimedGather:UpdateUI()
  -- Only update if Challenge UI exists
  if not GH.ChallengeUI or not GH.ChallengeUI.frame then return end

  -- Only update if we're the active challenge
  if not GatherHeroDB or not GatherHeroDB.challenges or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
    return
  end

  -- Get challenge data
  local data = GatherHeroDB.challenges.timedGatherData
  if not data then return end

  -- Update UI elements
  local frame = GH.ChallengeUI.frame
  frame.title:SetText("Timed Gather Challenge")
  frame.challengeType:SetText("Time Pressure")

  -- Update objective text
  frame.objective:SetText(string.format("Gather every %d seconds", data.timeWindow))

  -- Update progress text and bar
  frame.progress:SetText(string.format("%d/%d gathers completed",
    data.gathersCompleted, data.requiredGathers))

  -- Update progress bar (properly calculate percentage)
  local progressPercent = (data.gathersCompleted / data.requiredGathers) * 100
  frame.progressBar:SetValue(progressPercent)

  -- Update time remaining
  local timeToNextGather = math.max(0, data.nextGatherTime - GetTime())
  local overallTimeLeft = math.max(0, data.endTime - GetTime())

  -- Show the most important time (whichever is shorter)
  if timeToNextGather < overallTimeLeft then
    frame.timeRemaining:SetText(string.format("Next gather: %.1fs", timeToNextGather))

    -- Color based on urgency
    if timeToNextGather < 3 then
      frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 3 seconds
    elseif timeToNextGather < 5 then
      frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 5 seconds
    else
      frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
    end
  else
    -- Show overall time remaining
    frame.timeRemaining:SetText(string.format("Time left: %.1fs", overallTimeLeft))
    frame.timeRemaining:SetTextColor(1, 1, 0) -- Yellow
  end
end

-- Check challenge progress
function GH.Challenge.TimedGather:CheckProgress()
  -- Only process if the challenge is active
  if not GatherHeroDB.challenges or
      not GatherHeroDB.challenges.enabled or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
    return
  end

  local data = GatherHeroDB.challenges.timedGatherData
  if not data then return end

  -- FORCE FIX: Ensure timeWindow is always 20 seconds
  if data.timeWindow ~= 20 then
    data.timeWindow = 20
    -- Update the next gather time based on the last gather
    if data.lastGatherTime then
      data.nextGatherTime = data.lastGatherTime + 20
    end
  end

  local currentTime = GetTime()
  -- Update the UI with current status
  self:UpdateUI()

  -- Check if overall time limit has been reached
  if currentTime >= data.endTime then
    -- Time's up!
    if not GatherHeroDB.challenges.challengeCompleted then
      -- Check if actually completed (in case the event handling missed it)
      if data.gathersCompleted >= data.requiredGathers then
        -- Actually completed!
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        GH.ChallengeMode:ShowCompletionMessage(
          "Timed Gather Challenge Complete!",
          string.format("You've gathered %d times within the time limit!", data.gathersCompleted)
        )

        -- Also show as an objective popup
        if GH.ObjectivePopup then
          GH.ObjectivePopup:ShowCompletion(GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER)
        end

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Complete the challenge
        GH.ChallengeMode:CompleteChallenge(true)

        -- Start the next challenge
        C_Timer.After(3, function()
          -- Start Combat Gather challenge with safety checks
          local requiredGathers = 5 -- Default value
          local timeLimit = 300     -- Default value

          -- Try to get values from settings if they exist
          if GatherHeroDB and GatherHeroDB.challenges and
              GatherHeroDB.challenges.settings and
              GatherHeroDB.challenges.settings.combatGather then
            requiredGathers = GatherHeroDB.challenges.settings.combatGather.requiredGathers or requiredGathers
            timeLimit = GatherHeroDB.challenges.settings.combatGather.timeLimit or timeLimit
          end

          local params = {
            requiredGathers = requiredGathers,
            timeLimit = timeLimit
          }

          -- Make sure the challenge type is defined
          if GH.ChallengeMode.CHALLENGE_TYPES and GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
            GH.ChallengeMode:StartNextChallenge(GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER, params)
          else
            print("|cFFFF0000Gather Hero:|r Could not start Combat Gather challenge - challenge type not registered.")
          end
        end)
      else
        -- Challenge failed
        GH.ChallengeMode:ShowCompletionMessage(
          "Challenge Failed!",
          string.format("Time's up! You gathered %d/%d times.",
            data.gathersCompleted, data.requiredGathers)
        )

        -- Play failure sound
        PlaySoundFile("Sound\\Interface\\LevelUp", "Master") -- Built-in UI sound

        -- Complete the challenge (failed)
        GH.ChallengeMode:CompleteChallenge(false)
      end
    end
    return
  end

  -- Check if the time window for the next gather has expired
  if currentTime >= data.nextGatherTime then
    -- Player failed to gather within the time window
    GH.ChallengeMode:ShowCompletionMessage(
      "Challenge Failed!",
      string.format("You didn't gather within %d seconds! Got %d/%d gathers.",
        data.timeWindow, data.gathersCompleted, data.requiredGathers)
    )

    -- Play failure sound
    PlaySoundFile("Sound\\Interface\\LevelUp", "Master") -- Built-in UI sound

    -- Complete the challenge (failed)
    GH.ChallengeMode:CompleteChallenge(false)
    return
  end

  -- If we're getting close to the time window limit, warn the player
  local timeToNextGather = data.nextGatherTime - currentTime
  if timeToNextGather <= 5 and timeToNextGather > 4.9 then
    -- Show a warning at 5 seconds
    if GH.ObjectivePopup then
      GH.ObjectivePopup:Show(
        string.format("Warning: %.0f seconds to gather!", timeToNextGather),
        1
      )
    end

    -- Play warning sound
    PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
  elseif timeToNextGather <= 3 and timeToNextGather > 2.9 then
    -- Show a final warning at 3 seconds
    if GH.ObjectivePopup then
      GH.ObjectivePopup:Show(
        string.format("URGENT: %.0f seconds to gather!", timeToNextGather),
        1
      )
    end

    -- Play urgent warning sound
    PlaySoundFile("Sound\\Interface\\AlarmClockWarning3.ogg", "Master")
  end

  -- Check again in 0.1 seconds (more frequent updates for accurate timing)
  C_Timer.After(0.1, function() GH.Challenge.TimedGather:CheckProgress() end)
end

-- Make sure challenge type is registered
function GH.Challenge.TimedGather:EnsureChallengeTypeRegistered()
  if not GH.ChallengeMode or not GH.ChallengeMode.CHALLENGE_TYPES then
    -- Try again later
    C_Timer.After(1, function() self:EnsureChallengeTypeRegistered() end)
    return
  end

  -- Types are available, no need to register our own
  return true
end

-- Register challenge type and initialize
GH.Challenge.TimedGather:EnsureChallengeTypeRegistered()
GH.Challenge.TimedGather:Initialize()
