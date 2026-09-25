--!strict
-- Cosmetics from the brief: skins for belts, packages, the warehouse, and trails. Purely visual.
-- Most are sold as gamepasses (Config.Monetization.gamepasses with cosmeticId); the others come from
-- the starter pack, the club subscription and rebirth milestones.
-- Package skins change only the material: the color stays, because it tells kids where a package goes.
-- Trails are built in Studio via the Studio MCP (ServerStorage.CosmeticTemplates.<id>, docs/MAP_CONTRACT.md);
-- belt and warehouse skins recolor the parts marked with the SkinSlot attribute.

export type Slot = "trail" | "belt" | "package" | "warehouse"

export type Cosmetic = {
	id: string,
	displayName: string,
	slot: Slot,
	-- Belt and warehouse skins: new color of the skinned parts (nil = keep the color).
	color: string?,
	-- Enum.Material name for belt, package and warehouse skins (nil = keep the material).
	material: string?,
}

local items: { Cosmetic } = {
	-- Gamepasses
	{ id = "trailRainbow", displayName = "Rainbow Trail", slot = "trail" },
	{ id = "beltNeon", displayName = "Neon Belts", slot = "belt", color = "#00E5FF", material = "Neon" },
	{ id = "packageShiny", displayName = "Shiny Parcels", slot = "package", material = "Foil" },
	{
		id = "warehouseParty",
		displayName = "Party Warehouse",
		slot = "warehouse",
		color = "#7E57C2",
		material = "SmoothPlastic",
	},
	-- Starter pack
	{ id = "beltGold", displayName = "Golden Belts", slot = "belt", color = "#FFC107", material = "Foil" },
	-- Club subscription (usable while subscribed)
	{ id = "trailClub", displayName = "Club Trail", slot = "trail" },
	-- Rebirth milestones
	{
		id = "warehouseCandy",
		displayName = "Candy Warehouse",
		slot = "warehouse",
		color = "#F48FB1",
		material = "SmoothPlastic",
	},
	{ id = "packageGlass", displayName = "Glass Parcels", slot = "package", material = "Glass" },
	{ id = "trailStar", displayName = "Star Trail", slot = "trail" },
}

return {
	items = items,
	slots = { "trail", "belt", "package", "warehouse" } :: { Slot },
}
