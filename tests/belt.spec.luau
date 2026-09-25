--!strict
local BeltQueue = require("../src/shared/BeltQueue")
local BeltSim = require("./BeltSim")
local Economy = require("../src/shared/Economy")
local Test = require("./Test")

local function newBelt(): BeltQueue.Belt
	-- 20 studs long, the last 6 are the queue, gap 0, speed 2 studs/s.
	return BeltQueue.new(20, 6, 0, 2, 10)
end

Test.test("items move at belt speed and stop at the end", function()
	local belt = newBelt()
	local item = BeltQueue.spawn(belt, 1, 2, nil, 0)
	Test.near(BeltQueue.distanceAt(item, 0), 1, 1e-9)
	Test.near(BeltQueue.distanceAt(item, 2), 5, 1e-9)
	Test.near(BeltQueue.distanceAt(item, 100), 19, 1e-9)
	Test.truthy(not item.overflow, "first item fits")
end)

Test.test("items queue behind each other", function()
	local belt = newBelt()
	local first = BeltQueue.spawn(belt, 1, 2, nil, 0)
	local second = BeltQueue.spawn(belt, 2, 2, nil, 0)
	Test.near(first.stop, 19, 1e-9)
	Test.near(second.stop, 17, 1e-9)
end)

Test.test("items that do not fit into the queue overflow at the queue start", function()
	local belt = newBelt()
	local items = {}
	for id = 1, 4 do
		local item = BeltQueue.spawn(belt, id, 2, nil, 0)
		table.insert(items, item)
	end
	-- Queue zone is [14, 20]: three 2-stud items fit, the fourth overflows.
	Test.truthy(not items[3].overflow, "third fits")
	Test.truthy(items[4].overflow, "fourth overflows")
	Test.near(items[4].stop, 13, 1e-9)
	Test.equal(#BeltQueue.dueOverflows(belt, 0), 0)
	Test.equal(#BeltQueue.dueOverflows(belt, 100), 1)
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

Test.test("each item crosses a sorter once", function()
	local belt = newBelt()
	BeltQueue.spawn(belt, 1, 2, nil, 0)
	Test.equal(#BeltQueue.crossings(belt, 1, 1, 8), 0)
	Test.equal(#BeltQueue.crossings(belt, 4, 1, 8), 1)
	Test.equal(#BeltQueue.crossings(belt, 5, 1, 8), 0)
	Test.equal(#BeltQueue.crossings(belt, 5, 2, 8), 1)
end)

-- The balancing uses Economy.incomePerMinute; the real belts must deliver about the same.
local function compare(name: string, progress: Economy.Progress, manual: number)
	local model = Economy.incomePerMinute(progress, manual)
	local sim = BeltSim.run(progress, 20, manual, 12345)
	if model.machinesPerMinute > 0 then
		local ratio = sim.machinesPerMinute / model.machinesPerMinute
		Test.between(ratio, 0.88, 1.05, `{name}: machine income sim/model`)
	end
	local total = (sim.machinesPerMinute + sim.manualPerMinute) / model.totalPerMinute
	Test.between(total, 0.85, 1.1, `{name}: total income sim/model`)
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

Test.test("belt simulation matches the economy model when machines are saturated", function()
	local progress = Economy.newProgress()
	progress.upgrades = { beltSpeed = 25 }
	progress.purchases = { b1_sorter1 = true, b1_sorter2 = true, b1_sorter3 = true, spawner2 = true, spawner3 = true }
	compare("saturated", progress, 12)
end)

Test.test("a more valuable arrival evicts the cheapest queued package", function()
	local belt = newBelt()
	local cheap = BeltQueue.spawn(belt, 1, 2, { value = 1 }, 0)
	BeltQueue.spawn(belt, 2, 2, { value = 5 }, 0)
	BeltQueue.spawn(belt, 3, 2, { value = 5 }, 0)
	local valuable = BeltQueue.spawn(belt, 4, 2, { value = 9 }, 0)
	local worthless = BeltQueue.spawn(belt, 5, 2, { value = 0 }, 0)
	Test.truthy(valuable.overflow and worthless.overflow, "queue is full")
	local removed = BeltQueue.settleOverflows(belt, 100, function(item)
		return item.payload.value
	end)
	Test.equal(#removed, 2)
	Test.truthy(table.find(removed, cheap) ~= nil, "cheapest queued package evicted")
	Test.truthy(table.find(removed, worthless) ~= nil, "worthless arrival recycled")
	Test.truthy(not valuable.overflow, "valuable arrival took the free place")
	Test.equal(#belt.items, 3)
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
	Test.between(share, 0.05, 0.15, "rare bonus share of income")
end)
