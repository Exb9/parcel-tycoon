--!strict
-- Gamepasses and developer products from the brief.
-- id = 0 means "not created yet": Studio simulates the purchase, live servers show the offer as unavailable.
-- Prices are never stored here: the UI reads them via MarketplaceService:GetProductInfo so Roblox
-- regional pricing and price optimization keep working.
-- Rule: nothing sold here may change rare package chances (see Config.PackageTypes).

export type Gamepass = {
	id: number,
	displayName: string,
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
	-- 2x Cash
	doubleCash = { id = 0, displayName = "2x Cash" },
	-- Auto-Collect: machine cash goes straight to the balance, no cash register limit.
	autoCollect = { id = 0, displayName = "Auto Collect" },
	-- VIP area: opens the VIP door in the lobby.
	vip = { id = 0, displayName = "VIP" },
	-- Faster belts: more packages per minute on every belt.
	fastBelts = { id = 0, displayName = "Fast Belts" },
	-- Extra plot space: unlocks a fourth belt that is built with cash (decision 25.09.2026).
	biggerWarehouse = { id = 0, displayName = "Bigger Warehouse" },
}

local products: { [string]: Product } = {
	-- Cash packs that scale with progress.
	cashSmall = { id = 0, displayName = "Cash Stack", kind = "cash", incomeMinutes = 15, minimumCash = 250 },
	cashMedium = { id = 0, displayName = "Cash Bag", kind = "cash", incomeMinutes = 60, minimumCash = 1000 },
	cashLarge = { id = 0, displayName = "Cash Truck", kind = "cash", incomeMinutes = 240, minimumCash = 4000 },
	-- Time-limited boost.
	cashBoost = { id = 0, displayName = "2x Cash Boost", kind = "boost", minutes = 15 },
	-- Instant upgrade: builds the next available sorting machine.
	instantMachine = { id = 0, displayName = "Instant Machine", kind = "instantMachine" },
	-- Cosmetics.
	trailRainbow = { id = 0, displayName = "Rainbow Trail", kind = "cosmetic", cosmeticId = "trailRainbow" },
	beltNeon = { id = 0, displayName = "Neon Belts", kind = "cosmetic", cosmeticId = "beltNeon" },
	packageShiny = { id = 0, displayName = "Shiny Parcels", kind = "cosmetic", cosmeticId = "packageShiny" },
	warehouseParty = { id = 0, displayName = "Party Warehouse", kind = "cosmetic", cosmeticId = "warehouseParty" },
}

return {
	gamepasses = gamepasses,
	products = products,
	-- Display order in the store.
	gamepassOrder = { "doubleCash", "autoCollect", "fastBelts", "biggerWarehouse", "vip" },
	productOrder = { "cashSmall", "cashMedium", "cashLarge", "cashBoost", "instantMachine" },
	cosmeticProductOrder = { "trailRainbow", "beltNeon", "packageShiny", "warehouseParty" },

	-- Pass effects.
	doubleCashMultiplier = 2,
	fastBeltsMultiplier = 1.25,

	-- Instant Machine receipt with nothing left to build (e.g. bought twice quickly): cash instead.
	instantMachineFallback = { incomeMinutes = 30, minimumCash = 1000 },

	-- Grant id = 0 offers directly in Studio so everything can be tested before creating products.
	simulateInStudio = true,
	-- Receipts remembered per profile for idempotent ProcessReceipt handling.
	purchaseIdCacheSize = 100,
}
