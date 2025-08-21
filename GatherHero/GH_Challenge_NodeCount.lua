-- GH_Challenge_NodeCount.lua
-- Node Count Challenge for Gather Hero addon
-- Challenge: Loot X nodes within Y minutes

local _, GH = ...

-- Create a namespace for the challenge
GH.Challenge = GH.Challenge or {}
GH.Challenge.NodeCount = {}

-- Initialize NodeCount challenge
function GH.Challenge.NodeCount:Initialize()
  -- Wait until main addon is loaded
  if not GH.ChallengeMode then
    C_Timer.After(1, function() self:Initialize() end)
    return
  end

  -- Make sure challenge types are defined in main module
  if not GH.ChallengeMode.CHALLENGE_TYPES then
    print("|cFFFF0000Gather Hero:|r Challenge types not defined in ChallengeMode")
  end

  -- Register default settings
  self:RegisterDefaultSettings()

  -- Register challenge handlers
  self:RegisterChallengeHandlers()
end

-- Register default settings
function GH.Challenge.NodeCount:RegisterDefaultSettings()
  -- Initialize saved variables if needed
  if not GatherHeroDB then return end
  if not GatherHeroDB.challenges then GatherHeroDB.challenges = {} end
  if not GatherHeroDB.challenges.settings then GatherHeroDB.challenges.settings = {} end

  -- Default settings for node count challenge
  if not GatherHeroDB.challenges.settings.nodeCount then
    GatherHeroDB.challenges.settings.nodeCount = {
      nodeTarget = 10,       -- Loot 10 nodes
      timeLimit = 5,         -- Within 5 minutes
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
function GH.Challenge.NodeCount:RegisterChallengeHandlers()
  -- Hook into the main challenge system
  if not GH.ChallengeMode.StartChallenge then
    -- Function doesn't exist yet, try again later
    C_Timer.After(1, function() self:RegisterChallengeHandlers() end)
    return
  end

  -- Override the existing challenge start function
  local originalStartChallenge = GH.ChallengeMode.StartChallenge
  GH.ChallengeMode.StartChallenge = function(self, challengeType, params)
    -- Handle Node Count challenge
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
      -- Start countdown
      GH.ChallengeMode:StartCountdown(function()
        -- IMPORTANT: Set the first challenge start time
        GH:EnsureChallengeTimeTracking()

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
        local nodeTarget = params and params.nodeTarget or GatherHeroDB.challenges.settings.nodeCount.nodeTarget
        local timeLimit = params and params.timeLimit or GatherHeroDB.challenges.settings.nodeCount.timeLimit

        -- Store challenge data
        GatherHeroDB.challenges.nodeCountData = {
          nodeTarget = nodeTarget,
          timeLimit = timeLimit,
          endTime = GetTime() + (timeLimit * 60),
          nodesGathered = 0
        }

        -- Set up progress tracking
        GatherHeroDB.challenges.challengeProgress = 0
        GatherHeroDB.challenges.challengeGoal = nodeTarget
        GatherHeroDB.challenges.challengeCompleted = false

        -- Show challenge instructions
        GH.ChallengeMode:ShowChallengeInstructions(
          "Node Count Challenge",
          string.format("Gather %d nodes within %d minutes!", nodeTarget, timeLimit)
        )

        -- Log challenge info to console
        print(string.format("|cFF00FF00Gather Hero Challenge:|r Node Count: Gather %d nodes within %d minutes!",
          nodeTarget, timeLimit))

        -- Start challenge timer
        C_Timer.After(1, function() GH.Challenge.NodeCount:CheckProgress() end)
      end)

      return true
    else
      -- Pass other challenge types to the original function
      return originalStartChallenge(self, challengeType, params)
    end
  end

  -- Hook into node gathering system directly through GH.nodeCount
  local originalUpdateCounter = GH.UpdateCounter
  GH.UpdateCounter = function(self)
    -- Call original function first
    originalUpdateCounter(self)

    -- Check if node count challenge is active
    if GatherHeroDB.challenges and
        GatherHeroDB.challenges.enabled and
        GatherHeroDB.challenges.activeChallenge == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
      -- Get challenge data
      local data = GatherHeroDB.challenges.nodeCountData
      if not data then return end

      -- The GH.nodeCount variable is the accurate node count maintained by the addon
      local currentNodeCount = self.nodeCount or 0

      -- Only update if the node count has increased
      if currentNodeCount > data.nodesGathered then
        -- Update to the current node count
        local nodesAdded = currentNodeCount - data.nodesGathered
        data.nodesGathered = currentNodeCount

        -- Update progress
        GatherHeroDB.challenges.challengeProgress = data.nodesGathered

        if GH.ObjectivePopup and nodesAdded > 0 then
          GH.ObjectivePopup:ShowNodeCountProgress(data.nodesGathered, data.nodeTarget)
        end

        -- Check if challenge is complete
        if data.nodesGathered >= data.nodeTarget then
          -- Challenge completed!
          GatherHeroDB.challenges.challengeCompleted = true

          -- Show completion message
          GH.ChallengeMode:ShowCompletionMessage(
            "Node Count Challenge Complete!",
            string.format("You've gathered %d nodes!", data.nodesGathered)
          )

          -- Play completion sound
          PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

          -- Start the next challenge
          C_Timer.After(3, function()
            -- Start High Value Node challenge
            local params = {
              multiplier = GatherHeroDB.challenges.settings.highValueNode.multiplier
            }
            GH.ChallengeMode:StartNextChallenge(GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE, params)
          end)
        end
      end
    end
  end

  -- Add a function to start the next challenge
  GH.ChallengeMode.StartNextChallenge = function(self, challengeType, params)
    -- Show challenge instructions
    if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
      -- Set up the challenge
      GatherHeroDB.challenges.enabled = true
      GatherHeroDB.challenges.activeChallenge = challengeType

      -- Get multiplier parameter
      local multiplier = params and params.multiplier or
          (GatherHeroDB.challenges.settings.highValueNode and
            GatherHeroDB.challenges.settings.highValueNode.multiplier or 2.5)

      -- Store challenge data
      GatherHeroDB.challenges.settings.highValueNode.currentMultiplier = multiplier
      GatherHeroDB.challenges.challengeGoal = 0 -- Will be set when first node is gathered
      GatherHeroDB.challenges.challengeProgress = 0
      GatherHeroDB.challenges.challengeCompleted = false

      -- Show challenge instructions
      GH.ChallengeMode:ShowChallengeInstructions(
        "High Value Node Challenge",
        string.format("Find a node worth at least %.1fx your average node value!", multiplier)
      )

      -- Log challenge info to console
      print(string.format(
        "|cFF00FF00Gather Hero Challenge:|r High Value Node: Find a node worth at least %.1fx your average node value!",
        multiplier))
    elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
      -- Set up the challenge
      GatherHeroDB.challenges.enabled = true
      GatherHeroDB.challenges.activeChallenge = challengeType
      GatherHeroDB.challenges.challengeStartTime = GetTime()

      -- Get challenge parameters
      local timeWindow = params and params.timeWindow or
          (GatherHeroDB.challenges.settings.timedGather and
            GatherHeroDB.challenges.settings.timedGather.timeWindow or 10)
      local totalDuration = params and params.totalDuration or
          (GatherHeroDB.challenges.settings.timedGather and
            GatherHeroDB.challenges.settings.timedGather.totalDuration or 100)
      local requiredGathers = params and params.requiredGathers or
          (GatherHeroDB.challenges.settings.timedGather and
            GatherHeroDB.challenges.settings.timedGather.requiredGathers or 10)

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
        string.format("Gather every %d seconds for a total of %d gathers!",
          timeWindow, requiredGathers)
      )

      -- Log challenge info to console
      print(string.format(
        "|cFF00FF00Gather Hero Challenge:|r Timed Gather: Gather every %d seconds for a total of %d gathers!",
        timeWindow, requiredGathers))

      -- Start challenge timer
      C_Timer.After(0.1, function()
        if GH.Challenge and GH.Challenge.TimedGather and GH.Challenge.TimedGather.CheckProgress then
          GH.Challenge.TimedGather:CheckProgress()
        else
          print("|cFFFF0000Gather Hero:|r Error: Could not start Timed Gather challenge timer")
        end
      end)
    end
  end
end

-- Check challenge progress
function GH.Challenge.NodeCount:CheckProgress()
  -- Only process if the challenge is active
  if not GatherHeroDB.challenges or
      not GatherHeroDB.challenges.enabled or
      GatherHeroDB.challenges.activeChallenge ~= GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
    return
  end

  local data = GatherHeroDB.challenges.nodeCountData
  if not data then return end

  local currentTime = GetTime()

  -- Check if time limit has been reached
  if currentTime >= data.endTime then
    -- Time's up!
    if not GatherHeroDB.challenges.challengeCompleted then
      -- Check if actually completed (in case the event handling missed it)
      if data.nodesGathered >= data.nodeTarget then
        -- Actually completed!
        GatherHeroDB.challenges.challengeCompleted = true

        -- Show completion message
        GH.ChallengeMode:ShowCompletionMessage(
          "Node Count Challenge Complete!",
          string.format("You've gathered %d nodes!", data.nodesGathered)
        )

        -- Play completion sound
        PlaySoundFile("Interface\\AddOns\\GatherHero\\Sounds\\anime-wow.ogg", "Master")

        -- Start the next challenge
        C_Timer.After(3, function()
          -- Start High Value Node challenge
          local params = {
            multiplier = GatherHeroDB.challenges.settings.highValueNode.multiplier
          }
          GH.ChallengeMode:StartNextChallenge(GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE, params)
        end)
      else
        -- Challenge failed
        GH.ChallengeMode:ShowCompletionMessage(
          "Challenge Failed!",
          string.format("Time's up! You gathered %d/%d nodes.",
            data.nodesGathered, data.nodeTarget)
        )

        -- Play failure sound
        PlaySoundFile("Sound\\Interface\\LevelUp", "Master") -- Built-in UI sound

        -- Complete the challenge (failed)
        GH.ChallengeMode:CompleteChallenge(false)
      end
    end
    return
  end


  C_Timer.After(1, function() GH.Challenge.NodeCount:CheckProgress() end)
end

-- Initialize the challenge
GH.Challenge.NodeCount:Initialize()
