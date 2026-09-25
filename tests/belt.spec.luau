--!strict
local BeltQueue = require("../src/shared/BeltQueue")
local BeltSim = require("./BeltSim")
local Economy = require("../src/shared/Economy")
local Test = require("./Test")

local function newBelt(): BeltQueue.Belt
	-- 20 studs long, gap 0, speed 2 studs/s, at most 10 items.
	return BeltQueue.new(20, 0, 2, 10)
end

Test.test("items move at belt speed and stop at the end", function()
	local belt = newBelt()
	local item = BeltQueue.spawn(belt, 1, 2, nil, 0)
	Test.near(BeltQueue.distanceAt(item, 0), 1, 1e-9)
	Test.near(BeltQueue.distanceAt(item, 2), 5, 1e-9)
	Test.near(BeltQueue.distanceAt(item, 100), 19, 1e-9)
end)

Test.test("items line up behind each other", function()
	local belt = newBelt()
	local first = BeltQueue.spawn(belt, 1, 2, nil, 0)
	local second = BeltQueue.spawn(belt, 2, 2, nil, 0)
	Test.near(first.stop, 19, 1e-9)
	Test.near(second.stop, 17, 1e-9)
end)

Test.test("the chute pauses when the line reaches the start and resumes after a removal", function()
	local belt = newBelt()
	local now = 0
	local spawned = 0
	for id = 1, 20 do
		if BeltQueue.canSpawn(belt, 2, now) then
			BeltQueue.spawn(belt, id, 2, nil, now)
			spawned += 1
		end
		now += 1.5
	end
	-- 20 studs hold exactly ten 2-stud items.
	Test.equal(#belt.items, 10)
	Test.equal(spawned, 10)
	now += 100
	Test.truthy(not BeltQueue.canSpawn(belt, 2, now), "full belt pauses the chute")
	BeltQueue.remove(belt, belt.items[1], now)
	Test.truthy(BeltQueue.canSpawn(belt, 2, now + 2), "room again once the line moved up")
end)

Test.test("removing the front lets the others move up from where they are", function()
	local belt = newBelt()
	local first = BeltQueue.spawn(belt, 1, 2, nil, 0)
	local second = BeltQueue.spawn(belt, 2, 2, nil, 0)
	local changed = BeltQueue.remove(belt, first, 100)
	Test.equal(#changed, 1)
	Test.equal(changed[1], second)
	Test.near(BeltQueue.distanceAt(second, 100), 17, 1e-9)
	Test.near(BeltQueue.distanceAt(second, 101), 19, 1e-9)
end)

Test.test("spawning waits until the start is clear", function()
	local belt = newBelt()
	BeltQueue.spawn(belt, 1, 2, nil, 0)
	Test.truthy(not BeltQueue.canSpawn(belt, 2, 0), "start is blocked right after a spawn")
	Test.truthy(BeltQueue.canSpawn(belt, 2, 1.5), "free again once the first item moved on")
end)

Test.test("speed changes keep positions continuous", function()
	local belt = newBelt()
	local item = BeltQueue.spawn(belt, 1, 2, nil, 0)
	BeltQueue.setSpeed(belt, 4, 2)
	Test.near(BeltQueue.distanceAt(item, 2), 5, 1e-9)
	Test.near(BeltQueue.distanceAt(item, 3), 9, 1e-9)
end)

Test.test("machines see packages in front of them, moving or waiting", function()
	local belt = newBelt()
	local item = BeltQueue.spawn(belt, 1, 2, nil, 0)
	Test.equal(#BeltQueue.inRange(belt, 0, 6, 10), 0)
	Test.equal(#BeltQueue.inRange(belt, 3.5, 6, 10), 1, "passing by")
	Test.equal(#BeltQueue.inRange(belt, 100, 17, 21), 1, "waiting at the end")
	Test.equal(BeltQueue.inRange(belt, 100, 17, 21)[1], item)
end)

-- The balancing uses Economy.incomePerMinute; the real belts must deliver about the same.
local function compare(name: string, progress: Economy.Progress, manual: number)
	local model = Economy.incomePerMinute(progress, manual)
	local sim = BeltSim.run(progress, 20, manual, 12345)
	local total = (sim.machinesPerMinute + sim.manualPerMinute) / model.totalPerMinute
	Test.between(total, 0.85, 1.1, `{name}: total income sim/model`)
	if model.machinesPerMinute > 0 then
		Test.between(sim.machinesPerMinute / model.machinesPerMinute, 0.85, 1.1, `{name}: machine income sim/model`)
	end
end

Test.test("belt simulation matches the economy model early on", function()
	local progress = Economy.newProgress()
	progress.purchases.b1_sorter1 = true
	compare("first sorter", progress, 12)
end)

Test.test("belt simulation matches the economy model mid game", function()
	local progress = Economy.newProgress()
	progress.upgrades = { beltSpeed = 10, packageValue = 15, sorterSpeed = 4 }
	progress.purchases = {
		b1_sorter1 = true,
		b1_sorter2 = true,
		b1_sorter3 = true,
		spawner2 = true,
		belt2 = true,
		b2_sorter1 = true,
	}
	compare("mid game", progress, 12)
end)

Test.test("belt simulation matches the economy model when the belt jams", function()
	local progress = Economy.newProgress()
	progress.upgrades = { beltSpeed = 25 }
	progress.purchases = { b1_sorter1 = true, b1_sorter2 = true, b1_sorter3 = true, spawner2 = true, spawner3 = true }
	compare("jammed", progress, 12)
end)

Test.test("belt simulation matches the economy model with two automated belts", function()
	local progress = Economy.newProgress()
	progress.upgrades = { beltSpeed = 12, sorterSpeed = 8 }
	progress.purchases = {
		b1_sorter1 = true,
		b1_sorter2 = true,
		b1_sorter3 = true,
		spawner2 = true,
		belt2 = true,
		b2_sorter1 = true,
		b2_sorter2 = true,
		b2_sorter3 = true,
	}
	compare("two automated belts", progress, 12)
end)

Test.test("an idle player's belt jams and the machines stop (paused chute)", function()
	local progress = Economy.newProgress()
	progress.purchases.b1_sorter1 = true
	local sim = BeltSim.run(progress, 30, 0, 99)
	-- Boxes and crates have no machine: they fill the belt and everything stops.
	Test.truthy(sim.spawnedPerMinute < 2, `belt should jam, spawned {sim.spawnedPerMinute}/min`)
	Test.equal(Economy.incomePerMinute(progress, 0).totalPerMinute, 0)
end)

Test.test("rare packages add roughly 10 % for an active player mid game", function()
	local progress = Economy.newProgress()
	progress.upgrades = { beltSpeed = 10, packageValue = 15, sorterSpeed = 4 }
	progress.purchases = {
		b1_sorter1 = true,
		b1_sorter2 = true,
		b1_sorter3 = true,
		spawner2 = true,
		belt2 = true,
		b2_sorter1 = true,
	}
	local sim = BeltSim.run(progress, 30, 12, 777)
	local share = sim.rareBonusPerMinute / (sim.machinesPerMinute + sim.manualPerMinute + sim.rareBonusPerMinute)
	Test.between(share, 0.03, 0.15, "rare bonus share of income")
end)
