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

Test.test("sorter automates its type index up to its rate, scaled by accuracy", function()
	local progress = Economy.newProgress()
	progress.purchases.b1_sorter1 = true
	local letter = Economy.packageTypeAt("postOffice", 1)
	assert(letter, "letter type missing")
	local arriving = Config.Economy.spawnsPerMinute * letter.spawnWeight / 100
	local expected = math.min(arriving, Config.Economy.sorterBaseRate)
		* letter.baseValue
		* Config.Economy.sorterBaseAccuracy
	Test.near(Economy.incomePerMinute(progress).machinesPerMinute, expected, 1e-9)
	progress.upgrades.sorterAccuracy = 5
	Test.equal(Economy.sorterAccuracy(progress), 1)
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

Test.test("every available zone has three package types with indices 1-3", function()
	for _, zone in Config.Zones.zones do
		if zone.available then
			local types = Economy.packageTypesForZone(zone.id)
			Test.equal(#types, 3, `types in {zone.id}`)
			for i, packageType in types do
				Test.equal(packageType.index, i, `index order in {zone.id}`)
			end
		end
	end
end)

Test.test("zones unlock by rebirths and skip unavailable ones", function()
	Test.equal(Economy.highestUnlockedZone(0), "postOffice")
	Test.equal(Economy.highestUnlockedZone(2), "postOffice")
	Test.equal(Economy.highestUnlockedZone(3), "airportCargo")
	Test.equal(Economy.highestUnlockedZone(50), "airportCargo")
end)

Test.test("rebirth resets progress but keeps comfort upgrades", function()
	local progress = Economy.newProgress()
	progress.rebirths = 2
	progress.upgrades = { beltSpeed = 10, offlineCap = 2, collectorCapacity = 1 }
	progress.purchases = { b1_sorter1 = true }
	local after = Economy.rebirth(progress)
	Test.equal(after.rebirths, 3)
	Test.equal(after.zone, "airportCargo")
	Test.equal(after.upgrades.beltSpeed, nil)
	Test.equal(after.upgrades.offlineCap, 2)
	Test.equal(after.upgrades.collectorCapacity, 1)
	Test.equal(next(after.purchases), nil)
end)

Test.test("rebirth multiplier and cost", function()
	Test.equal(Economy.rebirthMultiplier(0), 1)
	Test.equal(Economy.rebirthMultiplier(2), 2)
	Test.equal(Economy.rebirthCost(0), Config.Economy.rebirth.baseCost)
	Test.equal(Economy.rebirthCost(1), Config.Economy.rebirth.baseCost * Config.Economy.rebirth.costGrowth)
end)

Test.test("cash multiplier stacks passes and boost", function()
	Test.equal(Economy.cashMultiplier(nil, false), 1)
	Test.equal(Economy.cashMultiplier({ doubleCash = true }, true), 4)
	Test.near(Economy.cashMultiplier({ vip = true }, false), 1 + Config.Monetization.vipCashBonus, 1e-9)
end)

Test.test("offline earnings are machine-only, capped and ignore short absences", function()
	local progress = Economy.newProgress()
	Test.equal(Economy.offlineEarnings(progress, 3600), 0)
	progress.purchases.b1_sorter1 = true
	Test.equal(Economy.offlineEarnings(progress, 60), 0)
	local perMinute = Economy.incomePerMinute(progress).machinesPerMinute * Config.Economy.offline.efficiency
	local capMinutes = Config.Economy.offline.baseCapHours * 60
	Test.equal(Economy.offlineEarnings(progress, 10 * 3600), math.floor(perMinute * capMinutes))
	Test.equal(
		Economy.offlineEarnings(progress, 10 * 3600, { doubleCash = true }),
		math.floor(perMinute * capMinutes * 2)
	)
	progress.upgrades.offlineCap = 1
	Test.equal(Economy.offlineCapHours(progress), Config.Economy.offline.baseCapHours + 2)
end)

Test.test("collector capacity has a floor and grows with its upgrade", function()
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
