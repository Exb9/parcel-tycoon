--!strict
-- One-off purchases (tycoon "buttons"). Each unlocks after its `requires` purchase, so they appear one
-- after another. Prices are chosen so each costs roughly 3-8 minutes of income at the time it becomes
-- the best next step for a free player. See docs/BALANCING.md.
-- Sorters point at a package type index (1-3) instead of a type, so the same purchases work in every zone.

export type PurchaseKind = "sorter" | "spawner" | "belt"

export type Purchase = {
	id: string,
	kind: PurchaseKind,
	cost: number,
	-- Belt the item belongs to (sorters and belts). Spawners apply to every belt.
	belt: number?,
	-- Package type index a sorter handles.
	typeIndex: number?,
	requires: string?,
	-- Gamepass key (Config.Monetization.gamepasses) needed before it can be bought with cash.
	requiresPass: string?,
}

local purchases: { Purchase } = {
	-- Belt 1
	{ id = "b1_sorter1", kind = "sorter", cost = 200, belt = 1, typeIndex = 1 },
	{ id = "spawner2", kind = "spawner", cost = 450 },
	{ id = "b1_sorter2", kind = "sorter", cost = 1200, belt = 1, typeIndex = 2, requires = "b1_sorter1" },
	{ id = "b1_sorter3", kind = "sorter", cost = 4000, belt = 1, typeIndex = 3, requires = "b1_sorter2" },
	{ id = "spawner3", kind = "spawner", cost = 9000, requires = "spawner2" },

	-- Belt 2
	{ id = "belt2", kind = "belt", cost = 25000, belt = 2, requires = "b1_sorter3" },
	{ id = "b2_sorter1", kind = "sorter", cost = 8000, belt = 2, typeIndex = 1, requires = "belt2" },
	{ id = "b2_sorter2", kind = "sorter", cost = 12000, belt = 2, typeIndex = 2, requires = "b2_sorter1" },
	{ id = "b2_sorter3", kind = "sorter", cost = 20000, belt = 2, typeIndex = 3, requires = "b2_sorter2" },

	-- Belt 3
	{ id = "belt3", kind = "belt", cost = 150000, belt = 3, requires = "b2_sorter3" },
	{ id = "b3_sorter1", kind = "sorter", cost = 40000, belt = 3, typeIndex = 1, requires = "belt3" },
	{ id = "b3_sorter2", kind = "sorter", cost = 70000, belt = 3, typeIndex = 2, requires = "b3_sorter1" },
	{ id = "b3_sorter3", kind = "sorter", cost = 110000, belt = 3, typeIndex = 3, requires = "b3_sorter2" },

	-- Belt 4: only with the "Bigger Warehouse" pass, still bought with in-game cash.
	{
		id = "belt4",
		kind = "belt",
		cost = 60000,
		belt = 4,
		requires = "b2_sorter3",
		requiresPass = "biggerWarehouse",
	},
	{
		id = "b4_sorter1",
		kind = "sorter",
		cost = 15000,
		belt = 4,
		typeIndex = 1,
		requires = "belt4",
		requiresPass = "biggerWarehouse",
	},
	{
		id = "b4_sorter2",
		kind = "sorter",
		cost = 25000,
		belt = 4,
		typeIndex = 2,
		requires = "b4_sorter1",
		requiresPass = "biggerWarehouse",
	},
	{
		id = "b4_sorter3",
		kind = "sorter",
		cost = 40000,
		belt = 4,
		typeIndex = 3,
		requires = "b4_sorter2",
		requiresPass = "biggerWarehouse",
	},
}

return {
	purchases = purchases,
	maxBelts = 4,
}
