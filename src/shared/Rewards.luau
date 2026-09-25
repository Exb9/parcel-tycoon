--!strict
-- Resolves reward definitions (Config.Rewards, products, milestones) into concrete grants, and the
-- login calendar / playtime gift rules. Pure logic; RewardService applies the grants.

local Config = require("./Config")
local DataSchema = require("./DataSchema")
local RewardsConfig = require("./Config/Rewards")
local Rng = require("./Rng")

export type Reward = RewardsConfig.Reward
export type WeightedReward = RewardsConfig.WeightedReward

export type Grant = {
	cash: number,
	boostMinutes: number,
	cosmeticId: string?,
}

export type Context = {
	-- Estimated income per minute (Economy.estimatedIncome).
	incomePerMinute: number,
	-- Value of the package that triggered the reward (mystery packages).
	packageValue: number?,
	ownsCosmetic: (cosmeticId: string) -> boolean,
}

type DailyData = typeof(DataSchema.template().daily)
type PlaytimeData = typeof(DataSchema.template().playtime)

local Rewards = {}

function Rewards.resolve(reward: Reward, context: Context): Grant
	if reward.kind == "cosmetic" then
		local cosmeticId = reward.cosmeticId
		if cosmeticId and not context.ownsCosmetic(cosmeticId) then
			return { cash = 0, boostMinutes = 0, cosmeticId = cosmeticId }
		end
		if reward.fallback then
			return Rewards.resolve(reward.fallback, context)
		end
		return { cash = 0, boostMinutes = 0, cosmeticId = nil }
	elseif reward.kind == "boost" then
		return { cash = 0, boostMinutes = reward.minutes or 0, cosmeticId = nil }
	end

	local cash = 0
	if reward.incomeMinutes then
		cash += context.incomePerMinute * reward.incomeMinutes
	end
	if reward.packageValues and context.packageValue then
		cash += context.packageValue * reward.packageValues
	end
	cash = math.max(reward.minimumCash or 0, math.floor(cash))
	return { cash = cash, boostMinutes = 0, cosmeticId = nil }
end

function Rewards.rollMystery(random: () -> number): WeightedReward
	return Rng.pickWeighted(Config.Rewards.mystery, function(entry)
		return entry.weight
	end, random)
end

-- Odds of every mystery outcome in percent, for the info window.
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

-- Login calendar ---------------------------------------------------------------------------------

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

-- Playtime gifts ---------------------------------------------------------------------------------

-- Starts a fresh set of gifts on a new UTC day.
function Rewards.ensurePlaytimeDay(playtime: PlaytimeData, day: number): boolean
	if playtime.day == day then
		return false
	end
	playtime.day = day
	playtime.seconds = 0
	local claimed = {}
	for _ in Config.Rewards.playtime do
		table.insert(claimed, false)
	end
	playtime.claimed = claimed
	return true
end

function Rewards.canClaimGift(playtime: PlaytimeData, index: number): boolean
	local gift = Config.Rewards.playtime[index]
	if gift == nil or playtime.claimed[index] then
		return false
	end
	return playtime.seconds >= gift.minutes * 60
end

function Rewards.claimGift(playtime: PlaytimeData, index: number): Reward?
	if not Rewards.canClaimGift(playtime, index) then
		return nil
	end
	playtime.claimed[index] = true
	return Config.Rewards.playtime[index].reward
end

return Rewards
