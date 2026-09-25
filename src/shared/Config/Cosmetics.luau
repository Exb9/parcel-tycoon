--!strict
-- Cosmetics from the brief: skins for belts, packages, the warehouse, and trails. Purely visual,
-- sold as fixed-content developer products (Config.Monetization.products, kind "cosmetic").
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
}

return {
	items = items,
	slots = { "trail", "belt", "package", "warehouse" } :: { Slot },
}
