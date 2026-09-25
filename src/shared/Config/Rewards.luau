--!strict
-- Free rewards: mystery packages, the daily login calendar, playtime gifts, the VIP gift, invites
-- and rebirth milestones. Cash rewards scale with progress ("minutes of your current income") and
-- have a floor for players who have no income yet. Nothing here can be bought.
-- Daily rewards and playtime gifts are paced so a daily session lasts 10+ minutes (Creator Rewards).

export type Reward = {
	kind: "cash" | "boost" | "cosmetic",
	-- cash: minutes of the player's current income estimate (Economy.incomePerMinute) ...
	incomeMinutes: number?,
	-- ... or a multiple of the sorted package's value (mystery packages).
	packageValues: number?,
	-- cash: lower bound.
	minimumCash: number?,
	-- boost: minutes of the cash boost (Config.Economy.boostMultiplier).
	minutes: number?,
	-- cosmetic: item from Config.Cosmetics; players who own it get `fallback` instead.
	cosmeticId: string?,
	fallback: Reward?,
}

export type WeightedReward = {
	id: string,
	weight: number,
	reward: Reward,
}

export type PlaytimeGift = {
	-- Minutes played today (UTC day) needed to claim.
	minutes: number,
	reward: Reward,
}

-- Mystery package rewards. Found through gameplay only, so no odds disclosure is required;
-- the odds are still shown in the info window (Config values are the single source).
local mystery: { WeightedReward } = {
	{ id = "smallCash", weight = 55, reward = { kind = "cash", packageValues = 5, minimumCash = 20 } },
	{ id = "bigCash", weight = 25, reward = { kind = "cash", packageValues = 15, minimumCash = 50 } },
	{ id = "boost", weight = 15, reward = { kind = "boost", minutes = 3 } },
	{ id = "jackpot", weight = 4, reward = { kind = "cash", packageValues = 50, minimumCash = 150 } },
	{
		id = "sparkleTrail",
		weight = 1,
		reward = {
			kind = "cosmetic",
			cosmeticId = "trailSparkle",
			fallback = { kind = "cash", packageValues = 25, minimumCash = 100 },
		},
	},
}

-- Login calendar: one step per UTC day you claim, loops after 7, never resets (no streak pressure).
local daily: { Reward } = {
	{ kind = "cash", incomeMinutes = 5, minimumCash = 100 },
	{ kind = "cash", incomeMinutes = 10, minimumCash = 200 },
	{ kind = "boost", minutes = 10 },
	{ kind = "cash", incomeMinutes = 20, minimumCash = 400 },
	{ kind = "cash", incomeMinutes = 30, minimumCash = 600 },
	{ kind = "boost", minutes = 20 },
	{
		kind = "cosmetic",
		cosmeticId = "trailConfetti",
		fallback = { kind = "cash", incomeMinutes = 60, minimumCash = 1000 },
	},
}

-- Playtime gifts: claimable after playing this many minutes today (UTC); they reset every day.
local playtime: { PlaytimeGift } = {
	{ minutes = 3, reward = { kind = "cash", incomeMinutes = 3, minimumCash = 50 } },
	{ minutes = 6, reward = { kind = "cash", incomeMinutes = 5, minimumCash = 100 } },
	{ minutes = 10, reward = { kind = "boost", minutes = 5 } },
	{ minutes = 15, reward = { kind = "cash", incomeMinutes = 10, minimumCash = 250 } },
}

return {
	mystery = mystery,
	daily = daily,
	playtime = playtime,

	-- VIP pass: free boost once per UTC day from the gift pad in the VIP lounge.
	vipGift = { kind = "boost", minutes = 10 } :: Reward,

	-- Invites (Creator Rewards: audience expansion). The inviter is rewarded when an invited player
	-- joins for the first time; the invited player gets a welcome gift.
	referral = {
		inviter = { kind = "cash", incomeMinutes = 30, minimumCash = 1000 } :: Reward,
		invitee = { kind = "cash", incomeMinutes = 0, minimumCash = 500 } :: Reward,
		maxInviterRewardsPerDay = 5,
	},

	-- Given once when a player reaches this many rebirths.
	rebirthMilestones = {
		{ rebirths = 1, reward = { kind = "cosmetic", cosmeticId = "beltGold" } :: Reward },
	},
}
