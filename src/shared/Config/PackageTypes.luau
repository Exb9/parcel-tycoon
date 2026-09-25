--!strict
-- Package types per zone and rare variants.
-- Pure data (hex colors, plain size tables) so it can be loaded outside Roblox, e.g. by the Lune balance tests.

export type Size = { x: number, y: number, z: number }

export type PackageType = {
	id: string,
	displayName: string,
	zone: string,
	-- Cash for a correct sort, before upgrade and rebirth multipliers.
	baseValue: number,
	-- Relative spawn weight among the package types of the same zone.
	spawnWeight: number,
	-- Label printed on the package and on its matching exit.
	destination: string,
	color: string,
	size: Size,
}

export type RareVariant = {
	id: string,
	displayName: string,
	-- Chance per spawned package. Fixed on purpose: nothing sold for Robux or cash may change it,
	-- otherwise it becomes a paid random item (odds disclosure + PolicyService gating).
	chance: number,
	valueMultiplier: number,
	-- Machines leave rare packages on the belt so active play stays worth more than idling.
	machinesCanSort: boolean,
}

local types: { PackageType } = {
	{
		id = "letter",
		displayName = "Letter",
		zone = "postOffice",
		baseValue = 3,
		spawnWeight = 50,
		destination = "Town",
		color = "#E53935",
		size = { x = 1.6, y = 0.4, z = 1.2 },
	},
	{
		id = "box",
		displayName = "Box",
		zone = "postOffice",
		baseValue = 6,
		spawnWeight = 35,
		destination = "Country",
		color = "#1E88E5",
		size = { x = 2, y = 1.6, z = 2 },
	},
	{
		id = "crate",
		displayName = "Crate",
		zone = "postOffice",
		baseValue = 12,
		spawnWeight = 15,
		destination = "World",
		color = "#FDD835",
		size = { x = 3, y = 2.4, z = 3 },
	},
}

-- Implemented in phase 5; values are already part of the balancing plan (~10 % of active income).
local rareVariants: { RareVariant } = {
	{ id = "golden", displayName = "Golden", chance = 1 / 150, valueMultiplier = 10, machinesCanSort = false },
	{ id = "fragile", displayName = "Fragile", chance = 1 / 80, valueMultiplier = 4, machinesCanSort = false },
	{ id = "mystery", displayName = "Mystery", chance = 1 / 300, valueMultiplier = 1, machinesCanSort = false },
}

return {
	types = types,
	rareVariants = rareVariants,
}
