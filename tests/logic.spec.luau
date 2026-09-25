--!strict
local Config = require("../src/shared/Config")
local DataSchema = require("../src/shared/DataSchema")
local Format = require("../src/shared/Format")
local PackageRoll = require("../src/shared/PackageRoll")
local Quests = require("../src/shared/Quests")
local Rewards = require("../src/shared/Rewards")
local Rng = require("../src/shared/Rng")
local Test = require("./Test")

-- Data schema ------------------------------------------------------------------------------------

Test.test("template is fresh on every call", function()
	local a = DataSchema.template()
	local b = DataSchema.template()
	a.progress.upgrades.beltSpeed = 3
	Test.equal(b.progress.upgrades.beltSpeed, nil)
	Test.equal(a.schemaVersion, DataSchema.VERSION)
end)

Test.test("migration upgrades unversioned data and fills missing fields", function()
	local old: any = { cash = 42, progress = { zone = "postOffice", rebirths = 1, upgrades = {}, purchases = {} } }
	local data = DataSchema.migrate(old)
	Test.equal(data.schemaVersion, DataSchema.VERSION)
	Test.equal(data.cash, 42)
	Test.equal(data.progress.rebirths, 1)
	Test.equal(data.stats.totalEarned, 0)
	Test.equal(data.daily.lastClaimDay, -1)
end)

Test.test("sanitize repairs broken values", function()
	local data = DataSchema.template()
	data.cash = 0 / 0
	data.progress.zone = "nowhere"
	data.progress.upgrades = { beltSpeed = 999, removedTrack = 3 }
	data.progress.purchases = { b1_sorter1 = true, oldMachine = true }
	DataSchema.sanitize(data)
	Test.equal(data.cash, 0)
	Test.equal(data.progress.zone, "postOffice")
	Test.equal(data.progress.upgrades.beltSpeed, 25)
	Test.equal(data.progress.upgrades.removedTrack, nil)
	Test.equal(data.progress.purchases.oldMachine, nil)
	Test.equal(data.progress.purchases.b1_sorter1, true)
end)

-- Package roll -----------------------------------------------------------------------------------

Test.test("package rolls follow spawn weights and rare chances", function()
	local rng = Rng.new(99)
	local counts = { 0, 0, 0 }
	local rares = 0
	local n = 60000
	for _ = 1, n do
		local roll = PackageRoll.roll("postOffice", function()
			return Rng.next(rng)
		end)
		counts[roll.typeIndex] += 1
		if roll.rare then
			rares += 1
		end
	end
	Test.near(counts[1] / n, 0.50, 0.01, "letters")
	Test.near(counts[3] / n, 0.15, 0.01, "crates")
	local expectedRare = 0
	for _, variant in Config.PackageTypes.rareVariants do
		expectedRare += variant.chance
	end
	Test.near(rares / n, expectedRare, 0.002, "rare share")
end)

-- Quests -----------------------------------------------------------------------------------------

Test.test("daily quests are deterministic per player and day", function()
	local a = Quests.drawDaily(20000, 12345, 100)
	local b = Quests.drawDaily(20000, 12345, 100)
	local c = Quests.drawDaily(20001, 12345, 100)
	Test.equal(#a, Config.Quests.dailyCount)
	for i = 1, #a do
		Test.equal(a[i].id, b[i].id)
	end
	local same = true
	for i = 1, #a do
		same = same and a[i].id == c[i].id
	end
	Test.truthy(not same, "a new day draws different quests")
	local seen = {}
	for _, quest in a do
		Test.truthy(not seen[quest.id], "no duplicate quests")
		seen[quest.id] = true
	end
end)

Test.test("daily quests progress, cap at their target and can be claimed once", function()
	local data = DataSchema.template().quests
	data.daily = { { id = "sortHand25", progress = 0, target = 25, claimed = false } }
	Test.equal(Quests.claim(data, "sortHand25", 100), nil)
	local result = Quests.applyEvent(data, { kind = "sortManual", amount = 30 })
	Test.truthy(result.changed, "progress changed")
	Test.equal(result.completed[1], "sortHand25")
	Test.equal(data.daily[1].progress, 25)
	Test.equal(Quests.claim(data, "sortHand25", 100), 500)
	Test.equal(Quests.claim(data, "sortHand25", 100), nil)
end)

Test.test("type quests only count their package type", function()
	local data = DataSchema.template().quests
	data.daily = { { id = "sortType3", progress = 0, target = 8, claimed = false } }
	Quests.applyEvent(data, { kind = "sortType", amount = 1, typeIndex = 1 })
	Test.equal(data.daily[1].progress, 0)
	Quests.applyEvent(data, { kind = "sortType", amount = 1, typeIndex = 3 })
	Test.equal(data.daily[1].progress, 1)
end)

Test.test("earn quests scale with income and have a floor", function()
	local def = Quests.def("earn10")
	assert(def, "earn10 missing")
	Test.equal(Quests.rewardCash(def, 0), def.rewardMinimumCash)
	local drawn = Quests.drawDaily(5, 5, 0)
	Test.truthy(#drawn == Config.Quests.dailyCount, "draws the configured count")
end)

-- Rewards ----------------------------------------------------------------------------------------

Test.test("rewards resolve cash with a floor and boosts", function()
	local cash = Rewards.resolve({ kind = "cash", incomeMinutes = 10, minimumCash = 50 }, { incomePerMinute = 100 })
	Test.equal(cash.cash, 1000)
	local floor = Rewards.resolve({ kind = "cash", incomeMinutes = 10, minimumCash = 50 }, { incomePerMinute = 0 })
	Test.equal(floor.cash, 50)
	local bonus = Rewards.resolve({ kind = "cash", packageValues = 5 }, { incomePerMinute = 0, packageValue = 10 })
	Test.equal(bonus.cash, 50)
	local boost = Rewards.resolve({ kind = "boost", minutes = 3 }, { incomePerMinute = 0 })
	Test.equal(boost.boostMinutes, 3)
end)

Test.test("mystery odds sum to 100 percent", function()
	local total = 0
	for _, entry in Rewards.mysteryOdds() do
		total += entry.percent
	end
	Test.near(total, 100, 1e-9)
end)

Test.test("daily rewards advance once per day and loop after 7", function()
	local daily = DataSchema.template().daily
	Test.truthy(Rewards.canClaimDaily(daily, 100))
	Test.truthy(Rewards.claimDaily(daily, 100) ~= nil)
	Test.equal(Rewards.claimDaily(daily, 100), nil)
	Test.equal(daily.step, 1)
	Rewards.claimDaily(daily, 105)
	Test.equal(daily.step, 2)
	for day = 106, 110 do
		Rewards.claimDaily(daily, day)
	end
	Test.equal(daily.step, 7)
	Rewards.claimDaily(daily, 111)
	Test.equal(daily.step, 1, "loops after day 7")
end)

-- Format -----------------------------------------------------------------------------------------------

Test.test("number formatting", function()
	Test.equal(Format.number(0), "0")
	Test.equal(Format.number(999), "999")
	Test.equal(Format.number(1000), "1K")
	Test.equal(Format.number(1234), "1.23K")
	Test.equal(Format.number(45600), "45.6K")
	Test.equal(Format.number(100000), "100K")
	Test.equal(Format.number(999999), "999K")
	Test.equal(Format.number(1.5e6), "1.5M")
	Test.equal(Format.cash(2.5e9), "$2.5B")
	Test.equal(Format.clock(75), "1:15")
	Test.equal(Format.clock(3725), "1:02:05")
	Test.equal(Format.percent(0.85), "85%")
end)
