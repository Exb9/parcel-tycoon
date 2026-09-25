--!strict
-- Feature pack: data migration, playtime gifts, rebirth milestones, codes, tutorial, ad limits, bonuses
-- and the consistency of the monetization config.

local Ads = require("../src/shared/Ads")
local Config = require("../src/shared/Config")
local DataSchema = require("../src/shared/DataSchema")
local Economy = require("../src/shared/Economy")
local Onboarding = require("../src/shared/Onboarding")
local Rewards = require("../src/shared/Rewards")
local Test = require("./Test")

local function cosmeticExists(cosmeticId: string): boolean
	for _, item in Config.Cosmetics.items do
		if item.id == cosmeticId then
			return true
		end
	end
	return false
end

-- Data -------------------------------------------------------------------------------------------

Test.test("new players start the tutorial, players from schema 1 who already sorted skip it", function()
	Test.equal(DataSchema.template().onboarding.done, false)
	local old: any = {
		schemaVersion = 1,
		cash = 10,
		stats = { sortedTotal = 42 },
		progress = { zone = "postOffice", rebirths = 0, upgrades = {}, purchases = {} },
	}
	local data = DataSchema.migrate(old)
	Test.equal(data.schemaVersion, 2)
	Test.equal(data.onboarding.done, true)
	Test.equal(data.playtime.claimed, 0)
	Test.equal(data.autoCollectUntil, 0)
	local fresh: any = { schemaVersion = 1, stats = { sortedTotal = 0 } }
	Test.equal(DataSchema.migrate(fresh).onboarding.done, false)
end)

-- Playtime gifts ------------------------------------------------------------------------------------

Test.test("playtime gifts open in order once their time has come and reset every day", function()
	local playtime = DataSchema.template().playtime
	Rewards.ensurePlaytimeDay(playtime, 100)
	local first = Config.Rewards.playtime[1]
	playtime.seconds = first.minutes * 60 - 1
	Test.equal(Rewards.openGift(playtime, 100), nil, "too early")
	Test.equal(Rewards.secondsToNextGift(playtime), 1)
	playtime.seconds += 1
	Test.truthy(Rewards.openGift(playtime, 100) == first.reward, "first gift")
	Test.equal(playtime.claimed, 1)
	Test.equal(Rewards.openGift(playtime, 100), nil, "second gift needs more time")
	playtime.seconds = 24 * 3600
	for _ = 2, #Config.Rewards.playtime do
		Test.truthy(Rewards.openGift(playtime, 100) ~= nil)
	end
	Test.equal(Rewards.openGift(playtime, 100), nil, "all opened")
	Test.equal(Rewards.secondsToNextGift(playtime), nil)
	Test.truthy(Rewards.ensurePlaytimeDay(playtime, 101), "new day")
	Test.equal(playtime.claimed, 0)
	Test.equal(playtime.seconds, 0)
end)

Test.test("rebirth milestones are pending once reached and not yet rewarded", function()
	local milestones = {}
	Test.equal(#Rewards.pendingMilestones(milestones, 0), 0)
	local reached = Rewards.pendingMilestones(milestones, 3)
	Test.equal(#reached, 2)
	Test.equal(reached[1].rebirths, 1)
	milestones["1"] = true
	Test.equal(#Rewards.pendingMilestones(milestones, 3), 1)
end)

Test.test("codes ignore case, spaces and punctuation", function()
	Test.equal(Rewards.normalizeCode(" welcome! "), "WELCOME")
	Test.equal(Rewards.normalizeCode("Par-cels 2"), "PARCELS2")
end)

-- Tutorial ----------------------------------------------------------------------------------------------

Test.test("the tutorial advances with the right events and finishes once", function()
	local state = DataSchema.template().onboarding
	Test.equal((Onboarding.current(state) :: any).id, "grab")
	Test.equal(Onboarding.applyEvent(state, "sortManual").changed, false, "wrong event")
	Onboarding.applyEvent(state, "grab")
	Test.equal((Onboarding.current(state) :: any).id, "sort")
	Onboarding.applyEvent(state, "sortManual")
	for _ = 1, 4 do
		Onboarding.applyEvent(state, "sortManual")
	end
	Test.equal(state.count, 4, "sortMore counts")
	Onboarding.applyEvent(state, "sortManual")
	Test.equal((Onboarding.current(state) :: any).id, "buyMachine")
	Onboarding.applyEvent(state, "buyPurchase")
	local result = Onboarding.skip(state)
	Test.truthy(result.finished, "collect skipped -> finished")
	Test.equal(Onboarding.current(state), nil)
	Test.equal(Onboarding.applyEvent(state, "grab").changed, false, "done stays done")
end)

-- Ads ----------------------------------------------------------------------------------------------

Test.test("rewarded ads respect the daily limit per placement", function()
	local ads = DataSchema.template().ads
	local limit = Config.Monetization.ads.boost.dailyLimit
	for _ = 1, limit do
		Test.truthy(Ads.record(ads, 10, "boost"))
	end
	Test.equal(Ads.remaining(ads, 10, "boost"), 0)
	Test.equal(Ads.record(ads, 10, "boost"), false)
	Test.equal(Ads.remaining(ads, 10, "doubleOffline"), Config.Monetization.ads.doubleOffline.dailyLimit)
	Test.equal(Ads.remaining(ads, 11, "boost"), limit, "new day")
	Test.equal(Ads.remaining(ads, 10, "unknown"), 0)
	Test.equal(Ads.placementForProduct("boostSmall"), "boost")
	Test.equal(Ads.placementForProduct("cashLarge"), nil)
end)

-- Bonuses ------------------------------------------------------------------------------------------------

Test.test("cash bonuses add up and stack with 2x Cash and the boost", function()
	local rewards = Config.Rewards
	Test.near(Economy.cashBonus(10, false, false), rewards.friends.maxBonus, 1e-9, "friends bonus is capped")
	local group = if rewards.group.groupId ~= 0 then rewards.group.cashBonus else 0
	local bonus = Economy.cashBonus(1, true, true)
	Test.near(bonus, rewards.friends.bonusPerFriend + group + Config.Monetization.club.cashBonus, 1e-9)
	local multiplier = Economy.cashMultiplier({ doubleCash = true }, true, bonus)
	Test.near(multiplier, (1 + bonus) * Config.Monetization.doubleCashMultiplier * Config.Economy.boostMultiplier, 1e-9)
	Test.near(Economy.cashMultiplier(nil, false), 1, 1e-9)
end)

-- Monetization config ---------------------------------------------------------------------------------

Test.test("monetization config is consistent", function()
	local monetization = Config.Monetization
	for key, pass in monetization.gamepasses do
		for _, included in pass.includes or {} do
			Test.truthy(
				monetization.gamepasses[included] ~= nil and included ~= key,
				`{key} includes unknown pass {included}`
			)
		end
		if pass.cosmeticId then
			Test.truthy(cosmeticExists(pass.cosmeticId), `{key} unlocks unknown style {pass.cosmeticId}`)
		end
	end
	for placement, ad in monetization.ads do
		Test.truthy(monetization.products[ad.productKey] ~= nil, `ad {placement} grants unknown product`)
	end
	for _, list in { monetization.gamepassOrder, monetization.stylePassOrder } do
		for _, key in list do
			Test.truthy(monetization.gamepasses[key] ~= nil, `unknown pass {key} in store order`)
		end
	end
	for _, key in monetization.productOrder do
		Test.truthy(monetization.products[key] ~= nil, `unknown product {key} in store order`)
	end
	for key, product in monetization.products do
		if product.cosmeticId then
			Test.truthy(cosmeticExists(product.cosmeticId), `{key} includes unknown style {product.cosmeticId}`)
		end
	end
	Test.truthy(cosmeticExists(monetization.club.cosmeticId), "club style")
	for _, milestone in Config.Rewards.rebirthMilestones do
		if milestone.cosmeticId then
			Test.truthy(cosmeticExists(milestone.cosmeticId), `milestone style {milestone.cosmeticId}`)
		end
	end
	Test.truthy(Economy.findPurchase(monetization.offers.starterPackAfter) ~= nil, "starter pack trigger")
	Test.truthy(Economy.findPurchase(monetization.offers.biggerWarehouseAfter) ~= nil, "warehouse offer trigger")
end)
