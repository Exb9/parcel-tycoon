--!strict
-- Pure economy formulas shared by server, client (shop previews) and the Lune balance tests.
-- No Roblox APIs in here.

local Config = require("./Config")

type PackageType = typeof(Config.PackageTypes.types[1])
type UpgradeTrack = typeof(Config.Upgrades.tracks[1])
type Purchase = typeof(Config.Purchases.purchases[1])

-- The part of a player's saved data that drives income.
export type Progress = {
	zone: string,
	rebirths: number,
	upgrades: { [string]: number },
	purchases: { [string]: boolean },
}

local Economy = {}

local tracksById: { [string]: UpgradeTrack } = {}
for _, track in Config.Upgrades.tracks do
	tracksById[track.id] = track
end

local purchasesById: { [string]: Purchase } = {}
for _, purchase in Config.Purchases.purchases do
	purchasesById[purchase.id] = purchase
end

local function roundCost(cost: number): number
	return math.floor(cost + 0.5)
end

function Economy.newProgress(): Progress
	return {
		zone = Config.Zones.startingZone,
		rebirths = 0,
		upgrades = {},
		purchases = {},
	}
end

function Economy.getTrack(trackId: string): UpgradeTrack
	local track = tracksById[trackId]
	assert(track, `unknown upgrade track '{trackId}'`)
	return track
end

function Economy.getPurchase(purchaseId: string): Purchase
	local purchase = purchasesById[purchaseId]
	assert(purchase, `unknown purchase '{purchaseId}'`)
	return purchase
end

function Economy.level(progress: Progress, trackId: string): number
	return progress.upgrades[trackId] or 0
end

-- Cost of the next level, or nil when the track is maxed.
function Economy.upgradeCost(trackId: string, currentLevel: number): number?
	local track = Economy.getTrack(trackId)
	if currentLevel >= track.maxLevel then
		return nil
	end
	return roundCost(track.baseCost * track.growth ^ currentLevel)
end

-- Linear effect multiplier of a track: 1 + effectPerLevel * level.
function Economy.multiplier(progress: Progress, trackId: string): number
	return 1 + Economy.getTrack(trackId).effectPerLevel * Economy.level(progress, trackId)
end

function Economy.owns(progress: Progress, purchaseId: string): boolean
	return progress.purchases[purchaseId] == true
end

-- Whether a one-off purchase is visible/buyable (not owned and its prerequisite is owned).
function Economy.isPurchaseAvailable(progress: Progress, purchaseId: string): boolean
	local purchase = Economy.getPurchase(purchaseId)
	if Economy.owns(progress, purchaseId) then
		return false
	end
	return purchase.requires == nil or Economy.owns(progress, purchase.requires)
end

local function countOwned(progress: Progress, kind: string): number
	local count = 0
	for _, purchase in Config.Purchases.purchases do
		if purchase.kind == kind and Economy.owns(progress, purchase.id) then
			count += 1
		end
	end
	return count
end

function Economy.beltCount(progress: Progress): number
	return 1 + countOwned(progress, "belt")
end

function Economy.spawnerCount(progress: Progress): number
	return 1 + countOwned(progress, "spawner")
end

function Economy.hasSorter(progress: Progress, belt: number, packageTypeId: string): boolean
	for _, purchase in Config.Purchases.purchases do
		if
			purchase.kind == "sorter"
			and purchase.belt == belt
			and purchase.packageType == packageTypeId
			and Economy.owns(progress, purchase.id)
		then
			return true
		end
	end
	return false
end

function Economy.packageTypesForZone(zoneId: string): { PackageType }
	local result = {}
	for _, packageType in Config.PackageTypes.types do
		if packageType.zone == zoneId then
			table.insert(result, packageType)
		end
	end
	return result
end

-- Packages per minute arriving on one belt (all types together).
function Economy.supplyPerBelt(progress: Progress, beltSpeedBonus: number?): number
	return Config.Economy.spawnsPerMinute
		* Economy.spawnerCount(progress)
		* Economy.multiplier(progress, "beltSpeed")
		* (beltSpeedBonus or 1)
end

-- Packages per minute one sorting machine handles.
function Economy.sorterRate(progress: Progress): number
	return Config.Economy.sorterBaseRate * Economy.multiplier(progress, "sorterSpeed")
end

function Economy.rebirthMultiplier(rebirths: number): number
	return 1 + Config.Economy.rebirth.incomeBonusPerRebirth * rebirths
end

function Economy.rebirthCost(rebirths: number): number
	local rebirth = Config.Economy.rebirth
	return roundCost(rebirth.baseCost * rebirth.costGrowth ^ rebirths)
end

-- Cash for one correctly sorted package, before pass/boost multipliers.
function Economy.packageValue(progress: Progress, packageType: PackageType): number
	return packageType.baseValue
		* Economy.multiplier(progress, "packageValue")
		* Economy.rebirthMultiplier(progress.rebirths)
end

export type IncomeBreakdown = {
	machinesPerMinute: number,
	manualPerMinute: number,
	totalPerMinute: number,
}

-- Steady-state income estimate. Machines take what they can; the manual rate goes to the most
-- valuable leftovers. Used for offline earnings, progress-scaled cash packs and the balance simulation.
function Economy.incomePerMinute(progress: Progress, manualSortsPerMinute: number?): IncomeBreakdown
	local supply = Economy.supplyPerBelt(progress)
	local sorterRate = Economy.sorterRate(progress)
	local packageTypes = Economy.packageTypesForZone(progress.zone)

	local totalWeight = 0
	for _, packageType in packageTypes do
		totalWeight += packageType.spawnWeight
	end

	local machines = 0
	local leftovers: { { value: number, amount: number } } = {}
	for belt = 1, Economy.beltCount(progress) do
		for _, packageType in packageTypes do
			local value = Economy.packageValue(progress, packageType)
			local arriving = supply * packageType.spawnWeight / totalWeight
			local automated = if Economy.hasSorter(progress, belt, packageType.id)
				then math.min(arriving, sorterRate)
				else 0
			machines += automated * value
			table.insert(leftovers, { value = value, amount = arriving - automated })
		end
	end

	table.sort(leftovers, function(a, b)
		return a.value > b.value
	end)
	local manualLeft = manualSortsPerMinute or 0
	local manual = 0
	for _, leftover in leftovers do
		local taken = math.min(leftover.amount, manualLeft)
		manual += taken * leftover.value
		manualLeft -= taken
	end

	return {
		machinesPerMinute = machines,
		manualPerMinute = manual,
		totalPerMinute = machines + manual,
	}
end

function Economy.offlineCapHours(progress: Progress): number
	local offline = Config.Economy.offline
	return offline.baseCapHours + Economy.getTrack("offlineCap").effectPerLevel * Economy.level(progress, "offlineCap")
end

-- Cash earned while away, from machines only, capped.
function Economy.offlineEarnings(progress: Progress, secondsAway: number): number
	local cappedMinutes = math.min(math.max(secondsAway, 0), Economy.offlineCapHours(progress) * 3600) / 60
	local machines = Economy.incomePerMinute(progress).machinesPerMinute
	return math.floor(machines * Config.Economy.offline.efficiency * cappedMinutes)
end

-- Cash granted by a progress-scaled cash pack.
function Economy.cashPackAmount(incomePerMinute: number, incomeMinutes: number, minimumCash: number): number
	return math.max(minimumCash, math.floor(incomePerMinute * incomeMinutes))
end

return Economy
