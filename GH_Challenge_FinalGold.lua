-- GH_Challenge_FinalGold.lua
-- Final Gold Challenge for Gather Hero addon
-- Challenge: Gather 1.5x the total gold earned during all previous challenges within the same time spent

local _, GH = ...

-- Create a namespace for the challenge
GH.Challenge = GH.Challenge or {}
GH.Challenge.FinalGold = {}

-- Initialize FinalGold challenge
function GH.Challenge.FinalGold:Initialize()
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

  -- Register the final gold challenge type if not already registered
  self:EnsureChallengeTypeRegistered()

  -- Register default settings
  self:RegisterDefaultSettings()

  -- Register challenge handlers
  self:RegisterChallengeHandlers()
end

-- Make sure challenge type is registered
function GH.Challenge.FinalGold:EnsureChallengeTypeRegistered()
  if not GH.ChallengeMode or not GH.ChallengeMode.CHALLENGE_TYPES then
    -- Try again later
    C_Timer.After(1, function() self:EnsureChallengeTypeRegistered() end)
    return
  end

  -- Register our challenge type if not already defined
  if not GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
    GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD = 6
  end

  return true
end

-- Register default settings
function GH.Challenge.FinalGold:RegisterDefaultSettings()
  -- Initialize saved variables if needed
  if not GatherHeroDB then return end
  if not GatherHeroDB.challenges then GatherHeroDB.challenges = {} end
  if not GatherHeroDB.challenges.settings then GatherHeroDB.challenges.settings = {} end

  -- Default settings for final gold challenge
  if not GatherHeroDB.challenges.settings.finalGold then
    GatherHeroDB.challenges.settings.finalGold = {
      goldMultiplier = 1.5,  -- Target is 1.5x total gold earned so far
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
function GH.Challenge.FinalGold:RegisterChallengeHandlers()
  -- Hook into the main challenge system
  if not GH.ChallengeMode.StartChallenge then
    -- Function doesn't exist yet, try again later
    C_Timer.After(1, function() self:RegisterChallengeHandlers() end)
    return
  end

  -- Override the existing challenge start function
  local originalStartChallenge = GH.ChallengeMode.StartChallenge
  GH.ChallengeMode.StartChallenge = function(self, challengeType, params)
    -- Handle Final Gold challenge
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
      -- Use parameters or defaults for gold
      local totalGoldEarned = (params and params.goldEarned) or (GH.sessionGold or 0)

      -- Get the time from params, fall back to direct calculation if needed
      local totalTimeSpent = 5 -- Default fallback

      if params and params.timeSpent then
        totalTimeSpent = params.timeSpent
        print(string.format("|cFF00FF00Gather Hero Debug:|r Using timeSpent from params: %.2f minutes", totalTimeSpent))
      elseif GatherHeroDB.challenges.firstChallengeStartTime then
        -- Direct calculation from first challenge time
        local elapsedSec = GetTime() - GatherHeroDB.challenges.firstChallengeStartTime
        totalTimeSpent = elapsedSec / 60 -- Convert to minutes
        print(string.format("|cFF00FF00Gather Hero Debug:|r Directly calculated time: %.2f minutes", totalTimeSpent))
      else
        print(string.format("|cFF00FF00Gather Hero Debug:|r Using default time: %.2f minutes", totalTimeSpent))
      end

      -- Debug to verify values
      print(string.format("|cFF00FF00Gather Hero Debug:|r Final Gold params: Time=%.2f min, Gold=%s",
        totalTimeSpent, GH.ChallengeMode:FormatGold(totalGoldEarned)))

      -- Calculate target gold - round down to nice number
      local baseTargetGold = totalGoldEarned * 1.5

      -- Round down to nearest 500 gold (5000 copper is 0.5g, 500 gold is 5000000 copper)
      local targetGold
      if baseTargetGold >= 5000000 then                             -- 500g or more
        targetGold = math.floor(baseTargetGold / 5000000) * 5000000 -- Round to nearest 500g
      elseif baseTargetGold >= 100000 then                          -- 10g or more
        targetGold = math.floor(baseTargetGold / 100000) * 100000   -- Round to nearest 10g
      else
        targetGold = math.floor(baseTargetGold / 10000) * 10000     -- Round to nearest 1g
      end

      -- Ensure minimum value
      targetGold = math.max(50000, targetGold) -- At least 5g

      -- Round time to nearest minute and ensure minimum and maximum
      local timeLimit = math.ceil(totalTimeSpent)
      timeLimit = math.max(5, timeLimit)  -- At least 5 minutes
      timeLimit = math.min(60, timeLimit) -- Maximum 60 minutes (sanity check)

      -- Debug the calculated values
      print(string.format("|cFF00FF00Gather Hero Debug:|r Base target (1.5x): %s",
        GH.ChallengeMode:FormatGold(baseTargetGold)))
      print(string.format("|cFF00FF00Gather Hero Debug:|r Rounded target: %s",
        GH.ChallengeMode:FormatGold(targetGold)))
      print(string.format("|cFF00FF00Gather Hero Debug:|r Time limit: %d minutes", timeLimit))


      -- IMPORTANT: DO NOT reset the session - just store current gold
      local startingGold = GH.sessionGold or 0

      -- Set up the challenge
      GatherHeroDB.challenges.enabled = true
      GatherHeroDB.challenges.activeChallenge = challengeType
      GatherHeroDB.challenges.challengeStartTime = GetTime()

      -- Store challenge data
      GatherHeroDB.challenges.finalGoldData = {
        targetGold = targetGold,
        startingGold = startingGold,
        timeLimit = timeLimit * 60, -- Convert minutes to seconds
        endTime = GetTime() + (timeLimit * 60),
        goldGathered = 0
      }

      -- Set up progress tracking
      GatherHeroDB.challenges.challengeProgress = 0
      GatherHeroDB.challenges.challengeGoal = targetGold
      GatherHeroDB.challenges.challengeCompleted = false

      -- Show challenge instructions
      GH.ChallengeMode:ShowChallengeInstructions(
        "Final Gold Challenge",
        string.format("Gather %s within %d minutes!",
          GH.ChallengeMode:FormatGold(targetGold), timeLimit)
      )

      -- Log challenge info to console
      print(string.format("|cFF00FF00Gather Hero Challenge:|r Final Gold: Gather %s within %d minutes!",
        GH.ChallengeMode:FormatGold(targetGold), timeLimit))

      -- Make sure the UI is updated immediately
      if GH.ChallengeUI and GH.ChallengeUI.Update then
        GH.ChallengeUI:Update()
      end

      -- Start challenge timer
      C_Timer.After(1, function() GH.Challenge.FinalGold:CheckProgress() end)

      return true
    else
      -- Pass other challenge types to the original function
      return originalStartChallenge(self, challengeType, params)
    end
  end

  -- Hook into the StartNextChallenge function to add Final Gold as the next challenge
  if GH.ChallengeMode.StartNextChallenge then
    local originalStartNextChallenge = GH.ChallengeMode.StartNextChallenge
    GH.ChallengeMode.StartNextChallenge = function(self, challengeType, params)
      if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
        -- Calculate the total time spent on challenges so far
        local firstTime = GatherHeroDB.challenges.firstChallengeStartTime
        local elapsedTime = 0

        if firstTime then
          elapsedTime = GetTime() - firstTime
          -- Convert to minutes
          elapsedTime = elapsedTime / 60

          -- Log detailed time information
          local elapsedMin = math.floor(elapsedTime)
          local elapsedSec = math.floor((elapsedTime - elapsedMin) * 60)

          print(string.format("|cFF00FF00Gather Hero Debug:|r Challenge series started at: %s",
            date("%H:%M:%S", firstTime)))
          print(string.format("|cFF00FF00Gather Hero Debug:|r Current time: %s",
            date("%H:%M:%S", GetTime())))
          print(string.format("|cFF00FF00Gather Hero Debug:|r Total elapsed time: %d:%02d (%.2f minutes)",
            elapsedMin, elapsedSec, elapsedTime))
        else
          print("|cFFFF0000Gather Hero Debug:|r WARNING: No first challenge start time recorded!")
          elapsedTime = 9 -- Reasonable fallback
        end

        -- Get current gold earned
        local currentGold = GH.sessionGold or 0
        print(string.format("|cFF00FF00Gather Hero Debug:|r Starting Final Gold Challenge..."))
        print(string.format("|cFF00FF00Gather Hero Debug:|r Time spent: %.2f minutes, gold earned: %d",
          elapsedTime, currentGold))

        -- Set up the challenge data for Final Gold
        GatherHeroDB.challenges.enabled = true
        GatherHeroDB.challenges.activeChallenge = challengeType

        -- Parameters for final challenge
        local params = {
          timeSpent = elapsedTime,
          goldEarned = currentGold
        }

        -- Start the challenge - DON'T use the countdown
        GH.ChallengeMode:StartChallenge(GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD, params)
      else
        -- Call original function for other challenge types
        originalStartNextChallenge(self, challengeType, params)
      end
    end
  end

  -- Hook into ProcessLootMessage to track gold earned
  local originalProcessLootMessage = GH.ProcessLootMessage
  GH.ProcessLootMessage = function(self, msg)
    -- Call original function first
    originalProcessLootMessage(self, msg)

    -- Check if final gold challenge is active
    if GatherHeroDB.challenges and
        GatherHeroDB.challenges.enabled and
        GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
      -- Get challenge data
      local data = GatherHeroDB.challenges.finalGoldData
      if not data then return end

      -- Calculate current gold collected during this challenge
      local currentGold = (GH.sessionGold or 0) - data.startingGold
      data.goldGathered = currentGold

      -- Update progress
      GatherHeroDB.challenges.challengeProgress = currentGold

      -- Display progress message (only on significant gold increases)
      if currentGold - (data.lastReportedGold or 0) > 5000 then -- Only report every 50g change
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Gold collected: %s/%s",
          GH.ChallengeMode:FormatGold(currentGold), GH.ChallengeMode:FormatGold(data.targetGold)))

        data.lastReportedGold = currentGold

        -- Show progress popup
        if GH.ObjectivePopup then
          GH.ObjectivePopup:Show(
            string.format("Gold collected: %s/%s",
              GH.ChallengeMode:FormatGold(currentGold), GH.ChallengeMode:FormatGold(data.targetGold)),
            2.5
          )
        end
      end

      -- Force update the UI
      if GH.Challenge.FinalGold.UpdateUI then
        GH.Challenge.FinalGold:UpdateUI()
      end

      -- Check if challenge is complete
      if currentGold >= data.targetGold then
        -- Challenge completed!
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        GH.ChallengeMode:ShowCompletionMessage(
          "Final Gold Challenge Complete!",
          string.format("You've successfully gathered %s gold!",
            GH.ChallengeMode:FormatGold(currentGold))
        )

        -- Also show as an objective popup
        if GH.ObjectivePopup then
          GH.ObjectivePopup:Show(
            "Final Gold Challenge Complete!",
            4
          )
        end

        -- Log to console
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Final Gold Challenge Complete! You've gathered %s gold!",
          GH.ChallengeMode:FormatGold(currentGold)))

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Complete the challenge
        GH.ChallengeMode:CompleteChallenge(true)

        -- Show final congratulations
        C_Timer.After(2, function()
          GH.ChallengeMode:ShowCompletionMessage(
            "Challenge Series Complete!",
            "Congratulations! You've completed all gathering challenges!"
          )
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
      if GH.Challenge and GH.Challenge.FinalGold and GH.Challenge.FinalGold.UpdateUI then
        GH.Challenge.FinalGold:UpdateUI()
      end
    end
  end
end

-- Check challenge progress
function GH.Challenge.FinalGold:CheckProgress()
  -- Only process if the challenge is active
  if not GatherHeroDB.challenges or
      not GatherHeroDB.challenges.enabled or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
    return
  end

  local data = GatherHeroDB.challenges.finalGoldData
  if not data then return end

  local currentTime = GetTime()

  -- Calculate current gold collected during this challenge
  local currentGold = (GH.sessionGold or 0) - data.startingGold
  data.goldGathered = currentGold

  -- Update progress
  GatherHeroDB.challenges.challengeProgress = currentGold

  -- Update the UI with current status
  self:UpdateUI()

  -- Check if time limit has been reached
  if currentTime >= data.endTime then
    -- Time's up!
    if not GatherHeroDB.challenges.challengeCompleted then
      -- Check if actually completed (in case the event handling missed it)
      if currentGold >= data.targetGold then
        -- Actually completed!
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        GH.ChallengeMode:ShowCompletionMessage(
          "Final Gold Challenge Complete!",
          string.format("You've successfully gathered %s gold!",
            GH.ChallengeMode:FormatGold(currentGold))
        )

        -- Log to console
        print(string.format(
          "|cFF00FF00Gather Hero Challenge:|r Final Gold Challenge Complete! You've gathered %s gold!",
          GH.ChallengeMode:FormatGold(currentGold)))

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Complete the challenge
        GH.ChallengeMode:CompleteChallenge(true)

        -- Show final congratulations
        C_Timer.After(2, function()
          GH.ChallengeMode:ShowCompletionMessage(
            "Challenge Series Complete!",
            "Congratulations! You've completed all gathering challenges!"
          )
        end)
      else
        -- Challenge failed
        GH.ChallengeMode:ShowCompletionMessage(
          "Challenge Failed!",
          string.format("Time's up! You gathered %s/%s gold.",
            GH.ChallengeMode:FormatGold(currentGold), GH.ChallengeMode:FormatGold(data.targetGold))
        )

        -- Log to console
        print(string.format("|cFFFF0000Gather Hero Challenge:|r Failed! Time's up! You gathered %s/%s gold.",
          GH.ChallengeMode:FormatGold(currentGold), GH.ChallengeMode:FormatGold(data.targetGold)))

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
  C_Timer.After(1, function() GH.Challenge.FinalGold:CheckProgress() end)
end

-- Format gold value to not show "0s"
function GH.Challenge.FinalGold:FormatGoldClean(amount)
  local gold = math.floor(amount / 10000)
  local silver = math.floor((amount % 10000) / 100)

  if silver == 0 then
    return gold .. "g"
  else
    return gold .. "g " .. silver .. "s"
  end
end

-- Update UI elements
function GH.Challenge.FinalGold:UpdateUI()
  -- Only update if Challenge UI exists
  if not GH.ChallengeUI or not GH.ChallengeUI.frame then return end

  -- Only update if we're the active challenge
  if not GatherHeroDB or not GatherHeroDB.challenges or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
    return
  end

  -- Get challenge data
  local data = GatherHeroDB.challenges.finalGoldData
  if not data then return end

  -- Calculate current gold collected during this challenge
  local currentGold = (GH.sessionGold or 0) - data.startingGold
  data.goldGathered = currentGold

  -- Update UI elements
  local frame = GH.ChallengeUI.frame
  frame.title:SetText("Final Gold Challenge")
  frame.challengeType:SetText("Gold Rush")

  -- Update objective text
  frame.objective:SetText(string.format("Gather %s",
    self:FormatGoldClean(data.targetGold)))

  -- Update progress text and bar
  frame.progress:SetText(string.format("%s/%s gold collected",
    self:FormatGoldClean(currentGold), self:FormatGoldClean(data.targetGold)))

  -- Update progress bar
  local progressPercent = (currentGold / data.targetGold) * 100
  frame.progressBar:SetValue(math.min(100, progressPercent))

  -- Update time remaining
  local timeLeft = math.max(0, data.endTime - GetTime())
  local minutes = math.floor(timeLeft / 60)
  local seconds = math.floor(timeLeft % 60)
  frame.timeRemaining:SetText(string.format("Time: %d:%02d", minutes, seconds))

  -- Change color based on time left
  if timeLeft < 30 then
    frame.timeRemaining:SetTextColor(1, 0, 0)   -- Red when < 30 seconds
  elseif timeLeft < 60 then
    frame.timeRemaining:SetTextColor(1, 0.5, 0) -- Orange when < 1 minute
  else
    frame.timeRemaining:SetTextColor(1, 1, 0)   -- Yellow otherwise
  end
end

-- Initialize the challenge
GH.Challenge.FinalGold:Initialize()
