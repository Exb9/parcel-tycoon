--!strict
-- Gamepasses, developer products, rewarded video ads, the club subscription and contextual offers.
-- id = 0 (or "" for the subscription) means "not created yet": Studio simulates the purchase, live servers
-- show the offer as unavailable. Create them in the Creator Hub and enter the ids here (docs/PC_SESSION.md).
-- Prices are never stored here: the UI reads them via MarketplaceService so Roblox regional pricing and
-- price optimization keep working.
-- Fairness rules (docs/BALANCING.md): nothing sold here may change rare package chances, discounts must be
-- genuine, no fake timers or pushy wording (Roblox monetization guidelines for all ages).

local RewardsConfig = require("./Rewards")

type Reward = RewardsConfig.Reward

export type Gamepass = {
	id: number,
	displayName: string,
	-- Bundles: passes this one also grants.
	includes: { string }?,
	-- Cosmetic passes: the style it unlocks (Config.Cosmetics).
	cosmeticId: string?,
}

export type ProductKind = "cash" | "boost" | "instantMachine" | "starterPack" | "doubleOffline" | "autoCollectTrial"

export type Product = {
	id: number,
	displayName: string,
	kind: ProductKind,
	-- cash, starterPack, doubleOffline (fallback): minutes of the buyer's current income ...
	incomeMinutes: number?,
	-- ... with this floor for players who have no income yet.
	minimumCash: number?,
	-- boost, starterPack: minutes of the cash boost; autoCollectTrial: minutes of Auto Collect.
	minutes: number?,
	-- starterPack: style included in the pack.
	cosmeticId: string?,
	-- Can only be bought once per player (starter pack).
	oneTime: boolean?,
}

export type AdPlacement = {
	-- Developer product granted when the video was watched to the end (also sold for Robux).
	productKey: string,
	-- Placement id from Creator Hub (Monetization > Ads > Placements) for reporting; 0 = default placement.
	placementId: number,
	-- Ads a player can watch for this reward per UTC day.
	dailyLimit: number,
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
	-- Walk faster: shorter trips between belt and chutes.
	speedyShoes = { id = 0, displayName = "Speedy Shoes" },
	-- Bundle of the three core passes; price it below the sum of the three in the Creator Hub.
	tycoonBundle = {
		id = 0,
		displayName = "Tycoon Bundle",
		includes = { "doubleCash", "autoCollect", "fastBelts" },
	},
	-- Styles (durable, so they are passes: they can't be bought twice and show up in Roblox's Shop).
	trailRainbow = { id = 0, displayName = "Rainbow Trail", cosmeticId = "trailRainbow" },
	beltNeon = { id = 0, displayName = "Neon Belts", cosmeticId = "beltNeon" },
	packageShiny = { id = 0, displayName = "Shiny Parcels", cosmeticId = "packageShiny" },
	warehouseParty = { id = 0, displayName = "Party Warehouse", cosmeticId = "warehouseParty" },
}

local products: { [string]: Product } = {
	-- Beginner offer: one purchase per player, clearly more value than the single items.
	starterPack = {
		id = 0,
		displayName = "Starter Pack",
		kind = "starterPack",
		incomeMinutes = 30,
		minimumCash = 2500,
		minutes = 30,
		cosmeticId = "beltGold",
		oneTime = true,
	},
	-- Cash packs that scale with progress.
	cashSmall = { id = 0, displayName = "Cash Stack", kind = "cash", incomeMinutes = 15, minimumCash = 250 },
	cashMedium = { id = 0, displayName = "Cash Bag", kind = "cash", incomeMinutes = 60, minimumCash = 1000 },
	cashLarge = { id = 0, displayName = "Cash Truck", kind = "cash", incomeMinutes = 240, minimumCash = 4000 },
	-- Time-limited boosts. The small one is also the reward of the boost video ad.
	boostSmall = { id = 0, displayName = "2x Cash (10 min)", kind = "boost", minutes = 10 },
	cashBoost = { id = 0, displayName = "2x Cash (30 min)", kind = "boost", minutes = 30 },
	-- Auto Collect for a while (also the reward of the "try Auto Collect" video ad).
	autoCollectTrial = { id = 0, displayName = "Auto Collect (15 min)", kind = "autoCollectTrial", minutes = 15 },
	-- Welcome back: pays the offline earnings a second time (also the reward of the welcome-back video ad).
	-- Without pending offline earnings (e.g. bought from Roblox's Shop) it pays this much cash instead.
	doubleOffline = {
		id = 0,
		displayName = "Double Offline Earnings",
		kind = "doubleOffline",
		incomeMinutes = 15,
		minimumCash = 250,
	},
	-- Instant upgrade: builds the next available sorting machine.
	instantMachine = { id = 0, displayName = "Instant Machine", kind = "instantMachine" },
}

-- Rewarded video ads (AdService). The ad grants the developer product through ProcessReceipt.
local ads: { [string]: AdPlacement } = {
	boost = { productKey = "boostSmall", placementId = 0, dailyLimit = 5 },
	doubleOffline = { productKey = "doubleOffline", placementId = 0, dailyLimit = 3 },
	autoCollectTrial = { productKey = "autoCollectTrial", placementId = 0, dailyLimit = 3 },
}

return {
	gamepasses = gamepasses,
	products = products,
	ads = ads,

	-- Display order in the store.
	gamepassOrder = {
		"tycoonBundle",
		"doubleCash",
		"autoCollect",
		"fastBelts",
		"speedyShoes",
		"biggerWarehouse",
		"vip",
	},
	productOrder = {
		"starterPack",
		"cashSmall",
		"cashMedium",
		"cashLarge",
		"boostSmall",
		"cashBoost",
		"autoCollectTrial",
		"instantMachine",
	},
	stylePassOrder = { "trailRainbow", "beltNeon", "packageShiny", "warehouseParty" },

	-- Monthly subscription "Parcel Club" (MarketplaceService subscriptions).
	club = {
		-- Subscription id from the Creator Hub ("EXP-..."); "" = not created yet (simulated in Studio).
		id = "",
		-- Extra cash while subscribed (added to the other bonuses).
		cashBonus = 0.2,
		-- Gift members can claim once per UTC day.
		dailyGift = { kind = "cash", incomeMinutes = 20, minimumCash = 500 } :: Reward,
		-- Style members can use while subscribed.
		cosmeticId = "trailClub",
	},

	-- Contextual offers: a small popup at the right moment, never more often than cooldownSeconds and each
	-- offer at most once per session. No timers, no "last chance" wording.
	offers = {
		cooldownSeconds = 300,
		-- Starter pack: after this purchase (the first machine), until it is bought.
		starterPackAfter = "b1_sorter1",
		-- Auto Collect: when the cash register is full.
		autoCollectWhenFull = true,
		-- Bigger Warehouse: once the fourth belt could be built.
		biggerWarehouseAfter = "b2_sorter3",
	},

	-- Pass effects.
	doubleCashMultiplier = 2,
	fastBeltsMultiplier = 1.25,
	speedyShoesWalkSpeed = 24,

	-- Instant Machine receipt with nothing left to build (e.g. bought twice quickly): cash instead.
	instantMachineFallback = { incomeMinutes = 30, minimumCash = 1000 },

	-- Grant id = 0 offers directly in Studio so everything can be tested before creating products.
	simulateInStudio = true,
	-- Receipts remembered per profile for idempotent ProcessReceipt handling.
	purchaseIdCacheSize = 100,
}
