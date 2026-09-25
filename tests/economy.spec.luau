--!strict
local Config = require("../src/shared/Config")
local Economy = require("../src/shared/Economy")
local Test = require("./Test")

Test.test("upgrade cost follows base * growth ^ level", function()
	local track = Economy.getTrack("beltSpeed")
	Test.equal(Economy.upgradeCost("beltSpeed", 0), track.baseCost)
	Test.equal(Economy.upgradeCost("beltSpeed", 5), math.floor(track.baseCost * track.growth ^ 5 + 0.5))
end)

Test.test("maxed track has no next cost", function()
	local track = Economy.getTrack("beltSpeed")
	Test.equal(Economy.upgradeCost("beltSpeed", track.maxLevel), nil)
end)

Test.test("new progress earns only from manual sorting", function()
	local progress = Economy.newProgress()
	local income = Economy.incomePerMinute(progress, 12)
	Test.equal(income.machinesPerMinute, 0)
	Test.truthy(income.manualPerMinute > 0, "manual income should be positive")
end)

Test.test("sorter automates its package type up to its rate", function()
	local progress = Economy.newProgress()
	progress.purchases.sorter1_letter = true
	local letterShare = 50 / 100
	local arriving = Config.Economy.spawnsPerMinute * letterShare
	local expected = math.min(arriving, Config.Economy.sorterBaseRate) * 3
	Test.near(Economy.incomePerMinute(progress).machinesPerMinute, expected, 1e-9)
end)

Test.test("purchases unlock in order", function()
	local progress = Economy.newProgress()
	Test.truthy(Economy.isPurchaseAvailable(progress, "sorter1_letter"))
	Test.truthy(not Economy.isPurchaseAvailable(progress, "sorter1_box"), "box sorter needs letter sorter")
	progress.purchases.sorter1_letter = true
	Test.truthy(Economy.isPurchaseAvailable(progress, "sorter1_box"))
	Test.truthy(not Economy.isPurchaseAvailable(progress, "sorter1_letter"), "owned purchase is not available")
end)

Test.test("every purchase prerequisite exists", function()
	for _, purchase in Config.Purchases.purchases do
		if purchase.requires then
			Economy.getPurchase(purchase.requires)
		end
	end
end)

Test.test("rebirth multiplier and cost", function()
	Test.equal(Economy.rebirthMultiplier(0), 1)
	Test.equal(Economy.rebirthMultiplier(2), 2)
	Test.equal(Economy.rebirthCost(0), Config.Economy.rebirth.baseCost)
	Test.equal(Economy.rebirthCost(1), Config.Economy.rebirth.baseCost * Config.Economy.rebirth.costGrowth)
end)

Test.test("offline earnings are machine-only and capped", function()
	local progress = Economy.newProgress()
	Test.equal(Economy.offlineEarnings(progress, 3600), 0)
	progress.purchases.sorter1_letter = true
	local perMinute = Economy.incomePerMinute(progress).machinesPerMinute * Config.Economy.offline.efficiency
	local capMinutes = Config.Economy.offline.baseCapHours * 60
	Test.equal(Economy.offlineEarnings(progress, 10 * 3600), math.floor(perMinute * capMinutes))
	progress.upgrades.offlineCap = 1
	Test.equal(Economy.offlineCapHours(progress), Config.Economy.offline.baseCapHours + 2)
end)

Test.test("cash packs scale with income and respect the floor", function()
	Test.equal(Economy.cashPackAmount(0, 15, 250), 250)
	Test.equal(Economy.cashPackAmount(1000, 15, 250), 15000)
end)

Test.test("config is frozen", function()
	Test.truthy(table.isfrozen(Config.Economy), "Config.Economy should be frozen")
	Test.truthy(table.isfrozen(Config.PackageTypes.types[1]), "nested config should be frozen")
end)
