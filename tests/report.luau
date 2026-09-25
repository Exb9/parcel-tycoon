--!strict
-- Prints the pacing report: `lune run tests/report` (from the repo root).

local BalanceSim = require("./BalanceSim")

local function minutes(second: number?): string
	return if second then string.format("%5.1f min", second / 60) else "      -  "
end

local milestones =
	{ "sorter1_letter", "spawner2", "sorter1_box", "sorter1_crate", "spawner3", "belt2", "sorter2_crate", "belt3" }

for rebirths = 0, 2 do
	local cycle = BalanceSim.runCycle({ rebirths = rebirths })
	print(`\n== Run {rebirths + 1} (rebirths so far: {rebirths}) ==`)
	print(`first purchase     {minutes(cycle.buys[1] and cycle.buys[1].second)}`)
	for _, id in milestones do
		print(`{string.format("%-18s", id)} {minutes(cycle.firstBought[id])}`)
	end
	print(`rebirth            {minutes(cycle.rebirthSecond)}`)
	for _, w in { { 0, 5 }, { 5, 15 }, { 15, 30 }, { 30, 60 }, { 60, 90 } } do
		local count, longest = BalanceSim.window(cycle, w[1], w[2])
		print(string.format("%3d-%3d min: %3d purchases, longest wait %4.1f min", w[1], w[2], count, longest))
	end
	for _, m in { 1, 5, 15, 30, 45, 60 } do
		local value = cycle.incomeByMinute[m + 1]
		if value then
			print(string.format("income at %2d min: %9.0f / min", m, value))
		end
	end
end
