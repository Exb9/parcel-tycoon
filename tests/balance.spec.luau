--!strict
-- Pacing targets from docs/BALANCING.md. If a config change breaks one, either retune the config
-- or consciously change the target here and in the doc.

local BalanceSim = require("./BalanceSim")
local Test = require("./Test")

local firstRun = BalanceSim.runCycle()

local function minutesOf(second: number?): number
	assert(second, "milestone never reached")
	return second / 60
end

Test.test("first purchase within 30 seconds", function()
	Test.between(firstRun.buys[1].second, 0, 30)
end)

Test.test("first sorting machine after 2-6 minutes", function()
	Test.between(minutesOf(firstRun.firstBought.b1_sorter1), 2, 6)
end)

Test.test("steady purchases early on", function()
	local count = BalanceSim.window(firstRun, 0, 5)
	Test.truthy(count >= 12, `only {count} purchases in the first 5 minutes`)
	local _, longest = BalanceSim.window(firstRun, 0, 15)
	Test.between(longest, 0, 3, "longest wait in the first 15 minutes")
end)

Test.test("first belt fully automated after 15-30 minutes", function()
	Test.between(minutesOf(firstRun.firstBought.b1_sorter3), 15, 30)
end)

Test.test("second belt after 35-55 minutes", function()
	Test.between(minutesOf(firstRun.firstBought.belt2), 35, 55)
end)

Test.test("rebirth cycles 1-6 take 45-75 minutes (zone 2 from rebirth 3)", function()
	for rebirths = 0, 5 do
		local cycle = if rebirths == 0 then firstRun else BalanceSim.runCycle({ rebirths = rebirths })
		Test.between(minutesOf(cycle.rebirthSecond), 45, 75, `rebirth cycle {rebirths + 1}`)
	end
end)
