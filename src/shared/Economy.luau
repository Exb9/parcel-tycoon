--!strict
-- Pure economy formulas shared by server, client (shop previews) and the Lune balance tests.
-- No Roblox APIs in here.

local Config = require("./Config")
local PackageTypesConfig = require("./Config/PackageTypes")
local PurchasesConfig = require("./Config/Purchases")
local UpgradesConfig = require("./Config/Upgrades")
local ZonesConfig = require("./Config/Zones")

export type PackageType = PackageTypesConfig.PackageType
export type RareVariant = PackageTypesConfig.RareVariant
export type Purchase = PurchasesConfig.Purchase
export type UpgradeTrack = UpgradesConfig.UpgradeTrack
export type Zone = ZonesConfig.Zone

-- The part of a player's saved data that drives income. Reset by rebirths (except keepOnRebirth tracks).
export type Progress = {
	zone: string,
	rebirths: number,
	upgrades: { [string]: number },
	purchases: { [string]: boolean },
}

-- Owned gamepasses by key (Config.Monetization.gamepasses).
export type Passes = { [string]: boolean }

export type IncomeBreakdown = {
	machinesPerMinute: number,
	manualPerMinute: number,
	totalPerMinute: number,
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

local zonesById: { [string]: Zone } = {}
for _, zone in Config.Zones.zones do
	zonesById[zone.id] = zone
end

local raresById: { [string]: RareVariant } = {}
for _, rare in Config.PackageTypes.rareVariants do
	raresById[rare.id] = rare
end

local typesByZone: { [string]: { PackageType } } = {}
for _, packageType in Config.PackageTypes.types do
	local list = typesByZone[packageType.zone]
	if not list then
		list = {}
		typesByZone[packageType.zone] = list
	end
	table.insert(list, packageType)
end
for _, list in typesByZone do
	table.sort(list, function(a, b)
		return a.index < b.index
	end)
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

function Economy.findTrack(trackId: string): UpgradeTrack?
	return tracksById[trackId]
end

function Economy.getPurchase(purchaseId: string): Purchase
	local purchase = purchasesById[purchaseId]
	assert(purchase, `unknown purchase '{purchaseId}'`)
	return purchase
end

function Economy.findPurchase(purchaseId: string): Purchase?
	return purchasesById[purchaseId]
end

function Economy.getZone(zoneId: string): Zone
	local zone = zonesById[zoneId]
	assert(zone, `unknown zone '{zoneId}'`)
	return zone
end

function Economy.findRare(rareId: string): RareVariant?
	return raresById[rareId]
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

-- Whether a one-off purchase can be bought now: not owned, prerequisite owned, required pass owned.
function Economy.isPurchaseAvailable(progress: Progress, purchaseId: string, passes: Passes?): boolean
	local purchase = Economy.getPurchase(purchaseId)
	if Economy.owns(progress, purchaseId) then
		return false
	end
	if purchase.requiresPass and not (passes and passes[purchase.requiresPass]) then
		return false
	end
	return purchase.requires == nil or Economy.owns(progress, purchase.requires)
end

-- Belt indices in use: belt 1 always, others once bought.
function Economy.activeBelts(progress: Progress): { number }
	local belts = { 1 }
	for _, purchase in Config.Purchases.purchases do
		if purchase.kind == "belt" and purchase.belt and Economy.owns(progress, purchase.id) then
			table.insert(belts, purchase.belt)
		end
	end
	table.sort(belts)
	return belts
end

function Economy.spawnerCount(progress: Progress): number
	local count = 1
	for _, purchase in Config.Purchases.purchases do
		if purchase.kind == "spawner" and Economy.owns(progress, purchase.id) then
			count += 1
		end
	end
	return count
end

function Economy.hasSorter(progress: Progress, belt: number, typeIndex: number): boolean
	for _, purchase in Config.Purchases.purchases do
		if
			purchase.kind == "sorter"
			and purchase.belt == belt
			and purchase.typeIndex == typeIndex
			and Economy.owns(progress, purchase.id)
		then
			return true
		end
	end
	return false
end

-- First sorter purchase that is available right now (for the "Instant Machine" product).
function Economy.nextSorterPurchase(progress: Progress, passes: Passes?): Purchase?
	for _, purchase in Config.Purchases.purchases do
		if purchase.kind == "sorter" and Economy.isPurchaseAvailable(progress, purchase.id, passes) then
			return purchase
		end
	end
	return nil
end

function Economy.packageTypesForZone(zoneId: string): { PackageType }
	return typesByZone[zoneId] or {}
end

function Economy.packageTypeAt(zoneId: string, typeIndex: number): PackageType?
	for _, packageType in Economy.packageTypesForZone(zoneId) do
		if packageType.index == typeIndex then
			return packageType
		end
	end
	return nil
end

-- Highest available zone the given rebirth count unlocks.
function Economy.highestUnlockedZone(rebirths: number): string
	local best = Config.Zones.startingZone
	local bestOrder = Economy.getZone(best).order
	for _, zone in Config.Zones.zones do
		local unlocked = zone.unlock == nil or rebirths >= zone.unlock.rebirths
		if zone.available and unlocked and zone.order > bestOrder then
			best, bestOrder = zone.id, zone.order
		end
	end
	return best
end

-- Packages per minute arriving on one belt (all types together).
function Economy.supplyPerBelt(progress: Progress, passes: Passes?): number
	local passBonus = if passes and passes.fastBelts then Config.Monetization.fastBeltsMultiplier else 1
	return Config.Economy.spawnsPerMinute
		* Economy.spawnerCount(progress)
		* Economy.multiplier(progress, "beltSpeed")
		* passBonus
end

-- Visual belt speed in studs per second.
function Economy.beltSpeed(progress: Progress, passes: Passes?): number
	local belt = Config.Gameplay.belt
	local passBonus = if passes and passes.fastBelts then Config.Monetization.fastBeltsMultiplier else 1
	return math.min(belt.maxSpeed, belt.baseSpeed * Economy.multiplier(progress, "beltSpeed") * passBonus)
end

-- Packages per minute one sorting machine handles.
function Economy.sorterRate(progress: Progress): number
	return Config.Economy.sorterBaseRate * Economy.multiplier(progress, "sorterSpeed")
end

-- Share of machine-sorted packages that earn cash.
function Economy.sorterAccuracy(progress: Progress): number
	local track = Economy.getTrack("sorterAccuracy")
	return math.min(
		1,
		Config.Economy.sorterBaseAccuracy + track.effectPerLevel * Economy.level(progress, "sorterAccuracy")
	)
end

function Economy.rebirthMultiplier(rebirths: number): number
	return 1 + Config.Economy.rebirth.incomeBonusPerRebirth * rebirths
end

function Economy.rebirthCost(rebirths: number): number
	local rebirth = Config.Economy.rebirth
	return roundCost(rebirth.baseCost * rebirth.costGrowth ^ rebirths)
end

-- Cash for one correctly sorted package, before pass/boost multipliers and rare bonuses.
function Economy.packageValue(progress: Progress, packageType: PackageType): number
	return packageType.baseValue
		* Economy.multiplier(progress, "packageValue")
		* Economy.rebirthMultiplier(progress.rebirths)
end

-- Multiplier on every cash gain from sorting: passes and the active boost.
function Economy.cashMultiplier(passes: Passes?, boostActive: boolean): number
	local multiplier = 1
	if passes and passes.doubleCash then
		multiplier *= Config.Monetization.doubleCashMultiplier
	end
	if passes and passes.vip then
		multiplier *= 1 + Config.Monetization.vipCashBonus
	end
	if boostActive then
		multiplier *= Config.Economy.boostMultiplier
	end
	return multiplier
end

-- Steady-state income estimate before cash multipliers. Machines take what they can (and earn only
-- their accuracy share); the manual rate goes to the most valuable leftovers.
-- Used for offline earnings, progress-scaled rewards and cash packs, and the balance simulation.
function Economy.incomePerMinute(progress: Progress, manualSortsPerMinute: number?, passes: Passes?): IncomeBreakdown
	local supply = Economy.supplyPerBelt(progress, passes)
	local sorterRate = Economy.sorterRate(progress)
	local accuracy = Economy.sorterAccuracy(progress)
	local packageTypes = Economy.packageTypesForZone(progress.zone)

	local totalWeight = 0
	for _, packageType in packageTypes do
		totalWeight += packageType.spawnWeight
	end
	if totalWeight <= 0 then
		return { machinesPerMinute = 0, manualPerMinute = 0, totalPerMinute = 0 }
	end

	local machines = 0
	local leftovers: { { value: number, amount: number } } = {}
	for _, belt in Economy.activeBelts(progress) do
		for _, packageType in packageTypes do
			local value = Economy.packageValue(progress, packageType)
			local arriving = supply * packageType.spawnWeight / totalWeight
			local automated = if Economy.hasSorter(progress, belt, packageType.index)
				then math.min(arriving, sorterRate)
				else 0
			machines += automated * value * accuracy
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

-- Income estimate used for progress-scaled rewards: typical manual rate, passes, no boost.
function Economy.estimatedIncome(progress: Progress, passes: Passes?): number
	local income = Economy.incomePerMinute(progress, Config.Economy.manualSortsPerMinute, passes)
	return income.totalPerMinute * Economy.cashMultiplier(passes, false)
end

-- Machine cash the collector holds before machines pause.
function Economy.collectorCapacity(progress: Progress, passes: Passes?): number
	local collector = Config.Economy.collector
	local minutes = collector.capacityMinutes
		+ Economy.getTrack("collectorCapacity").effectPerLevel * Economy.level(progress, "collectorCapacity")
	local machines = Economy.incomePerMinute(progress, 0, passes).machinesPerMinute
		* Economy.cashMultiplier(passes, false)
	return math.max(collector.minimumCapacity, math.floor(machines * minutes))
end

function Economy.offlineCapHours(progress: Progress): number
	local offline = Config.Economy.offline
	return offline.baseCapHours + Economy.getTrack("offlineCap").effectPerLevel * Economy.level(progress, "offlineCap")
end

-- Cash earned while away, from machines only, capped. Passes apply, boosts do not.
function Economy.offlineEarnings(progress: Progress, secondsAway: number, passes: Passes?): number
	local offline = Config.Economy.offline
	if secondsAway < offline.minimumSeconds then
		return 0
	end
	local cappedMinutes = math.min(secondsAway, Economy.offlineCapHours(progress) * 3600) / 60
	local machines = Economy.incomePerMinute(progress, 0, passes).machinesPerMinute
	return math.floor(machines * Economy.cashMultiplier(passes, false) * offline.efficiency * cappedMinutes)
end

-- Cash granted by a progress-scaled reward or cash pack.
function Economy.cashPackAmount(incomePerMinute: number, incomeMinutes: number, minimumCash: number): number
	return math.max(minimumCash, math.floor(incomePerMinute * incomeMinutes))
end

-- Progress after a rebirth: cash-bought things reset, keepOnRebirth upgrades stay, the warehouse moves
-- to the highest unlocked zone.
function Economy.rebirth(progress: Progress): Progress
	local rebirths = progress.rebirths + 1
	local upgrades: { [string]: number } = {}
	for trackId, level in progress.upgrades do
		local track = Economy.findTrack(trackId)
		if track and track.keepOnRebirth then
			upgrades[trackId] = level
		end
	end
	return {
		zone = Economy.highestUnlockedZone(rebirths),
		rebirths = rebirths,
		upgrades = upgrades,
		purchases = {},
	}
end

return Economy
