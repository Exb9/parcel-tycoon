--!strict
-- Package types per zone and rare variants.
-- Pure data (hex colors, plain size tables) so it can be loaded outside Roblox (Lune tests, map builder).
-- Colors tell kids where a package goes, so every type in a zone needs a clearly different color
-- that also differs from the rare colors below.

export type Size = { x: number, y: number, z: number }

export type PackageType = {
	id: string,
	displayName: string,
	zone: string,
	-- Position 1-3 within its zone. Sorters, exits and sorter slots refer to this index,
	-- so the same plot layout and purchases work in every zone.
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
	-- Carrying it slows the player down (Config.Gameplay.heavyWalkSpeedMultiplier).
	heavy: boolean?,
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
	-- Accepted by every exit (the mystery box has no destination).
	anyExit: boolean,
	-- Replaces the type color; nil keeps it so the destination color stays readable.
	color: string?,
	-- Breaks when the carrier jumps or falls (Config.Gameplay.fragile*).
	fragile: boolean,
}

local types: { PackageType } = {
	-- Post office (zone 1)
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

	-- Airport cargo (zone 2)
	{
		id = "suitcase",
		displayName = "Suitcase",
		zone = "airportCargo",
		index = 1,
		baseValue = 4,
		spawnWeight = 50,
		destination = "Gate A",
		color = "#FB8C00",
		size = { x = 1.6, y = 2, z = 2.4 },
	},
	{
		id = "mailSack",
		displayName = "Mail Sack",
		zone = "airportCargo",
		index = 2,
		baseValue = 9,
		spawnWeight = 35,
		destination = "Gate B",
		color = "#00ACC1",
		size = { x = 2, y = 1.8, z = 2 },
	},
	{
		id = "pallet",
		displayName = "Pallet",
		zone = "airportCargo",
		index = 3,
		baseValue = 18,
		spawnWeight = 15,
		destination = "Gate C",
		color = "#8D6E63",
		size = { x = 3, y = 2.2, z = 3 },
		heavy = true,
	},
}

-- Rare packages: ~10 % of an active player's income (docs/BALANCING.md).
local rareVariants: { RareVariant } = {
	{
		id = "golden",
		displayName = "Golden",
		chance = 1 / 200,
		valueMultiplier = 10,
		machinesCanSort = false,
		anyExit = false,
		fragile = false,
	},
	{
		id = "fragile",
		displayName = "Fragile",
		chance = 1 / 120,
		valueMultiplier = 4,
		machinesCanSort = false,
		anyExit = false,
		fragile = true,
	},
	{
		id = "mystery",
		displayName = "Mystery",
		chance = 1 / 400,
		-- Pays a random reward from Config.Rewards.mystery instead of its value.
		valueMultiplier = 0,
		machinesCanSort = false,
		anyExit = true,
		color = "#8E24AA",
		fragile = false,
	},
}

return {
	types = types,
	rareVariants = rareVariants,
	goldenColor = "#FFC400",
}
