--!strict
-- Free rewards: the mystery package bonus, daily rewards and the invite reward.
-- Cash rewards scale with progress ("minutes of your current income") and have a floor for players who
-- have no income yet. Nothing here can be bought.
-- Daily rewards and daily quests are paced for daily sessions of 10+ minutes (Creator Rewards).

export type Reward = {
	kind: "cash" | "boost",
	-- cash: minutes of the player's current income estimate (Economy.estimatedIncome) ...
	incomeMinutes: number?,
	-- ... or a multiple of the sorted package's value (mystery bonus).
	packageValues: number?,
	-- cash: lower bound.
	minimumCash: number?,
	-- boost: minutes of the cash boost (Config.Economy.boostMultiplier).
	minutes: number?,
}

export type WeightedReward = {
	id: string,
	weight: number,
	reward: Reward,
}

-- Bonus reward of a mystery package ("mysteriös (Bonus-Belohnung)"), on top of its normal value.
-- Found through gameplay only, so no odds disclosure is required; the odds are still shown in the
-- info window (decision: chances visible), and these weights are the single source for it.
local mystery: { WeightedReward } = {
	{ id = "smallCash", weight = 60, reward = { kind = "cash", packageValues = 5, minimumCash = 20 } },
	{ id = "bigCash", weight = 25, reward = { kind = "cash", packageValues = 15, minimumCash = 50 } },
	{ id = "boost", weight = 11, reward = { kind = "boost", minutes = 3 } },
	{ id = "jackpot", weight = 4, reward = { kind = "cash", packageValues = 50, minimumCash = 150 } },
}

-- Daily rewards: one step per UTC day claimed, loops after 7.
local daily: { Reward } = {
	{ kind = "cash", incomeMinutes = 5, minimumCash = 100 },
	{ kind = "cash", incomeMinutes = 10, minimumCash = 200 },
	{ kind = "boost", minutes = 10 },
	{ kind = "cash", incomeMinutes = 20, minimumCash = 400 },
	{ kind = "cash", incomeMinutes = 30, minimumCash = 600 },
	{ kind = "boost", minutes = 20 },
	{ kind = "cash", incomeMinutes = 60, minimumCash = 1000 },
}

return {
	mystery = mystery,
	daily = daily,

	-- Invites via share link (decision: reward invites for Creator Rewards audience expansion).
	-- The inviter is rewarded when an invited player joins for the first time; the invited player gets
	-- a welcome gift.
	referral = {
		inviter = { kind = "cash", incomeMinutes = 30, minimumCash = 1000 } :: Reward,
		invitee = { kind = "cash", incomeMinutes = 0, minimumCash = 500 } :: Reward,
		maxInviterRewardsPerDay = 5,
	},
}
