--!strict
-- Repeatable upgrade tracks. Cost of the next level: baseCost * growth ^ currentLevel.
-- Effects grow linearly (1 + effectPerLevel * level) while costs grow exponentially, so purchases
-- slow down over a run until a rebirth pays off. See docs/BALANCING.md.

export type UpgradeTrack = {
	id: string,
	displayName: string,
	baseCost: number,
	growth: number,
	maxLevel: number,
	effectPerLevel: number,
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
	-- +2 hours offline earnings cap (base cap lives in Economy.offline).
	{ id = "offlineCap", displayName = "Night Shift", baseCost = 5000, growth = 6, maxLevel = 3, effectPerLevel = 2 },
}

return {
	tracks = tracks,
}
