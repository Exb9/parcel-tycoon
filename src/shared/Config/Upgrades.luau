--!strict
-- Repeatable upgrade tracks. Cost of the next level: baseCost * growth ^ currentLevel.
-- Effects grow linearly (effectPerLevel per level) while costs grow exponentially, so purchases
-- slow down over a run until a rebirth pays off. See docs/BALANCING.md.

export type UpgradeTrack = {
	id: string,
	displayName: string,
	baseCost: number,
	growth: number,
	maxLevel: number,
	effectPerLevel: number,
	-- Survives rebirths (comfort upgrades that do not raise income).
	keepOnRebirth: boolean?,
}

local tracks: { UpgradeTrack } = {
	-- +10 % packages per minute on every belt.
	{
		id = "beltSpeed",
		displayName = "Belt Speed",
		baseCost = 12,
		growth = 1.15,
		maxLevel = 25,
		effectPerLevel = 0.10,
	},
	-- +15 % cash per package ("bigger parcels").
	{
		id = "packageValue",
		displayName = "Bigger Parcels",
		baseCost = 18,
		growth = 1.16,
		maxLevel = 60,
		effectPerLevel = 0.15,
	},
	-- +20 % throughput for every sorting machine.
	{
		id = "sorterSpeed",
		displayName = "Machine Speed",
		baseCost = 250,
		growth = 1.18,
		maxLevel = 30,
		effectPerLevel = 0.20,
	},
	-- +3 percentage points machine accuracy (base in Config.Economy.sorterBaseAccuracy).
	{
		id = "sorterAccuracy",
		displayName = "Machine Accuracy",
		baseCost = 400,
		growth = 2.2,
		maxLevel = 5,
		effectPerLevel = 0.03,
	},
	-- +10 minutes of machine income the cash register can hold.
	{
		id = "collectorCapacity",
		displayName = "Bigger Cash Register",
		baseCost = 1000,
		growth = 3,
		maxLevel = 5,
		effectPerLevel = 10,
		keepOnRebirth = true,
	},
	-- +2 hours offline earnings cap (base cap lives in Config.Economy.offline).
	{
		id = "offlineCap",
		displayName = "Night Shift",
		baseCost = 5000,
		growth = 6,
		maxLevel = 3,
		effectPerLevel = 2,
		keepOnRebirth = true,
	},
}

return {
	tracks = tracks,
}
