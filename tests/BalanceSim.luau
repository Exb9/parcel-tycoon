--!strict
-- Greedy free-player simulation (no passes, no rare packages) used to check pacing targets.
-- The player always buys the affordable option with the best income gain per cash and waits for it
-- otherwise. They stop buying and save for the rebirth once it costs at most `rebirthWithinMinutes`
-- of income (the rebirth bar is "almost full"), or once the next useful purchase is more than
-- `savingThresholdMinutes` of income away (the upper end of one-off pricing).

local Config = require("../src/shared/Config")
local Economy = require("../src/shared/Economy")

export type Options = {
	rebirths: number?,
	passes: Economy.Passes?,
	manualSortsPerMinute: number?,
	savingThresholdMinutes: number?,
	rebirthWithinMinutes: number?,
	maxMinutes: number?,
}

export type Buy = { second: number, id: string, cost: number }

export type Cycle = {
	buys: { Buy },
	firstBought: { [string]: number },
	-- Income per minute sampled at the start of every minute (index 1 = minute 0).
	incomeByMinute: { number },
	rebirthSecond: number?,
}

local BalanceSim = {}

type Option = { kind: "track" | "purchase", id: string, cost: number }

local function options(progress: Economy.Progress, passes: Economy.Passes?): { Option }
	local result: { Option } = {}
	for _, track in Config.Upgrades.tracks do
		local cost = Economy.upgradeCost(track.id, Economy.level(progress, track.id))
		if cost then
			table.insert(result, { kind = "track", id = track.id, cost = cost })
		end
	end
	for _, purchase in Config.Purchases.purchases do
		if Economy.isPurchaseAvailable(progress, purchase.id, passes) then
			table.insert(result, { kind = "purchase", id = purchase.id, cost = purchase.cost })
		end
	end
	return result
end

local function apply(progress: Economy.Progress, option: Option, delta: number)
	if option.kind == "track" then
		progress.upgrades[option.id] = Economy.level(progress, option.id) + delta
	else
		progress.purchases[option.id] = if delta > 0 then true else nil
	end
end

local function income(progress: Economy.Progress, manual: number, passes: Economy.Passes?): number
	return Economy.incomePerMinute(progress, manual, passes).totalPerMinute * Economy.cashMultiplier(passes, false)
end

-- Best income gain per cash among all options that raise income.
local function bestOption(progress: Economy.Progress, manual: number, passes: Economy.Passes?): Option?
	local base = income(progress, manual, passes)
	local best: Option? = nil
	local bestScore = 0
	for _, option in options(progress, passes) do
		apply(progress, option, 1)
		local gain = income(progress, manual, passes) - base
		apply(progress, option, -1)
		local score = gain / option.cost
		if gain > 0 and score > bestScore then
			best, bestScore = option, score
		end
	end
	return best
end

function BalanceSim.runCycle(opts: Options?): Cycle
	local o: Options = opts or {}
	local manual = o.manualSortsPerMinute or Config.Economy.manualSortsPerMinute
	local threshold = (o.savingThresholdMinutes or 8) * 60
	local rebirthWithin = (o.rebirthWithinMinutes or 15) * 60
	local maxSeconds = (o.maxMinutes or 180) * 60

	local passes = o.passes
	local progress = Economy.newProgress()
	progress.rebirths = o.rebirths or 0
	progress.zone = Economy.highestUnlockedZone(progress.rebirths)
	local rebirthCost = Economy.rebirthCost(progress.rebirths)

	local cycle: Cycle = { buys = {}, firstBought = {}, incomeByMinute = {}, rebirthSecond = nil }
	local cash = Config.Economy.startingCash
	local saving = false

	for second = 1, maxSeconds do
		local perMinute = income(progress, manual, passes)
		if second % 60 == 1 then
			table.insert(cycle.incomeByMinute, perMinute)
		end
		cash += perMinute / 60

		if cash >= rebirthCost then
			cycle.rebirthSecond = second
			break
		end
		if not saving and (rebirthCost - cash) / (perMinute / 60) <= rebirthWithin then
			saving = true
		end

		while not saving do
			local option = bestOption(progress, manual, passes)
			if not option then
				saving = true
				break
			end
			if cash < option.cost then
				-- Too far away: a real player would rather save up for the rebirth.
				saving = (option.cost - cash) / (income(progress, manual, passes) / 60) > threshold
				break
			end
			cash -= option.cost
			apply(progress, option, 1)
			table.insert(cycle.buys, { second = second, id = option.id, cost = option.cost })
			if cycle.firstBought[option.id] == nil then
				cycle.firstBought[option.id] = second
			end
		end
	end

	return cycle
end

-- Purchases made in [fromMinute, toMinute) and the longest gap between purchases in that window.
function BalanceSim.window(cycle: Cycle, fromMinute: number, toMinute: number): (number, number)
	local count = 0
	local last = fromMinute * 60
	local longest = 0
	for _, buy in cycle.buys do
		if buy.second >= fromMinute * 60 and buy.second < toMinute * 60 then
			count += 1
			longest = math.max(longest, buy.second - last)
			last = buy.second
		end
	end
	return count, longest / 60
end

return BalanceSim
