--!strict
local Config = require("../src/shared/Config")
local DataSchema = require("../src/shared/DataSchema")
local Format = require("../src/shared/Format")
local PackageRoll = require("../src/shared/PackageRoll")
local Quests = require("../src/shared/Quests")
local Rewards = require("../src/shared/Rewards")
local Rng = require("../src/shared/Rng")
local Strings = require("../src/shared/Strings")
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
	Test.equal(#data.playtime.claimed, #Config.Rewards.playtime)
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
		Test.truthy(not roll.express, "no express packages in the post office")
	end
	Test.near(counts[1] / n, 0.50, 0.01, "letters")
	Test.near(counts[3] / n, 0.15, 0.01, "crates")
	local expectedRare = 0
	for _, variant in Config.PackageTypes.rareVariants do
		expectedRare += variant.chance
	end
	Test.near(rares / n, expectedRare, 0.002, "rare share")
end)

Test.test("airport cargo has express deliveries", function()
	local rng = Rng.new(7)
	local express = 0
	for _ = 1, 20000 do
		if PackageRoll.roll("airportCargo", function()
			return Rng.next(rng)
		end).express then
			express += 1
		end
	end
	Test.between(express / 20000, 0.10, 0.14, "express share")
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

Test.test("tutorial advances step by step", function()
	local data = DataSchema.template().quests
	local result = Quests.applyEvent(data, { kind = "grab", amount = 1 })
	Test.equal(result.tutorialCompleted and result.tutorialCompleted.id, "tutorialGrab")
	Test.equal(data.tutorialStep, 2)
	Quests.applyEvent(data, { kind = "sortManual", amount = 2, typeIndex = 1 })
	Test.equal(data.tutorialStep, 2)
	result = Quests.applyEvent(data, { kind = "sortManual", amount = 1, typeIndex = 2 })
	Test.equal(result.tutorialCompleted and result.tutorialCompleted.id, "tutorialSort")
	Quests.applyEvent(data, { kind = "buyPurchase", amount = 1, purchaseId = "spawner2" })
	Test.equal(data.tutorialStep, 3, "wrong purchase does not count")
end)

Test.test("daily quests progress, cap at their target and can be claimed once", function()
	local data = DataSchema.template().quests
	data.tutorialStep = #Config.Quests.tutorial + 1
	data.daily = { { id = "sortHand25", progress = 0, target = 25, claimed = false } }
	Test.equal(Quests.claimDaily(data, "sortHand25", 100), nil)
	local result = Quests.applyEvent(data, { kind = "sortManual", amount = 30 })
	Test.equal(result.dailyCompleted[1], "sortHand25")
	Test.equal(data.daily[1].progress, 25)
	local reward = Quests.claimDaily(data, "sortHand25", 100)
	Test.equal(reward, 500)
	Test.equal(Quests.claimDaily(data, "sortHand25", 100), nil)
end)

Test.test("earn quests scale with income and have a floor", function()
	local def = Quests.dailyDef("earn10")
	assert(def, "earn10 missing")
	local rich = Quests.drawDaily(1, 1, 0)
	Test.truthy(#rich > 0, "draws quests")
	Test.equal(Quests.rewardCash(def, 0), def.rewardMinimumCash)
end)

-- Rewards ----------------------------------------------------------------------------------------

local function context(income: number, owned: { [string]: boolean }?): Rewards.Context
	return {
		incomePerMinute = income,
		packageValue = 10,
		ownsCosmetic = function(id)
			return owned ~= nil and owned[id] == true
		end,
	}
end

Test.test("rewards resolve cash, boosts and cosmetics with fallback", function()
	local cash = Rewards.resolve({ kind = "cash", incomeMinutes = 10, minimumCash = 50 }, context(100))
	Test.equal(cash.cash, 1000)
	local floor = Rewards.resolve({ kind = "cash", incomeMinutes = 10, minimumCash = 50 }, context(0))
	Test.equal(floor.cash, 50)
	local boost = Rewards.resolve({ kind = "boost", minutes = 3 }, context(0))
	Test.equal(boost.boostMinutes, 3)
	local reward: Rewards.Reward = {
		kind = "cosmetic",
		cosmeticId = "trailSparkle",
		fallback = { kind = "cash", packageValues = 5 },
	}
	Test.equal(Rewards.resolve(reward, context(0)).cosmeticId, "trailSparkle")
	local fallback = Rewards.resolve(reward, context(0, { trailSparkle = true }))
	Test.equal(fallback.cosmeticId, nil)
	Test.equal(fallback.cash, 50)
end)

Test.test("mystery odds sum to 100 percent", function()
	local total = 0
	for _, entry in Rewards.mysteryOdds() do
		total += entry.percent
	end
	Test.near(total, 100, 1e-9)
end)

Test.test("login calendar advances once per day and never resets", function()
	local daily = DataSchema.template().daily
	Test.truthy(Rewards.canClaimDaily(daily, 100))
	Test.truthy(Rewards.claimDaily(daily, 100) ~= nil)
	Test.equal(Rewards.claimDaily(daily, 100), nil)
	Test.equal(daily.step, 1)
	-- Skipping days does not reset the calendar.
	Rewards.claimDaily(daily, 105)
	Test.equal(daily.step, 2)
	for day = 106, 110 do
		Rewards.claimDaily(daily, day)
	end
	Test.equal(daily.step, 7)
	Rewards.claimDaily(daily, 111)
	Test.equal(daily.step, 1, "loops after day 7")
end)

Test.test("playtime gifts unlock by minutes played today", function()
	local playtime = DataSchema.template().playtime
	Rewards.ensurePlaytimeDay(playtime, 50)
	Test.truthy(not Rewards.canClaimGift(playtime, 1))
	playtime.seconds = Config.Rewards.playtime[1].minutes * 60
	Test.truthy(Rewards.claimGift(playtime, 1) ~= nil)
	Test.equal(Rewards.claimGift(playtime, 1), nil)
	Rewards.ensurePlaytimeDay(playtime, 51)
	Test.equal(playtime.seconds, 0)
	Test.equal(playtime.claimed[1], false)
end)

-- Format and strings -----------------------------------------------------------------------------

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

Test.test("english and german have the same keys", function()
	local en = Strings.tables.en
	local de = Strings.tables.de
	for key in en do
		Test.truthy(de[key] ~= nil, `missing German text for {key}`)
	end
	for key in de do
		Test.truthy(en[key] ~= nil, `German text without English key: {key}`)
	end
end)

Test.test("strings interpolate and fall back to English", function()
	Strings.setLocale("de-de")
	Test.equal(Strings.get("shop.level", { level = 2, max = 5 }), "Stufe 2/5")
	Strings.setLocale("fr-fr")
	Test.equal(Strings.get("shop.level", { level = 2, max = 5 }), "Level 2/5")
	Test.equal(Strings.get("does.not.exist"), "does.not.exist")
	Strings.setLocale("en-us")
end)

Test.test("every package type, upgrade, pass and product has texts", function()
	for _, packageType in Config.PackageTypes.types do
		Test.truthy(Strings.tables.en["package." .. packageType.id], `name for {packageType.id}`)
		Test.truthy(Strings.tables.en["dest." .. packageType.id], `destination for {packageType.id}`)
	end
	for _, track in Config.Upgrades.tracks do
		Test.truthy(Strings.tables.en["upgrade." .. track.id .. ".name"], `name for {track.id}`)
		Test.truthy(Strings.tables.en["upgrade." .. track.id .. ".desc"], `description for {track.id}`)
	end
	for key in Config.Monetization.gamepasses do
		Test.truthy(Strings.tables.en["pass." .. key .. ".name"], `name for pass {key}`)
	end
	for _, zone in Config.Zones.zones do
		Test.truthy(Strings.tables.en["zone." .. zone.id], `name for zone {zone.id}`)
	end
	for _, entry in Config.Rewards.mystery do
		Test.truthy(Strings.tables.en["reward." .. entry.id], `name for mystery reward {entry.id}`)
	end
	for _, def in Config.Quests.tutorial do
		Test.truthy(Strings.tables.en["tutorial." .. def.kind], `tutorial hint for {def.kind}`)
	end
end)
