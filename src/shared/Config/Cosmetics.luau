--!strict
-- Cosmetics: purely visual, no gameplay effect. Sources:
--   "free"   - owned by everyone
--   "reward" - earned through gameplay (Config.Rewards)
--   "robux"  - fixed-content developer product (Config.Monetization.cosmeticProducts), never random
-- Package colors stay untouched on purpose: they tell kids where a package goes.

export type Slot = "trail" | "belt" | "floor"

export type Cosmetic = {
	id: string,
	displayName: string,
	slot: Slot,
	color: string,
	-- Trails fade from color to color2.
	color2: string?,
	-- Enum.Material name for belts and floors.
	material: string?,
	source: "free" | "reward" | "robux",
}

local items: { Cosmetic } = {
	{
		id = "trailSparkle",
		displayName = "Sparkle Trail",
		slot = "trail",
		color = "#FFFFFF",
		color2 = "#FFD54F",
		source = "reward",
	},
	{
		id = "trailConfetti",
		displayName = "Confetti Trail",
		slot = "trail",
		color = "#FF4081",
		color2 = "#40C4FF",
		source = "reward",
	},
	{
		id = "trailRainbow",
		displayName = "Rainbow Trail",
		slot = "trail",
		color = "#FF1744",
		color2 = "#2979FF",
		source = "robux",
	},
	{
		id = "beltGold",
		displayName = "Golden Belts",
		slot = "belt",
		color = "#FFC400",
		material = "Foil",
		source = "reward",
	},
	{
		id = "beltNeon",
		displayName = "Neon Belts",
		slot = "belt",
		color = "#00E5FF",
		material = "Neon",
		source = "robux",
	},
	{
		id = "floorWood",
		displayName = "Wooden Floor",
		slot = "floor",
		color = "#A1887F",
		material = "WoodPlanks",
		source = "free",
	},
	{
		id = "floorParty",
		displayName = "Party Floor",
		slot = "floor",
		color = "#7E57C2",
		material = "Glass",
		source = "robux",
	},
}

return {
	items = items,
}
