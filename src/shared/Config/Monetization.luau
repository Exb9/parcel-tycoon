--!strict
-- Gamepasses and developer products (implemented in phase 4).
-- id = 0 means "not created yet": Studio simulates the purchase, live servers show the offer as unavailable.
-- Prices are never stored here: the UI reads them via MarketplaceService:GetProductInfo so Roblox
-- regional pricing and price optimization keep working.
-- Rule: nothing sold here may change rare package chances (see Config.PackageTypes).

export type Gamepass = {
	id: number,
	displayName: string,
}

export type CashProduct = {
	id: number,
	displayName: string,
	-- Grants this many minutes of the buyer's current income, so packs scale with progress.
	incomeMinutes: number,
	-- Floor for players who have no income yet.
	minimumCash: number,
}

export type BoostProduct = {
	id: number,
	displayName: string,
	cashMultiplier: number,
	durationMinutes: number,
}

local gamepasses: { [string]: Gamepass } = {
	doubleCash = { id = 0, displayName = "2x Cash" },
	autoCollect = { id = 0, displayName = "Auto Collect" },
	vip = { id = 0, displayName = "VIP" },
	fastBelts = { id = 0, displayName = "Fast Belts" },
	biggerWarehouse = { id = 0, displayName = "Bigger Warehouse" },
}

local cashProducts: { [string]: CashProduct } = {
	cashSmall = { id = 0, displayName = "Cash Stack", incomeMinutes = 15, minimumCash = 250 },
	cashMedium = { id = 0, displayName = "Cash Bag", incomeMinutes = 60, minimumCash = 1000 },
	cashLarge = { id = 0, displayName = "Cash Truck", incomeMinutes = 240, minimumCash = 4000 },
}

local boostProducts: { [string]: BoostProduct } = {
	cashBoost = { id = 0, displayName = "2x Cash Boost", cashMultiplier = 2, durationMinutes = 15 },
}

return {
	gamepasses = gamepasses,
	cashProducts = cashProducts,
	boostProducts = boostProducts,
	-- Pass effects.
	doubleCashMultiplier = 2,
	fastBeltsMultiplier = 1.25,
}
