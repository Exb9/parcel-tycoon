--!strict
-- Package types per zone and rare variants.
-- Pure data (hex colors, plain size tables) so it can be loaded outside Roblox (Lune tests).
-- Colors tell kids where a package goes, so every type in a zone needs a clearly different color.
-- Only the post office exists until phase 6 (second zone).

export type Size = { x: number, y: number, z: number }

export type PackageType = {
	id: string,
	displayName: string,
	zone: string,
	-- Position 1-3 within its zone. Sorters and exits refer to this index.
	index: number,
	-- Cash for a correct sort, before upgrade and rebirth multipliers.
	baseValue: number,
	-- Relative spawn weight among the package types of the same zone.
	spawnWeight: number,
	-- Label printed on the package and on its matching exit.
	destination: string,
	color: string,
	-- Studs; z is the length along the belt.
	size: Size,
}

export type RareVariant = {
	id: string,
	displayName: string,
	-- Chance per spawned package. Fixed on purpose: nothing sold for Robux or cash may change it,
	-- otherwise it becomes a paid random item (odds disclosure + PolicyService gating).
	chance: number,
	-- Multiplier on the package value for a correct sort.
	valueMultiplier: number,
	-- Machines leave rare packages on the belt so active play stays worth more than idling.
	machinesCanSort: boolean,
	-- "Sort carefully": breaks when the carrier jumps or falls (Config.Gameplay.carry.fragile*).
	fragile: boolean,
	-- Adds a random bonus reward from Config.Rewards.mystery.
	bonusReward: boolean,
}

local types: { PackageType } = {
	{
		id = "letter",
		displayName = "Letter",
		zone = "postOffice",
		index = 1,
		baseValue = 3,
		spawnWeight = 50,
		destination = "Town",
		color = "#E53935",
		size = { x = 1.4, y = 0.5, z = 1.8 },
	},
	{
		id = "box",
		displayName = "Box",
		zone = "postOffice",
		index = 2,
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
		index = 3,
		baseValue = 12,
		spawnWeight = 15,
		destination = "World",
		color = "#43A047",
		size = { x = 2.8, y = 2.2, z = 2.8 },
	},
}

-- Rare packages keep their type color (the destination); the package template built in Studio shows
-- the golden/fragile/mystery look (docs/MAP_CONTRACT.md). Found through gameplay only.
local rareVariants: { RareVariant } = {
	{
		id = "golden",
		displayName = "Golden",
		chance = 1 / 200,
		valueMultiplier = 10,
		machinesCanSort = false,
		fragile = false,
		bonusReward = false,
	},
	{
		id = "fragile",
		displayName = "Fragile",
		chance = 1 / 120,
		valueMultiplier = 4,
		machinesCanSort = false,
		fragile = true,
		bonusReward = false,
	},
	{
		id = "mystery",
		displayName = "Mystery",
		chance = 1 / 400,
		valueMultiplier = 1,
		machinesCanSort = false,
		fragile = false,
		bonusReward = true,
	},
}

return {
	types = types,
	rareVariants = rareVariants,
}
