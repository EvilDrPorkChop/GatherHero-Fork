-- GH_Challenge_CombatGather.lua
-- Combat Gather Challenge for Gather Hero addon
-- Challenge: Successfully gather nodes while in combat

local _, GH = ...

-- Create a namespace for the challenge
GH.Challenge = GH.Challenge or {}
GH.Challenge.CombatGather = {}

-- Initialize CombatGather challenge
function GH.Challenge.CombatGather:Initialize()
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

  -- Register the combat gather challenge type if not already registered
  self:EnsureChallengeTypeRegistered()

  -- Register default settings
  self:RegisterDefaultSettings()

  -- Register challenge handlers
  self:RegisterChallengeHandlers()
end

-- Make sure challenge types are available
function GH.Challenge.CombatGather:EnsureChallengeTypeRegistered()
  if not GH.ChallengeMode or not GH.ChallengeMode.CHALLENGE_TYPES then
    -- Try again later
    C_Timer.After(1, function() self:EnsureChallengeTypeRegistered() end)
    return
  end

  -- Types are available, no need to register our own
  return true
end

-- Register default settings
function GH.Challenge.CombatGather:RegisterDefaultSettings()
  -- Initialize saved variables if needed
  if not GatherHeroDB then return end
  if not GatherHeroDB.challenges then GatherHeroDB.challenges = {} end
  if not GatherHeroDB.challenges.settings then GatherHeroDB.challenges.settings = {} end

  -- Default settings for combat gather challenge
  if not GatherHeroDB.challenges.settings.combatGather then
    GatherHeroDB.challenges.settings.combatGather = {
      requiredGathers = 5,     -- Need to gather 5 times in combat
      timeLimit = 300,         -- Within 5 minutes
      allowedProfessions = {   -- Allowed professions
        ["Herbalism"] = true,
        ["Mining"] = true,
        ["Skinning"] = true,
        ["Fishing"] = true
      }
    }
  end
end

-- Register challenge handlers
function GH.Challenge.CombatGather:RegisterChallengeHandlers()
  -- Hook into the main challenge system
  if not GH.ChallengeMode.StartChallenge then
    -- Function doesn't exist yet, try again later
    C_Timer.After(1, function() self:RegisterChallengeHandlers() end)
    return
  end

  -- Override the existing challenge start function
  local originalStartChallenge = GH.ChallengeMode.StartChallenge
  GH.ChallengeMode.StartChallenge = function(self, challengeType, params)
    -- Handle Combat Gather challenge
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
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
        local requiredGathers = params and params.requiredGathers or
            GatherHeroDB.challenges.settings.combatGather.requiredGathers
        local timeLimit = params and params.timeLimit or
            GatherHeroDB.challenges.settings.combatGather.timeLimit

        -- Store challenge data
        GatherHeroDB.challenges.combatGatherData = {
          requiredGathers = requiredGathers,
          timeLimit = timeLimit,
          endTime = GetTime() + timeLimit,
          gathersCompleted = 0,
          playerDied = false
        }

        -- Set up progress tracking
        GatherHeroDB.challenges.challengeProgress = 0
        GatherHeroDB.challenges.challengeGoal = requiredGathers
        GatherHeroDB.challenges.challengeCompleted = false

        -- Show challenge instructions
        GH.ChallengeMode:ShowChallengeInstructions(
          "Combat Gather Challenge",
          string.format("Gather %d nodes while in combat!", requiredGathers)
        )

        -- Log challenge info to console
        print(string.format("|cFF00FF00Gather Hero Challenge:|r Combat Gather: Gather %d nodes while in combat!",
          requiredGathers))

        -- Make sure the UI is updated immediately
        if GH.ChallengeUI and GH.ChallengeUI.Update then
          GH.ChallengeUI:Update()
        end

        -- Start challenge timer
        C_Timer.After(1, function() GH.Challenge.CombatGather:CheckProgress() end)

        -- Register for combat events if not already registered
        if not self.combatEventsRegistered then
          GH.Challenge.CombatGather:RegisterCombatEvents()
        end
      end)

      return true
    else
      -- Pass other challenge types to the original function
      return originalStartChallenge(self, challengeType, params)
    end
  end

  -- Hook into the StartNextChallenge function to add Combat Gather as the next challenge
  if GH.ChallengeMode.StartNextChallenge then
    local originalStartNextChallenge = GH.ChallengeMode.StartNextChallenge
    GH.ChallengeMode.StartNextChallenge = function(self, challengeType, params)
      if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
        -- Set up the challenge data for Combat Gather
        GatherHeroDB.challenges.enabled = true
        GatherHeroDB.challenges.activeChallenge = challengeType
        GatherHeroDB.challenges.challengeStartTime = GetTime()

        -- Get parameters
        local requiredGathers = params and params.requiredGathers or
            GatherHeroDB.challenges.settings.combatGather.requiredGathers
        local timeLimit = params and params.timeLimit or
            GatherHeroDB.challenges.settings.combatGather.timeLimit

        -- Store challenge data
        GatherHeroDB.challenges.combatGatherData = {
          requiredGathers = requiredGathers,
          timeLimit = timeLimit,
          endTime = GetTime() + timeLimit,
          gathersCompleted = 0,
          playerDied = false
        }

        -- Set up progress tracking
        GatherHeroDB.challenges.challengeProgress = 0
        GatherHeroDB.challenges.challengeGoal = requiredGathers
        GatherHeroDB.challenges.challengeCompleted = false

        -- Show challenge instructions
        GH.ChallengeMode:ShowChallengeInstructions(
          "Combat Gather Challenge",
          string.format("Gather %d nodes while in combat!", requiredGathers)
        )

        -- Log challenge info to console
        print(string.format("|cFF00FF00Gather Hero Challenge:|r Combat Gather: Gather %d nodes while in combat!",
          requiredGathers))

        -- Start challenge timer
        C_Timer.After(1, function() GH.Challenge.CombatGather:CheckProgress() end)

        -- Register for combat events if not already registered
        if not self.combatEventsRegistered then
          GH.Challenge.CombatGather:RegisterCombatEvents()
        end
      else
        -- Call original function for other challenge types
        originalStartNextChallenge(self, challengeType, params)
      end
    end
  end

  -- Hook into ProcessLootMessage to track gathering in combat
  local originalProcessLootMessage = GH.ProcessLootMessage
  GH.ProcessLootMessage = function(self, msg)
    -- Call original function first
    originalProcessLootMessage(self, msg)

    -- Check if combat gather challenge is active
    if GatherHeroDB.challenges and
        GatherHeroDB.challenges.enabled and
        GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
      -- Get challenge data
      local data = GatherHeroDB.challenges.combatGatherData
      if not data then return end

      -- Check if player is in combat
      if UnitAffectingCombat("player") then
        -- Check if this node was already counted this frame (prevent double-counting)
        if data.lastProcessedNode and (GetTime() - data.lastProcessedNode) < 0.1 then
          return   -- Skip this to prevent double counting
        end

        -- Record this gather
        data.lastProcessedNode = GetTime()
        data.gathersCompleted = data.gathersCompleted + 1

        -- Update progress
        GatherHeroDB.challenges.challengeProgress = data.gathersCompleted

        -- Show progress popup
        if GH.ObjectivePopup then
          GH.ObjectivePopup:Show(
            string.format("Combat Gather: %d/%d completed",
              data.gathersCompleted, data.requiredGathers),
            2.5
          )
        end

        -- Play sound for successful gather
        PlaySoundFile("Sound\\Interface\\LevelUp.ogg", "Master")

        -- Force update the UI
        if GH.Challenge.CombatGather.UpdateUI then
          GH.Challenge.CombatGather:UpdateUI()
        end

        -- Check if challenge is complete
        if data.gathersCompleted >= data.requiredGathers then
          -- Challenge completed!
          GatherHeroDB.challenges.challengeCompleted = true

          -- Show completion message
          GH.ChallengeMode:ShowCompletionMessage(
            "Combat Gather Challenge Complete!",
            string.format("You've successfully gathered %d times while in combat!", data.gathersCompleted)
          )

          -- Also show as an objective popup
          if GH.ObjectivePopup then
            GH.ObjectivePopup:Show(
              "Combat Gather Challenge Complete!",
              4
            )
          end

          -- Play completion sound
          PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

          -- Complete the challenge
          GH.ChallengeMode:CompleteChallenge(true)

          -- Start the next challenge
          C_Timer.After(3, function()
            -- Start Zone Hopper challenge with safety checks
            local requiredZones = 3   -- Default value
            local nodesPerZone = 3    -- Default value
            local timeLimit = 600     -- Default value

            -- Try to get values from settings if they exist
            if GatherHeroDB and GatherHeroDB.challenges and
                GatherHeroDB.challenges.settings and
                GatherHeroDB.challenges.settings.zoneHopper then
              requiredZones = GatherHeroDB.challenges.settings.zoneHopper.requiredZones or requiredZones
              nodesPerZone = GatherHeroDB.challenges.settings.zoneHopper.nodesPerZone or nodesPerZone
              timeLimit = GatherHeroDB.challenges.settings.zoneHopper.timeLimit or timeLimit
            end

            local params = {
              requiredZones = requiredZones,
              nodesPerZone = nodesPerZone,
              timeLimit = timeLimit
            }

            -- Make sure the challenge type is defined
            if GH.ChallengeMode.CHALLENGE_TYPES and GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
              GH.ChallengeMode:StartNextChallenge(GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER, params)
            else
              print("|cFFFF0000Gather Hero:|r Could not start Zone Hopper challenge - challenge type not registered.")
            end
          end)
        end
      else
        -- Player is not in combat, provide a hint
        if GetTime() - (data.lastCombatHint or 0) > 10 then   -- Only show hint every 10 seconds
          print("|cFFFFFF00Gather Hero Challenge:|r You need to be in combat when gathering!")
          data.lastCombatHint = GetTime()
        end
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
      if GH.Challenge and GH.Challenge.CombatGather and GH.Challenge.CombatGather.UpdateUI then
        GH.Challenge.CombatGather:UpdateUI()
      end
    end
  end
end

-- Register for combat events
function GH.Challenge.CombatGather:RegisterCombatEvents()
  -- Create frame for events if it doesn't exist
  if not self.eventFrame then
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
      if event == "PLAYER_REGEN_DISABLED" then
        -- Player entered combat
        self:OnCombatEnter()
      elseif event == "PLAYER_REGEN_ENABLED" then
        -- Player left combat
        self:OnCombatLeave()
      elseif event == "PLAYER_DEAD" then
        -- Player died
        self:OnPlayerDeath()
      end
    end)
  end

  -- Register for combat events
  self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
  self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  self.eventFrame:RegisterEvent("PLAYER_DEAD")

  self.combatEventsRegistered = true
end

-- Unregister combat events
function GH.Challenge.CombatGather:UnregisterCombatEvents()
  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
  end

  self.combatEventsRegistered = false
end

-- Handle player entering combat
function GH.Challenge.CombatGather:OnCombatEnter()
  -- Check if the combat gather challenge is active
  if GatherHeroDB.challenges and
      GatherHeroDB.challenges.enabled and
      GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    -- Show popup that player is in combat
    if GH.ObjectivePopup then
      GH.ObjectivePopup:Show("In combat - nodes gathered now will count!", 2)
    end
  end
end

-- Handle player leaving combat
function GH.Challenge.CombatGather:OnCombatLeave()
  -- Check if the combat gather challenge is active
  if GatherHeroDB.challenges and
      GatherHeroDB.challenges.enabled and
      GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    -- Show popup that player left combat
    if GH.ObjectivePopup then
      GH.ObjectivePopup:Show("Combat ended - find more enemies!", 2)
    end
  end
end

-- Handle player death
function GH.Challenge.CombatGather:OnPlayerDeath()
  -- Check if the combat gather challenge is active
  if GatherHeroDB.challenges and
      GatherHeroDB.challenges.enabled and
      GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    -- Get challenge data
    local data = GatherHeroDB.challenges.combatGatherData
    if not data then return end

    -- Mark player as died
    data.playerDied = true

    -- Show failure message
    GH.ChallengeMode:ShowCompletionMessage(
      "Challenge Failed!",
      "You died during the Combat Gather Challenge."
    )

    -- Complete the challenge (failed)
    GH.ChallengeMode:CompleteChallenge(false)
  end
end

-- Check challenge progress
function GH.Challenge.CombatGather:CheckProgress()
  -- Only process if the challenge is active
  if not GatherHeroDB.challenges or
      not GatherHeroDB.challenges.enabled or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    return
  end

  local data = GatherHeroDB.challenges.combatGatherData
  if not data then return end

  local currentTime = GetTime()
  -- Update the UI with current status
  self:UpdateUI()

  -- Check if time limit has been reached
  if currentTime >= data.endTime then
    -- Time's up!
    if not GatherHeroDB.challenges.challengeCompleted then
      -- Check if actually completed (in case the event handling missed it)
      if data.gathersCompleted >= data.requiredGathers then
        -- Actually completed!
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        GH.ChallengeMode:ShowCompletionMessage(
          "Combat Gather Challenge Complete!",
          string.format("You've successfully gathered %d nodes in combat!", data.gathersCompleted)
        )

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Complete the challenge
        GH.ChallengeMode:CompleteChallenge(true)
      else
        -- Challenge failed
        GH.ChallengeMode:ShowCompletionMessage(
          "Challenge Failed!",
          string.format("Time's up! You gathered %d/%d nodes in combat.",
            data.gathersCompleted, data.requiredGathers)
        )

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
  C_Timer.After(1, function() GH.Challenge.CombatGather:CheckProgress() end)
end

-- Update UI elements
function GH.Challenge.CombatGather:UpdateUI()
  -- Only update if Challenge UI exists
  if not GH.ChallengeUI or not GH.ChallengeUI.frame then return end

  -- Only update if we're the active challenge
  if not GatherHeroDB or not GatherHeroDB.challenges or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    return
  end

  -- Get challenge data
  local data = GatherHeroDB.challenges.combatGatherData
  if not data then return end

  -- Update UI elements
  local frame = GH.ChallengeUI.frame
  frame.title:SetText("Combat Gather Challenge")
  frame.challengeType:SetText("Combat Gathering")

  -- Update objective text
  frame.objective:SetText(string.format("Gather %d nodes while in combat", data.requiredGathers))

  -- Update progress text and bar
  frame.progress:SetText(string.format("%d/%d nodes gathered in combat",
    data.gathersCompleted, data.requiredGathers))

  -- Update progress bar
  local progressPercent = (data.gathersCompleted / data.requiredGathers) * 100
  frame.progressBar:SetValue(progressPercent)

  -- Update time remaining
  local timeLeft = math.max(0, data.endTime - GetTime())
  local minutes = math.floor(timeLeft / 60)
  local seconds = math.floor(timeLeft % 60)
  frame.timeRemaining:SetText(string.format("Time: %d:%02d", minutes, seconds))

  -- Change color based on time left
  if timeLeft < 30 then
    frame.timeRemaining:SetTextColor(1, 0, 0)     -- Red when < 30 seconds
  elseif timeLeft < 60 then
    frame.timeRemaining:SetTextColor(1, 0.5, 0)   -- Orange when < 1 minute
  else
    frame.timeRemaining:SetTextColor(1, 1, 0)     -- Yellow otherwise
  end

  -- Highlight if player is in combat
  if UnitAffectingCombat("player") then
    frame.progress:SetTextColor(0, 1, 0)     -- Green when in combat
  else
    frame.progress:SetTextColor(1, 0.5, 0)   -- Orange when not in combat
  end
end

-- Initialize the challenge
GH.Challenge.CombatGather:Initialize()
