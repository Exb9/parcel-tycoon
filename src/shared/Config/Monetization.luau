--!strict
-- Gamepasses and developer products.
-- id = 0 means "not created yet": Studio simulates the purchase, live servers show the offer as unavailable.
-- Prices are never stored here: the UI reads them via MarketplaceService:GetProductInfo so Roblox
-- regional pricing and price optimization keep working.
-- Rule: nothing sold here may change rare package chances (see Config.PackageTypes).

export type Gamepass = {
	id: number,
	displayName: string,
	description: string,
}

export type ProductKind = "cash" | "boost" | "instantMachine" | "cosmetic"

export type Product = {
	id: number,
	displayName: string,
	kind: ProductKind,
	-- cash: grants this many minutes of the buyer's current income, so packs scale with progress ...
	incomeMinutes: number?,
	-- ... with this floor for players who have no income yet.
	minimumCash: number?,
	-- boost: minutes of the cash boost (Config.Economy.boostMultiplier).
	minutes: number?,
	-- cosmetic: permanent unlock (Config.Cosmetics).
	cosmeticId: string?,
}

local gamepasses: { [string]: Gamepass } = {
	doubleCash = { id = 0, displayName = "2x Cash", description = "Doubles all cash you earn." },
	autoCollect = {
		id = 0,
		displayName = "Auto Collect",
		description = "Machine cash goes straight to your balance, no cash register limit.",
	},
	vip = {
		id = 0,
		displayName = "VIP",
		description = "VIP lounge, a free daily boost, a VIP chat tag and +10% cash.",
	},
	fastBelts = { id = 0, displayName = "Fast Belts", description = "25% more parcels on every belt." },
	biggerWarehouse = {
		id = 0,
		displayName = "Bigger Warehouse",
		description = "Unlocks a fourth belt you can build with cash.",
	},
}

local products: { [string]: Product } = {
	cashSmall = { id = 0, displayName = "Cash Stack", kind = "cash", incomeMinutes = 15, minimumCash = 250 },
	cashMedium = { id = 0, displayName = "Cash Bag", kind = "cash", incomeMinutes = 60, minimumCash = 1000 },
	cashLarge = { id = 0, displayName = "Cash Truck", kind = "cash", incomeMinutes = 240, minimumCash = 4000 },
	cashBoost = { id = 0, displayName = "2x Cash Boost", kind = "boost", minutes = 15 },
	-- "Sofort-Upgrade": builds the next available sorting machine for free.
	instantMachine = { id = 0, displayName = "Instant Machine", kind = "instantMachine" },
	trailRainbow = { id = 0, displayName = "Rainbow Trail", kind = "cosmetic", cosmeticId = "trailRainbow" },
	beltNeon = { id = 0, displayName = "Neon Belts", kind = "cosmetic", cosmeticId = "beltNeon" },
	floorParty = { id = 0, displayName = "Party Floor", kind = "cosmetic", cosmeticId = "floorParty" },
}

return {
	gamepasses = gamepasses,
	products = products,
	-- Display order in the store.
	gamepassOrder = { "doubleCash", "autoCollect", "fastBelts", "biggerWarehouse", "vip" },
	productOrder = { "cashSmall", "cashMedium", "cashLarge", "cashBoost", "instantMachine" },
	cosmeticProductOrder = { "trailRainbow", "beltNeon", "floorParty" },

	-- Pass effects.
	doubleCashMultiplier = 2,
	vipCashBonus = 0.1,
	fastBeltsMultiplier = 1.25,

	-- Grant id = 0 offers directly in Studio so everything can be tested before creating products.
	simulateInStudio = true,
	-- Receipts remembered per profile for idempotent ProcessReceipt handling.
	purchaseIdCacheSize = 100,
}
