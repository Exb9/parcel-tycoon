--!strict
-- Tutorial chain and daily quests. Three daily quests are drawn per player and UTC day; together they
-- take roughly 10-15 minutes, which lines up with the Creator Rewards 10-minute session threshold.

export type QuestKind =
	"grab" -- pick up packages by hand
	| "sortManual" -- sort packages by hand
	| "sortType" -- sort packages of one type index by hand
	| "sortMachine" -- packages sorted by your machines
	| "sortRare" -- rare packages sorted by hand
	| "earn" -- cash earned from sorting
	| "buyUpgrades" -- upgrade levels bought
	| "buyPurchase" -- a specific one-off purchase
	| "collect" -- cash register collections

export type QuestDef = {
	id: string,
	kind: QuestKind,
	-- Fixed target ...
	target: number?,
	-- ... or, for "earn", minutes of the player's income estimate when the quest is drawn.
	targetIncomeMinutes: number?,
	typeIndex: number?,
	purchaseId: string?,
	-- Reward: minutes of current income with a floor, or a fixed amount (tutorial).
	rewardIncomeMinutes: number?,
	rewardMinimumCash: number?,
	rewardCash: number?,
}

local tutorial: { QuestDef } = {
	{ id = "tutorialGrab", kind = "grab", target = 1, rewardCash = 10 },
	{ id = "tutorialSort", kind = "sortManual", target = 3, rewardCash = 25 },
	{ id = "tutorialUpgrade", kind = "buyUpgrades", target = 1, rewardCash = 30 },
	{ id = "tutorialMachine", kind = "buyPurchase", purchaseId = "b1_sorter1", target = 1, rewardCash = 60 },
	{ id = "tutorialCollect", kind = "collect", target = 1, rewardCash = 100 },
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
	tutorial = tutorial,
	dailyPool = dailyPool,
	dailyCount = 3,
	-- Floor for "earn" targets so brand-new players get a sensible goal.
	minimumEarnTarget = 500,
}
