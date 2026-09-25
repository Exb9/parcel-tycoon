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

-- PlayerData.daily (DataSchema).
type DailyData = { lastClaimDay: number, step: number }

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

return Rewards
