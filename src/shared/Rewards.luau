--!strict
-- Resolves reward definitions (Config.Rewards) into concrete grants, and the daily reward rules.
-- Pure logic; RewardService applies the grants.

local Config = require("./Config")
local RewardsConfig = require("./Config/Rewards")
local Rng = require("./Rng")

export type Reward = RewardsConfig.Reward
export type WeightedReward = RewardsConfig.WeightedReward

export type Grant = {
	cash: number,
	boostMinutes: number,
}

export type Context = {
	-- Estimated income per minute (Economy.estimatedIncome).
	incomePerMinute: number,
	-- Value of the package that triggered the reward (mystery bonus).
	packageValue: number?,
}

-- PlayerData.daily, .playtime and .milestones (DataSchema).
type DailyData = { lastClaimDay: number, step: number }
type PlaytimeData = { day: number, seconds: number, claimed: number }
type MilestoneData = { [string]: boolean }

local Rewards = {}

function Rewards.resolve(reward: Reward, context: Context): Grant
	if reward.kind == "boost" then
		return { cash = 0, boostMinutes = reward.minutes or 0 }
	end
	local cash = 0
	if reward.incomeMinutes then
		cash += context.incomePerMinute * reward.incomeMinutes
	end
	if reward.packageValues and context.packageValue then
		cash += context.packageValue * reward.packageValues
	end
	return { cash = math.max(reward.minimumCash or 0, math.floor(cash)), boostMinutes = 0 }
end

function Rewards.rollMystery(random: () -> number): WeightedReward
	return Rng.pickWeighted(Config.Rewards.mystery, function(entry)
		return entry.weight
	end, random)
end

-- Odds of every mystery bonus in percent, for the info window.
function Rewards.mysteryOdds(): { { id: string, percent: number } }
	local total = 0
	for _, entry in Config.Rewards.mystery do
		total += entry.weight
	end
	local odds = {}
	for _, entry in Config.Rewards.mystery do
		table.insert(odds, { id = entry.id, percent = entry.weight / total * 100 })
	end
	return odds
end

-- Daily rewards -------------------------------------------------------------------------------------

function Rewards.canClaimDaily(daily: DailyData, day: number): boolean
	return daily.lastClaimDay < day
end

-- The calendar step (1-7) and reward the next claim gives.
function Rewards.nextDaily(daily: DailyData): (number, Reward)
	local calendar = Config.Rewards.daily
	local step = daily.step % #calendar + 1
	return step, calendar[step]
end

-- Advances the calendar. Returns the reward, or nil if today's reward was already claimed.
function Rewards.claimDaily(daily: DailyData, day: number): Reward?
	if not Rewards.canClaimDaily(daily, day) then
		return nil
	end
	local step, reward = Rewards.nextDaily(daily)
	daily.step = step
	daily.lastClaimDay = day
	return reward
end

-- Playtime gifts ------------------------------------------------------------------------------------

-- Starts a new day of playtime gifts when the UTC day changed. Returns true if it reset.
function Rewards.ensurePlaytimeDay(playtime: PlaytimeData, day: number): boolean
	if playtime.day == day then
		return false
	end
	playtime.day = day
	playtime.seconds = 0
	playtime.claimed = 0
	return true
end

-- The next gift to open today (index into Config.Rewards.playtime), or nil when all are opened.
function Rewards.nextGift(playtime: PlaytimeData): (number?, RewardsConfig.PlaytimeGift?)
	local index = playtime.claimed + 1
	local gift = Config.Rewards.playtime[index]
	if gift == nil then
		return nil, nil
	end
	return index, gift
end

-- Seconds until the next gift can be opened (0 = ready), or nil when all are opened today.
function Rewards.secondsToNextGift(playtime: PlaytimeData): number?
	local _, gift = Rewards.nextGift(playtime)
	if gift == nil then
		return nil
	end
	return math.max(0, gift.minutes * 60 - playtime.seconds)
end

-- Opens the next gift if its time has come. Returns its reward, or nil.
function Rewards.openGift(playtime: PlaytimeData, day: number): Reward?
	Rewards.ensurePlaytimeDay(playtime, day)
	local _, gift = Rewards.nextGift(playtime)
	if gift == nil or playtime.seconds < gift.minutes * 60 then
		return nil
	end
	playtime.claimed += 1
	return gift.reward
end

-- Rebirth milestones ------------------------------------------------------------------------------

-- Milestones reached with `rebirths` that were not rewarded yet, in order.
function Rewards.pendingMilestones(milestones: MilestoneData, rebirths: number): { RewardsConfig.Milestone }
	local pending = {}
	for _, milestone in Config.Rewards.rebirthMilestones do
		if rebirths >= milestone.rebirths and not milestones[tostring(milestone.rebirths)] then
			table.insert(pending, milestone)
		end
	end
	return pending
end

-- Codes -------------------------------------------------------------------------------------------

-- Codes are typed by kids on phones: ignore case, spaces and punctuation.
function Rewards.normalizeCode(text: string): string
	return string.upper((string.gsub(text, "[^%w]", "")))
end

return Rewards
