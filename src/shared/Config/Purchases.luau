--!strict
-- One-off purchases (tycoon "buttons"). Each unlocks after its `requires` purchase, so they appear one
-- after another. Prices are chosen so each costs roughly 3-8 minutes of income at the time it becomes
-- the best next step for a free player. See docs/BALANCING.md.

export type PurchaseKind = "sorter" | "spawner" | "belt"

export type Purchase = {
	id: string,
	displayName: string,
	kind: PurchaseKind,
	cost: number,
	-- Belt the item belongs to (sorters and belts). Spawners apply to every belt.
	belt: number?,
	-- Package type a sorter handles.
	packageType: string?,
	requires: string?,
}

local purchases: { Purchase } = {
	-- Belt 1
	{
		id = "sorter1_letter",
		displayName = "Letter Sorter",
		kind = "sorter",
		cost = 200,
		belt = 1,
		packageType = "letter",
	},
	{ id = "spawner2", displayName = "Second Chute", kind = "spawner", cost = 450 },
	{
		id = "sorter1_box",
		displayName = "Box Sorter",
		kind = "sorter",
		cost = 1200,
		belt = 1,
		packageType = "box",
		requires = "sorter1_letter",
	},
	{
		id = "sorter1_crate",
		displayName = "Crate Sorter",
		kind = "sorter",
		cost = 4000,
		belt = 1,
		packageType = "crate",
		requires = "sorter1_box",
	},
	{ id = "spawner3", displayName = "Third Chute", kind = "spawner", cost = 9000, requires = "spawner2" },

	-- Belt 2
	{ id = "belt2", displayName = "Second Belt", kind = "belt", cost = 25000, belt = 2, requires = "sorter1_crate" },
	{
		id = "sorter2_letter",
		displayName = "Letter Sorter II",
		kind = "sorter",
		cost = 8000,
		belt = 2,
		packageType = "letter",
		requires = "belt2",
	},
	{
		id = "sorter2_box",
		displayName = "Box Sorter II",
		kind = "sorter",
		cost = 12000,
		belt = 2,
		packageType = "box",
		requires = "sorter2_letter",
	},
	{
		id = "sorter2_crate",
		displayName = "Crate Sorter II",
		kind = "sorter",
		cost = 20000,
		belt = 2,
		packageType = "crate",
		requires = "sorter2_box",
	},

	-- Belt 3
	{ id = "belt3", displayName = "Third Belt", kind = "belt", cost = 150000, belt = 3, requires = "sorter2_crate" },
	{
		id = "sorter3_letter",
		displayName = "Letter Sorter III",
		kind = "sorter",
		cost = 40000,
		belt = 3,
		packageType = "letter",
		requires = "belt3",
	},
	{
		id = "sorter3_box",
		displayName = "Box Sorter III",
		kind = "sorter",
		cost = 70000,
		belt = 3,
		packageType = "box",
		requires = "sorter3_letter",
	},
	{
		id = "sorter3_crate",
		displayName = "Crate Sorter III",
		kind = "sorter",
		cost = 110000,
		belt = 3,
		packageType = "crate",
		requires = "sorter3_box",
	},
}

return {
	purchases = purchases,
}
