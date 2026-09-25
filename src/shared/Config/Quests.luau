--!strict
-- Daily quests. Three quests are drawn per player and UTC day; together they take roughly 10-15 minutes,
-- which lines up with the Creator Rewards 10-minute session threshold.

export type QuestKind =
	"sortManual" -- sort packages by hand
	| "sortType" -- sort packages of one type index by hand
	| "sortMachine" -- packages sorted by your machines
	| "sortRare" -- rare packages sorted by hand
	| "earn" -- cash earned from sorting
	| "buyUpgrades" -- upgrade levels bought
	| "collect" -- cash register collections

export type QuestDef = {
	id: string,
	kind: QuestKind,
	-- Fixed target ...
	target: number?,
	-- ... or, for "earn", minutes of the player's income estimate when the quest is drawn.
	targetIncomeMinutes: number?,
	typeIndex: number?,
	-- Reward: minutes of current income with a floor.
	rewardIncomeMinutes: number,
	rewardMinimumCash: number,
}

local dailyPool: { QuestDef } = {
	{ id = "sortHand25", kind = "sortManual", target = 25, rewardIncomeMinutes = 5, rewardMinimumCash = 150 },
	{ id = "sortHand50", kind = "sortManual", target = 50, rewardIncomeMinutes = 10, rewardMinimumCash = 300 },
	{
		id = "sortType1",
		kind = "sortType",
		typeIndex = 1,
		target = 15,
		rewardIncomeMinutes = 4,
		rewardMinimumCash = 120,
	},
	{
		id = "sortType2",
		kind = "sortType",
		typeIndex = 2,
		target = 12,
		rewardIncomeMinutes = 5,
		rewardMinimumCash = 150,
	},
	{
		id = "sortType3",
		kind = "sortType",
		typeIndex = 3,
		target = 8,
		rewardIncomeMinutes = 6,
		rewardMinimumCash = 180,
	},
	{ id = "machines100", kind = "sortMachine", target = 100, rewardIncomeMinutes = 5, rewardMinimumCash = 150 },
	{ id = "rare1", kind = "sortRare", target = 1, rewardIncomeMinutes = 8, rewardMinimumCash = 250 },
	{ id = "earn10", kind = "earn", targetIncomeMinutes = 10, rewardIncomeMinutes = 5, rewardMinimumCash = 150 },
	{ id = "upgrades5", kind = "buyUpgrades", target = 5, rewardIncomeMinutes = 4, rewardMinimumCash = 120 },
	{ id = "collect3", kind = "collect", target = 3, rewardIncomeMinutes = 4, rewardMinimumCash = 120 },
}

return {
	dailyPool = dailyPool,
	dailyCount = 3,
	-- Floor for "earn" targets so brand-new players get a sensible goal.
	minimumEarnTarget = 500,
}
