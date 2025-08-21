-- GH_PointSystem.lua
-- Point system for Gather Hero challenges
-- Rewards players for speed and gold collection

local _, GH = ...

-- Create namespace for Points System
GH.PointSystem = {}

-- Initialize the point system
function GH.PointSystem:Initialize()
  -- Check if GatherHeroDB exists - if not, try again later
  if not GatherHeroDB then
    C_Timer.After(1, function() self:Initialize() end)
    return
  end

  -- Initialize saved variables
  if not GatherHeroDB.challenges then GatherHeroDB.challenges = {} end

  -- Create high scores table if it doesn't exist
  if not GatherHeroDB.highScores then
    GatherHeroDB.highScores = {
      challengeRuns = {}, -- Complete challenge runs
      topScores = {},     -- Top scores by category
      lastRun = nil       -- Most recent challenge run
    }
    print("|cFF00FF00Gather Hero Debug:|r Created highScores table")
  end

  -- Add safety checks to all functions that use highScores
  self:EnsureHighScoresExist()

  self.initialized = true
end

-- Helper function to ensure highScores exists
function GH.PointSystem:EnsureHighScoresExist()
  if not GatherHeroDB then return false end

  if not GatherHeroDB.highScores then
    GatherHeroDB.highScores = {
      challengeRuns = {},
      topScores = {},
      lastRun = nil
    }
    return true
  end

  return true
end

-- Calculate points for a challenge
function GH.PointSystem:CalculateChallengePoints(challengeType, success, duration, goal, progress)
  -- Base points for completing the challenge
  local points = 0

  -- Only award points for successful challenges
  if not success then return 0 end

  -- Calculate points based on challenge type
  if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.NODE_COUNT then
    -- Points = 100 base + bonus for speed (up to 100 extra points)
    -- Faster is better - standard is 5 minutes, so calculate bonus based on that
    local timeBonus = math.max(0, 100 - (duration / 3))
    points = 100 + math.floor(timeBonus)
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.HIGH_VALUE_NODE then
    -- Points = 100 base + value ratio bonus (up to 100 extra points)
    local valueBonus = 0
    if goal > 0 then
      -- How much the node exceeded the target (capped at 2x)
      local exceedRatio = math.min(2, progress / goal)
      valueBonus = 100 * (exceedRatio - 1)
    end
    points = 100 + math.floor(valueBonus)
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.TIMED_GATHER then
    -- Points = gathers completed * 20
    points = math.floor(progress * 20)
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.COMBAT_GATHER then
    -- Points = 150 base + 10 per gather
    points = 150 + math.floor(progress * 10)
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.ZONE_HOPPER then
    -- Points = 50 per zone completed
    points = math.floor(progress * 50)
  elseif challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
    -- Points = 200 base + percentage of target completed * 3
    if goal > 0 then
      local percentComplete = math.min(100, (progress / goal) * 100)
      points = 200 + math.floor(percentComplete * 3)
    else
      points = 200
    end
  end

  return math.floor(points)
end

-- Calculate total points for a complete challenge run
function GH.PointSystem:CalculateTotalPoints(challengeHistory)
  local totalPoints = 0
  local goldCollected = 0
  local totalTime = 0
  local challengesCompleted = 0

  -- Process each challenge in the history
  for _, challenge in ipairs(challengeHistory) do
    -- Add points for this challenge
    totalPoints = totalPoints + (challenge.points or 0)

    -- Track gold collected (for final gold challenge)
    if challenge.type == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
      goldCollected = challenge.progress or 0
    end

    -- Track total time
    totalTime = totalTime + (challenge.duration or 0)

    -- Count completed challenges
    if challenge.success then
      challengesCompleted = challengesCompleted + 1
    end
  end

  -- Bonus points for completing all challenges
  if challengesCompleted == 6 then
    -- Complete run bonus: 500 points
    totalPoints = totalPoints + 500

    -- Gold efficiency bonus: gold per minute * 0.5
    local goldPerMinute = 0
    if totalTime > 0 then
      goldPerMinute = (goldCollected / totalTime) * 60
    end
    totalPoints = totalPoints + math.floor(goldPerMinute * 0.5)
  end

  return math.floor(totalPoints)
end

-- Record a challenge completion
function GH.PointSystem:RecordChallengeCompletion(challengeType, success, duration, goal, progress)
  -- Make sure highScores exists
  if not self:EnsureHighScoresExist() then
    print("|cFFFF0000Gather Hero Error:|r Cannot record challenge - GatherHeroDB not initialized")
    return 0
  end
  -- Calculate points
  local points = self:CalculateChallengePoints(challengeType, success, duration, goal, progress)

  -- Get challenge name
  local challengeName = self:GetChallengeName(challengeType)

  -- Create challenge record
  local record = {
    type = challengeType,
    name = challengeName,
    success = success,
    duration = duration,
    goal = goal,
    progress = progress,
    points = points,
    date = date("%Y-%m-%d %H:%M:%S"),
    character = UnitName("player") .. "-" .. GetRealmName(),
  }

  -- Make sure highScores exists
  if not GatherHeroDB.highScores then
    GatherHeroDB.highScores = {
      challengeRuns = {}, -- Complete challenge runs
      topScores = {},     -- Top scores by category
      lastRun = nil       -- Most recent challenge run
    }
  end

  -- Add to current run if we don't have a record for this challenge type
  if not GatherHeroDB.highScores.lastRun then
    GatherHeroDB.highScores.lastRun = {
      challenges = {},
      date = date("%Y-%m-%d %H:%M:%S"),
      character = UnitName("player") .. "-" .. GetRealmName(),
      totalPoints = 0,
      completedChallenges = 0
    }
  end

  -- Check if we already have this challenge in the current run
  local exists = false
  for i, challenge in ipairs(GatherHeroDB.highScores.lastRun.challenges) do
    if challenge.type == challengeType then
      -- Update the existing challenge
      GatherHeroDB.highScores.lastRun.challenges[i] = record
      exists = true
      break
    end
  end

  -- Add if it doesn't exist
  if not exists then
    table.insert(GatherHeroDB.highScores.lastRun.challenges, record)
  end

  -- Update run statistics
  if success then
    GatherHeroDB.highScores.lastRun.completedChallenges = GatherHeroDB.highScores.lastRun.completedChallenges + 1
  end

  -- Calculate total points so far
  GatherHeroDB.highScores.lastRun.totalPoints = self:CalculateTotalPoints(GatherHeroDB.highScores.lastRun.challenges)

  -- If this was the final challenge and successfully completed, record the entire run
  if challengeType == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD and success then
    self:RecordCompletedRun()
  end

  -- Debug message
  print(string.format("|cFF00FF00Gather Hero Points:|r %s challenge: %d points",
    challengeName, points))

  return points
end

-- Record a completed challenge run
function GH.PointSystem:RecordCompletedRun()
  if not GatherHeroDB.highScores.lastRun then return end

  -- Calculate final points
  local finalPoints = self:CalculateTotalPoints(GatherHeroDB.highScores.lastRun.challenges)
  GatherHeroDB.highScores.lastRun.totalPoints = finalPoints

  -- Add total time
  local totalTime = 0
  for _, challenge in ipairs(GatherHeroDB.highScores.lastRun.challenges) do
    totalTime = totalTime + (challenge.duration or 0)
  end
  GatherHeroDB.highScores.lastRun.totalTime = totalTime

  -- Add the run to the challenge runs list
  table.insert(GatherHeroDB.highScores.challengeRuns, 1, CopyTable(GatherHeroDB.highScores.lastRun))

  -- Limit the number of stored runs
  while #GatherHeroDB.highScores.challengeRuns > 10 do
    table.remove(GatherHeroDB.highScores.challengeRuns)
  end

  -- Update top scores
  self:UpdateTopScores()

  -- Show points earned
  if GH.ObjectivePopup then
    GH.ObjectivePopup:Show(
      string.format("Challenge Series Complete! Total Score: %d points", finalPoints),
      5
    )
  end

  -- Debug info
  print(string.format("|cFF00FF00Gather Hero Points:|r Challenge series complete! Total score: %d points",
    finalPoints))

  -- Reset the last run
  GatherHeroDB.highScores.lastRun = nil
end

-- Get challenge name from type
function GH.PointSystem:GetChallengeName(challengeType)
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

-- Update top scores based on completed runs
function GH.PointSystem:UpdateTopScores()
  local topScores = GatherHeroDB.highScores.topScores

  -- Initialize categories if needed
  if not topScores.highestTotal then
    topScores.highestTotal = { score = 0, date = "", character = "" }
  end

  if not topScores.fastestTime then
    topScores.fastestTime = { time = 99999, date = "", character = "" }
  end

  if not topScores.mostGold then
    topScores.mostGold = { gold = 0, date = "", character = "" }
  end

  -- Check all runs for records
  for _, run in ipairs(GatherHeroDB.highScores.challengeRuns) do
    -- Check for highest total score
    if run.totalPoints > topScores.highestTotal.score then
      topScores.highestTotal.score = run.totalPoints
      topScores.highestTotal.date = run.date
      topScores.highestTotal.character = run.character
    end

    -- Check for fastest time (only for complete runs)
    if run.completedChallenges == 6 and run.totalTime < topScores.fastestTime.time then
      topScores.fastestTime.time = run.totalTime
      topScores.fastestTime.date = run.date
      topScores.fastestTime.character = run.character
    end

    -- Check for most gold (from Final Gold challenge)
    local finalGoldProgress = 0
    for _, challenge in ipairs(run.challenges) do
      if challenge.type == GH.ChallengeMode.CHALLENGE_TYPES.FINAL_GOLD then
        finalGoldProgress = challenge.progress or 0
        break
      end
    end

    if finalGoldProgress > topScores.mostGold.gold then
      topScores.mostGold.gold = finalGoldProgress
      topScores.mostGold.date = run.date
      topScores.mostGold.character = run.character
    end
  end
end

-- Initialize point system
GH.PointSystem:Initialize()
