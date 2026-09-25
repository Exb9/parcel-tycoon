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

Test.test("a sorter automates its type as long as the player keeps the belt moving", function()
	local progress = Economy.newProgress()
	progress.purchases.b1_sorter1 = true
	local letter = Economy.packageTypeAt("postOffice", 1)
	assert(letter, "letter type missing")
	-- Supply 14/min: letters (7/min) stay below the machine rate, the player handles the rest.
	local arriving = Config.Economy.spawnsPerMinute * letter.spawnWeight / 100 * (1 - Economy.rareShare())
	local expected = arriving * letter.baseValue * Config.Economy.sorterBaseAccuracy
	Test.near(Economy.incomePerMinute(progress, 12).machinesPerMinute, expected, 1e-6)
	progress.upgrades.sorterAccuracy = 5
	Test.equal(Economy.sorterAccuracy(progress), 1)
end)

Test.test("without manual help a belt with unsorted types jams (paused chute)", function()
	local progress = Economy.newProgress()
	progress.purchases.b1_sorter1 = true
	Test.equal(Economy.incomePerMinute(progress, 0).totalPerMinute, 0)
end)

Test.test("manual capacity limits a belt's intake", function()
	local progress = Economy.newProgress()
	progress.upgrades.beltSpeed = 25
	progress.purchases = { spawner2 = true, spawner3 = true }
	-- 147 packages/min arrive but without machines the player's 12 sorts/min are the whole intake.
	local income = Economy.incomePerMinute(progress, 12)
	local crate = Economy.packageTypeAt("postOffice", 3)
	assert(crate, "crate type missing")
	Test.truthy(income.manualPerMinute <= 12 * crate.baseValue + 1e-6, "manual income bounded by the manual rate")
	Test.equal(income.machinesPerMinute, 0)
end)

Test.test("purchases unlock in order and respect required passes", function()
	local progress = Economy.newProgress()
	Test.truthy(Economy.isPurchaseAvailable(progress, "b1_sorter1"))
	Test.truthy(not Economy.isPurchaseAvailable(progress, "b1_sorter2"), "second sorter needs the first")
	progress.purchases.b1_sorter1 = true
	Test.truthy(Economy.isPurchaseAvailable(progress, "b1_sorter2"))
	Test.truthy(not Economy.isPurchaseAvailable(progress, "b1_sorter1"), "owned purchase is not available")

	progress.purchases.b2_sorter3 = true
	Test.truthy(not Economy.isPurchaseAvailable(progress, "belt4"), "belt 4 needs the pass")
	Test.truthy(Economy.isPurchaseAvailable(progress, "belt4", { biggerWarehouse = true }))
end)

Test.test("purchase references are consistent", function()
	for _, purchase in Config.Purchases.purchases do
		if purchase.requires then
			Economy.getPurchase(purchase.requires)
		end
		if purchase.requiresPass then
			Test.truthy(Config.Monetization.gamepasses[purchase.requiresPass], `unknown pass {purchase.requiresPass}`)
		end
		if purchase.kind == "sorter" then
			Test.truthy(purchase.belt and purchase.typeIndex, `sorter {purchase.id} needs belt and typeIndex`)
		end
	end
end)

Test.test("the post office has three package types with indices 1-3", function()
	local types = Economy.packageTypesForZone("postOffice")
	Test.equal(#types, 3)
	for i, packageType in types do
		Test.equal(packageType.index, i)
	end
end)

Test.test("rebirth resets money-bought progress and keeps the zone", function()
	local progress = Economy.newProgress()
	progress.rebirths = 2
	progress.upgrades = { beltSpeed = 10, offlineCap = 2, collectorCapacity = 1 }
	progress.purchases = { b1_sorter1 = true }
	local after = Economy.rebirth(progress)
	Test.equal(after.rebirths, 3)
	Test.equal(after.zone, "postOffice")
	Test.equal(next(after.upgrades), nil)
	Test.equal(next(after.purchases), nil)
end)

Test.test("rebirth multiplier and cost", function()
	Test.equal(Economy.rebirthMultiplier(0), 1)
	Test.equal(Economy.rebirthMultiplier(2), 2)
	Test.equal(Economy.rebirthCost(0), Config.Economy.rebirth.baseCost)
	Test.equal(Economy.rebirthCost(1), Config.Economy.rebirth.baseCost * Config.Economy.rebirth.costGrowth)
end)

Test.test("cash multiplier stacks 2x Cash and the boost", function()
	Test.equal(Economy.cashMultiplier(nil, false), 1)
	Test.equal(Economy.cashMultiplier({ doubleCash = true }, false), 2)
	Test.equal(Economy.cashMultiplier({ doubleCash = true }, true), 4)
	Test.equal(Economy.cashMultiplier({ vip = true }, false), 1)
end)

Test.test("offline earnings are a capped share of machine income", function()
	local progress = Economy.newProgress()
	Test.equal(Economy.offlineEarnings(progress, 3600), 0)
	progress.purchases.b1_sorter1 = true
	local perMinute = Economy.machineIncome(progress) * Config.Economy.offline.efficiency
	local capMinutes = Config.Economy.offline.baseCapHours * 60
	Test.equal(Economy.offlineEarnings(progress, 10 * 3600), math.floor(perMinute * capMinutes))
	Test.equal(
		Economy.offlineEarnings(progress, 10 * 3600, { doubleCash = true }),
		math.floor(perMinute * 2 * capMinutes)
	)
	progress.upgrades.offlineCap = 1
	Test.equal(Economy.offlineCapHours(progress), Config.Economy.offline.baseCapHours + 2)
end)

Test.test("cash register capacity has a floor and grows with its upgrade", function()
	local progress = Economy.newProgress()
	Test.equal(Economy.collectorCapacity(progress), Config.Economy.collector.minimumCapacity)
	progress.purchases.b1_sorter1 = true
	progress.upgrades.packageValue = 40
	local base = Economy.collectorCapacity(progress)
	progress.upgrades.collectorCapacity = 1
	Test.truthy(Economy.collectorCapacity(progress) > base, "capacity upgrade should raise the cap")
end)

Test.test("cash packs scale with income and respect the floor", function()
	Test.equal(Economy.cashPackAmount(0, 15, 250), 250)
	Test.equal(Economy.cashPackAmount(1000, 15, 250), 15000)
end)

Test.test("next sorter purchase follows the unlock order", function()
	local progress = Economy.newProgress()
	local first = Economy.nextSorterPurchase(progress)
	Test.equal(first and first.id, "b1_sorter1")
	progress.purchases.b1_sorter1 = true
	local second = Economy.nextSorterPurchase(progress)
	Test.equal(second and second.id, "b1_sorter2")
end)

Test.test("config is frozen", function()
	Test.truthy(table.isfrozen(Config.Economy), "Config.Economy should be frozen")
	Test.truthy(table.isfrozen(Config.PackageTypes.types[1]), "nested config should be frozen")
end)
