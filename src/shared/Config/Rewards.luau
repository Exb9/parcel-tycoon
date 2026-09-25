--!strict
-- Free rewards: the mystery package bonus, daily rewards, playtime gifts, invites, the group bonus, the
-- friends bonus, rebirth milestones and the end of the tutorial.
-- Cash rewards scale with progress ("minutes of your current income") and have a floor for players who
-- have no income yet. Nothing here can be bought.
-- Daily rewards, playtime gifts and daily quests are paced for daily sessions of 10+ minutes (Creator Rewards).

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

export type PlaytimeGift = {
	-- Minutes played today (UTC day) before the gift can be opened. Gifts open in order.
	minutes: number,
	reward: Reward,
}

export type Milestone = {
	rebirths: number,
	reward: Reward,
	-- Style unlocked for good (Config.Cosmetics).
	cosmeticId: string?,
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

-- Playtime gifts: open one after the other while playing; the timer restarts every UTC day.
local playtime: { PlaytimeGift } = {
	{ minutes = 3, reward = { kind = "cash", incomeMinutes = 3, minimumCash = 100 } },
	{ minutes = 8, reward = { kind = "boost", minutes = 5 } },
	{ minutes = 15, reward = { kind = "cash", incomeMinutes = 6, minimumCash = 250 } },
	{ minutes = 25, reward = { kind = "cash", incomeMinutes = 10, minimumCash = 400 } },
	{ minutes = 40, reward = { kind = "boost", minutes = 10 } },
}

-- Rewards for reaching rebirth milestones (each once per player).
local rebirthMilestones: { Milestone } = {
	{ rebirths = 1, reward = { kind = "cash", incomeMinutes = 10, minimumCash = 2000 }, cosmeticId = "warehouseCandy" },
	{ rebirths = 3, reward = { kind = "cash", incomeMinutes = 20, minimumCash = 10000 }, cosmeticId = "packageGlass" },
	{ rebirths = 5, reward = { kind = "boost", minutes = 30 }, cosmeticId = "trailStar" },
	{ rebirths = 10, reward = { kind = "cash", incomeMinutes = 60, minimumCash = 100000 } },
}

return {
	mystery = mystery,
	daily = daily,
	playtime = playtime,
	rebirthMilestones = rebirthMilestones,

	-- Invites via share link (decision: reward invites for Creator Rewards audience expansion).
	-- The inviter is rewarded when an invited player joins for the first time; the invited player gets
	-- a welcome gift.
	referral = {
		inviter = { kind = "cash", incomeMinutes = 30, minimumCash = 1000 } :: Reward,
		invitee = { kind = "cash", incomeMinutes = 0, minimumCash = 500 } :: Reward,
		maxInviterRewardsPerDay = 5,
	},

	-- Roblox group: members earn a bit more and get a one-time gift.
	group = {
		-- Group id from roblox.com/communities/<id>; 0 = feature off.
		groupId = 0,
		cashBonus = 0.1,
		joinReward = { kind = "cash", incomeMinutes = 10, minimumCash = 500 } :: Reward,
	},

	-- Playing together: extra cash per friend on the same server.
	friends = {
		bonusPerFriend = 0.1,
		maxBonus = 0.3,
	},

	-- Gift at the end of the first-time tutorial (Config.Onboarding).
	onboarding = { kind = "cash", incomeMinutes = 0, minimumCash = 250 } :: Reward,
}
