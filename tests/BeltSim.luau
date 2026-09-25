--!strict
-- Time-stepped simulation of a whole plot with the real belt model (BeltQueue), package rolls, sorter
-- token buckets and a player who sorts by hand at a fixed rate. Used to check that the analytic
-- Economy.incomePerMinute (which the balancing relies on) matches what the belts actually produce,
-- including jams: the chute pauses while a belt is full.

local BeltQueue = require("../src/shared/BeltQueue")
local Config = require("../src/shared/Config")
local Economy = require("../src/shared/Economy")
local PackageRoll = require("../src/shared/PackageRoll")
local Rng = require("../src/shared/Rng")

export type Result = {
	machinesPerMinute: number,
	-- Manual income counting rare packages at their normal value (comparable to the economy model) ...
	manualPerMinute: number,
	-- ... and the extra cash rare packages add on top.
	rareBonusPerMinute: number,
	spawnedPerMinute: number,
}

type Sorter = { position: number, typeIndex: number, tokens: number }

local BeltSim = {}

-- Reference layout from docs/MAP_CONTRACT.md: 48-stud belts, sorters 12/20/28 studs along, the player
-- picks packages from the last 14 studs.
BeltSim.BELT_LENGTH = 48
BeltSim.SORTER_POSITIONS = { 12, 20, 28 }
BeltSim.PICK_ZONE = 14

function BeltSim.run(progress: Economy.Progress, minutes: number, manualPerMinute: number, seed: number): Result
	local beltConfig = Config.Gameplay.belt
	local rng = Rng.new(seed)
	local random = function()
		return Rng.next(rng)
	end

	local now = 0
	local dt = 0.05
	local supply = Economy.supplyPerBelt(progress)
	local sorterRate = Economy.sorterRate(progress)
	local accuracy = Economy.sorterAccuracy(progress)

	local belts = {}
	for _, beltIndex in Economy.activeBelts(progress) do
		local sorters: { Sorter } = {}
		for typeIndex, position in BeltSim.SORTER_POSITIONS do
			if Economy.hasSorter(progress, beltIndex, typeIndex) then
				table.insert(sorters, { position = position, typeIndex = typeIndex, tokens = beltConfig.sorterBuffer })
			end
		end
		table.insert(belts, {
			queue = BeltQueue.new(
				BeltSim.BELT_LENGTH,
				beltConfig.gap,
				Economy.beltSpeed(progress),
				beltConfig.maxPackages
			),
			credit = 0,
			nextRoll = nil :: PackageRoll.Roll?,
			-- The chute wanted to drop a package but the belt was full.
			paused = false,
			sorters = sorters,
		})
	end

	local nextId = 0
	local machines, manual, rareBonus, spawned = 0, 0, 0, 0
	local manualCredit = 0

	local function valueOf(item: BeltQueue.Item): number
		local packageType = Economy.packageTypeAt(progress.zone, item.payload.typeIndex)
		assert(packageType, "unknown type index")
		return Economy.packageValue(progress, packageType)
	end

	-- What a player considers a package worth: rare ones count their bonus.
	-- Mystery bonuses average roughly 8 package values (Config.Rewards.mystery).
	local function worth(item: BeltQueue.Item): number
		local rare = item.payload.rare and Economy.findRare(item.payload.rare)
		if not rare then
			return valueOf(item)
		end
		local bonus = if rare.bonusReward then 8 else 0
		return valueOf(item) * (rare.valueMultiplier + bonus)
	end

	local steps = math.floor(minutes * 60 / dt)
	for _ = 1, steps do
		now += dt
		for _, belt in belts do
			-- Spawning (the chute pauses while there is no room at the start)
			belt.credit = math.min(belt.credit + supply / 60 * dt, 1.5)
			belt.paused = false
			if belt.credit >= 1 then
				local roll = belt.nextRoll or PackageRoll.roll(progress.zone, random)
				belt.nextRoll = roll
				local packageType = Economy.packageTypeAt(progress.zone, roll.typeIndex)
				assert(packageType, "unknown type index")
				if BeltQueue.canSpawn(belt.queue, packageType.size.z, now) then
					nextId += 1
					BeltQueue.spawn(belt.queue, nextId, packageType.size.z, roll, now)
					belt.credit -= 1
					belt.nextRoll = nil
					spawned += 1
				else
					belt.paused = true
				end
			end

			-- Sorting machines take matching packages that pass or wait in front of them.
			for _, sorter in belt.sorters do
				sorter.tokens = math.min(beltConfig.sorterBuffer, sorter.tokens + sorterRate / 60 * dt)
				if sorter.tokens >= 1 then
					local reach = beltConfig.sorterReach
					for _, item in BeltQueue.inRange(belt.queue, now, sorter.position - reach, sorter.position + reach) do
						if item.payload.typeIndex == sorter.typeIndex and item.payload.rare == nil then
							sorter.tokens -= 1
							machines += valueOf(item) * accuracy
							BeltQueue.remove(belt.queue, item, now)
							break
						end
					end
				end
			end
		end

		-- The player sorts at a steady rate. A belt whose chute is paused and that has machines comes first
		-- (its front package, so the line moves and the machines keep working); otherwise the player takes
		-- the most valuable package from the end of any belt.
		manualCredit = math.min(manualCredit + manualPerMinute / 60 * dt, 1)
		if manualCredit >= 1 then
			local best: BeltQueue.Item? = nil
			local bestBelt = nil
			for _, belt in belts do
				local front = belt.queue.items[1]
				local atEnd = front ~= nil
					and BeltQueue.distanceAt(front, now) >= BeltSim.BELT_LENGTH - BeltSim.PICK_ZONE
				if belt.paused and #belt.sorters > 0 and atEnd then
					best, bestBelt = front, belt
					break
				end
			end
			if best == nil then
				for _, belt in belts do
					for _, item in BeltQueue.itemsFrom(belt.queue, now, BeltSim.BELT_LENGTH - BeltSim.PICK_ZONE) do
						if best == nil or worth(item) > worth(best) then
							best, bestBelt = item, belt
						end
					end
				end
			end
			if best and bestBelt then
				manualCredit -= 1
				manual += valueOf(best)
				rareBonus += worth(best) - valueOf(best)
				BeltQueue.remove(bestBelt.queue, best, now)
			end
		end
	end

	return {
		machinesPerMinute = machines / minutes,
		manualPerMinute = manual / minutes,
		rareBonusPerMinute = rareBonus / minutes,
		spawnedPerMinute = spawned / minutes,
	}
end

return BeltSim
