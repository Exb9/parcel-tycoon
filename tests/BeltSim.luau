--!strict
-- Time-stepped simulation of a whole plot with the real belt model (BeltQueue), package rolls, sorter
-- token buckets and a player who sorts by hand at a fixed rate. Used to check that the analytic
-- Economy.incomePerMinute (which the balancing relies on) matches what the belts actually produce.

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
	recycledPerMinute: number,
	spawnedPerMinute: number,
}

type Sorter = { position: number, typeIndex: number, tokens: number }

local BeltSim = {}

-- Layout of the placeholder map (tools/map/MapBuilder.luau): 48-stud belts, sorters at 12/20/28.
BeltSim.BELT_LENGTH = 48
BeltSim.SORTER_POSITIONS = { 12, 20, 28 }

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
				beltConfig.queueLength,
				beltConfig.gap,
				Economy.beltSpeed(progress),
				beltConfig.maxPackages
			),
			credit = 0,
			sorters = sorters,
		})
	end

	local nextId = 0
	local machines, manual, rareBonus, recycled, spawned = 0, 0, 0, 0, 0
	local manualCredit = 0

	local function valueOf(item: BeltQueue.Item): number
		local packageType = Economy.packageTypeAt(progress.zone, item.payload.typeIndex)
		assert(packageType, "unknown type index")
		return Economy.packageValue(progress, packageType)
	end

	-- What a player (and the queue eviction) considers a package worth: rare ones count their bonus.
	-- Mystery rewards average roughly 8.5 package values (Config.Rewards.mystery).
	local function rareMultiplier(item: BeltQueue.Item): number
		local rare = item.payload.rare and Economy.findRare(item.payload.rare)
		if not rare then
			return 1
		end
		return if rare.id == "mystery" then 8.5 else rare.valueMultiplier
	end
	local function worth(item: BeltQueue.Item): number
		return valueOf(item) * rareMultiplier(item)
	end

	local steps = math.floor(minutes * 60 / dt)
	for _ = 1, steps do
		now += dt
		for _, belt in belts do
			-- Spawning
			belt.credit = math.min(belt.credit + supply / 60 * dt, 1.5)
			if belt.credit >= 1 then
				local roll = PackageRoll.roll(progress.zone, random)
				local packageType = Economy.packageTypeAt(progress.zone, roll.typeIndex)
				assert(packageType, "unknown type index")
				if BeltQueue.canSpawn(belt.queue, packageType.size.z, now) then
					nextId += 1
					BeltQueue.spawn(belt.queue, nextId, packageType.size.z, roll, now)
					belt.credit -= 1
					spawned += 1
				end
			end

			-- Sorting machines
			for index, sorter in belt.sorters do
				sorter.tokens = math.min(beltConfig.sorterBuffer, sorter.tokens + sorterRate / 60 * dt)
				for _, item in BeltQueue.crossings(belt.queue, now, index, sorter.position) do
					if
						item.payload.typeIndex == sorter.typeIndex
						and item.payload.rare == nil
						and sorter.tokens >= 1
					then
						sorter.tokens -= 1
						machines += valueOf(item) * accuracy
						BeltQueue.remove(belt.queue, item, now)
					end
				end
			end

			-- Recycling bin (valuable arrivals push cheaper queued packages out)
			local removed = BeltQueue.settleOverflows(belt.queue, now, worth)
			recycled += #removed
		end

		-- The player takes the most valuable queued package at a steady rate.
		manualCredit = math.min(manualCredit + manualPerMinute / 60 * dt, 1)
		if manualCredit >= 1 then
			local best: BeltQueue.Item? = nil
			local bestBelt = nil
			for _, belt in belts do
				for _, item in BeltQueue.queued(belt.queue, now) do
					if best == nil or worth(item) > worth(best) then
						best, bestBelt = item, belt
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
		recycledPerMinute = recycled / minutes,
		spawnedPerMinute = spawned / minutes,
	}
end

return BeltSim
