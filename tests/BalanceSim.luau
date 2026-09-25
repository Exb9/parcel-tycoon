--!strict
-- Purchase-optimizing free-player simulation (no passes, no rare bonus) used to check pacing targets.
--
-- With the paused chute a single purchase can be worth nothing on its own (a second chute on a belt
-- that is already as full as the player can clear) while two together pay off (a machine plus a chute).
-- The player therefore plans two purchases ahead: they pick the single purchase or pair with the best
-- income gain per cash, buy its first step when affordable and wait for it otherwise.
-- They stop buying and save for the rebirth once it costs at most `rebirthWithinMinutes` of income
-- (the rebirth bar is "almost full"), or once the next useful step is more than
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
		local level = Economy.level(progress, option.id) + delta
		progress.upgrades[option.id] = if level > 0 then level else nil
	else
		progress.purchases[option.id] = if delta > 0 then true else nil
	end
end

local function income(progress: Economy.Progress, manual: number, passes: Economy.Passes?): number
	return Economy.incomePerMinute(progress, manual, passes).totalPerMinute * Economy.cashMultiplier(passes, false)
end

-- One-off purchases unlocked by this one, in unlock order (a new belt and its machines).
local function chainAfter(purchaseId: string, passes: Economy.Passes?): { Option }
	local chain: { Option } = {}
	local current = purchaseId
	while true do
		local nextPurchase = nil
		for _, purchase in Config.Purchases.purchases do
			if
				purchase.requires == current
				and (purchase.requiresPass == nil or (passes and passes[purchase.requiresPass]))
			then
				nextPurchase = purchase
				break
			end
		end
		if nextPurchase == nil or #chain >= 3 then
			return chain
		end
		table.insert(chain, { kind = "purchase", id = nextPurchase.id, cost = nextPurchase.cost })
		current = nextPurchase.id
	end
end

-- Next purchase of the best plan (income gain per cash), or nil. Plans: a single step, any two steps,
-- and a one-off followed by the purchases it unlocks (e.g. a belt with its machines).
local function bestStep(progress: Economy.Progress, manual: number, passes: Economy.Passes?): Option?
	local base = income(progress, manual, passes)
	local best: Option? = nil
	local bestScore = 0
	local function consider(first: Option, gain: number, cost: number)
		if gain > 0 and gain / cost > bestScore then
			best, bestScore = first, gain / cost
		end
	end
	for _, first in options(progress, passes) do
		apply(progress, first, 1)
		consider(first, income(progress, manual, passes) - base, first.cost)
		for _, second in options(progress, passes) do
			apply(progress, second, 1)
			consider(first, income(progress, manual, passes) - base, first.cost + second.cost)
			apply(progress, second, -1)
		end
		if first.kind == "purchase" then
			local cost = first.cost
			local chain = chainAfter(first.id, passes)
			for index, step in chain do
				apply(progress, step, 1)
				cost += step.cost
				if index >= 2 then
					consider(first, income(progress, manual, passes) - base, cost)
				end
			end
			for index = #chain, 1, -1 do
				apply(progress, chain[index], -1)
			end
		end
		apply(progress, first, -1)
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
	local rebirthCost = Economy.rebirthCost(progress.rebirths)

	local cycle: Cycle = { buys = {}, firstBought = {}, incomeByMinute = {}, rebirthSecond = nil }
	local cash = Config.Economy.startingCash
	local saving = false
	local perMinute = income(progress, manual, passes)
	local plan = bestStep(progress, manual, passes)

	for second = 1, maxSeconds do
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
			local step = plan
			if step == nil then
				saving = true
				break
			end
			if cash < step.cost then
				-- Too far away: a real player would rather save up for the rebirth.
				saving = perMinute <= 0 or (step.cost - cash) / (perMinute / 60) > threshold
				break
			end
			cash -= step.cost
			apply(progress, step, 1)
			table.insert(cycle.buys, { second = second, id = step.id, cost = step.cost })
			if cycle.firstBought[step.id] == nil then
				cycle.firstBought[step.id] = second
			end
			perMinute = income(progress, manual, passes)
			plan = bestStep(progress, manual, passes)
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
