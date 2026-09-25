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

-- The part of a player's saved data that drives income. A rebirth resets it (except rebirths/zone).
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
local rareShare = 0
for _, rare in Config.PackageTypes.rareVariants do
	raresById[rare.id] = rare
	rareShare += rare.chance
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

-- Share of spawned packages that are rare (sum of the fixed chances).
function Economy.rareShare(): number
	return rareShare
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

-- Packages per minute the chutes put on one belt (all types together) while there is room.
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

-- Multiplier on every cash gain from sorting: the 2x Cash pass, the active boost and the additive
-- bonuses (friends, group, club; 0.1 = +10 %).
function Economy.cashMultiplier(passes: Passes?, boostActive: boolean, bonus: number?): number
	local multiplier = 1 + math.max(0, bonus or 0)
	if passes and passes.doubleCash then
		multiplier *= Config.Monetization.doubleCashMultiplier
	end
	if boostActive then
		multiplier *= Config.Economy.boostMultiplier
	end
	return multiplier
end

-- Additive cash bonus from playing with friends, the group and the club subscription.
function Economy.cashBonus(friendsOnServer: number, inGroup: boolean, clubMember: boolean): number
	local rewards = Config.Rewards
	local friends = math.min(rewards.friends.maxBonus, math.max(0, friendsOnServer) * rewards.friends.bonusPerFriend)
	local group = if inGroup and rewards.group.groupId ~= 0 then rewards.group.cashBonus else 0
	local club = if clubMember then Config.Monetization.club.cashBonus else 0
	return friends + group + club
end

type Segment = { manual: number, machines: number, hand: number }

-- Pieces of one belt's intake curve. The chute pauses while the belt is full, so a belt only takes in
-- what is removed: machines remove their type up to their rate, everything else (other types, machine
-- overflow, rare packages) has to be sorted by hand. Taking in A packages per minute therefore needs
-- manual capacity L(A); L is piecewise linear, so the curve is a list of segments, each with the manual
-- capacity it needs and the machine / hand income it adds.
local function beltSegments(progress: Progress, beltIndex: number, supply: number): { Segment }
	local packageTypes = Economy.packageTypesForZone(progress.zone)
	local totalWeight = 0
	for _, packageType in packageTypes do
		totalWeight += packageType.spawnWeight
	end
	if totalWeight <= 0 or supply <= 0 then
		return {}
	end
	local sorterRate = Economy.sorterRate(progress)
	local accuracy = Economy.sorterAccuracy(progress)

	local shares = {}
	local averageValue = 0
	for _, packageType in packageTypes do
		local weight = packageType.spawnWeight / totalWeight
		local value = Economy.packageValue(progress, packageType)
		averageValue += weight * value
		table.insert(shares, {
			share = (1 - rareShare) * weight,
			value = value,
			rate = if Economy.hasSorter(progress, beltIndex, packageType.index) then sorterRate else 0,
		})
	end

	local points = { 0, supply }
	for _, entry in shares do
		if entry.rate > 0 and entry.share > 0 then
			local saturation = entry.rate / entry.share
			if saturation < supply then
				table.insert(points, saturation)
			end
		end
	end
	table.sort(points)

	local segments = {}
	for i = 1, #points - 1 do
		local a0, a1 = points[i], points[i + 1]
		local width = a1 - a0
		if width > 1e-9 then
			local middle = (a0 + a1) / 2
			-- Rare packages are always sorted by hand; counted at an average value (their bonus is extra).
			local manualSlope = rareShare
			local handSlope = rareShare * averageValue
			local machineSlope = 0
			for _, entry in shares do
				if entry.rate > 0 and entry.share * middle < entry.rate then
					machineSlope += entry.share * entry.value * accuracy
				else
					manualSlope += entry.share
					handSlope += entry.share * entry.value
				end
			end
			table.insert(segments, {
				manual = manualSlope * width,
				machines = machineSlope * width,
				hand = handSlope * width,
			})
		end
	end
	return segments
end

-- Steady-state income before cash multipliers. The player's manual rate goes where it earns the most:
-- each belt's intake grows segment by segment, and the next piece of manual capacity always goes to the
-- belt whose next segment pays the most per manual sort. Used for offline earnings, progress-scaled
-- rewards and cash packs, and the balance simulation.
function Economy.incomePerMinute(progress: Progress, manualSortsPerMinute: number?, passes: Passes?): IncomeBreakdown
	local supply = Economy.supplyPerBelt(progress, passes)
	local curves: { { Segment } } = {}
	for _, beltIndex in Economy.activeBelts(progress) do
		table.insert(curves, beltSegments(progress, beltIndex, supply))
	end

	local cursor: { number } = {}
	for index in curves do
		cursor[index] = 1
	end
	local remaining = manualSortsPerMinute or 0
	local machines, hand = 0, 0
	while remaining > 1e-12 do
		local bestIndex: number? = nil
		local bestScore = -1
		for index, segments in curves do
			local segment = segments[cursor[index]]
			if segment then
				local score = if segment.manual > 1e-12
					then (segment.machines + segment.hand) / segment.manual
					else math.huge
				if score > bestScore then
					bestIndex, bestScore = index, score
				end
			end
		end
		if bestIndex == nil then
			break
		end
		local segment = curves[bestIndex][cursor[bestIndex]]
		if segment.manual <= remaining then
			remaining -= segment.manual
			machines += segment.machines
			hand += segment.hand
			cursor[bestIndex] += 1
		else
			local fraction = remaining / segment.manual
			machines += segment.machines * fraction
			hand += segment.hand * fraction
			remaining = 0
		end
	end

	return {
		machinesPerMinute = machines,
		manualPerMinute = hand,
		totalPerMinute = machines + hand,
	}
end

-- Income estimate used for progress-scaled rewards: typical manual rate, passes, no boost.
function Economy.estimatedIncome(progress: Progress, passes: Passes?): number
	local income = Economy.incomePerMinute(progress, Config.Economy.manualSortsPerMinute, passes)
	return income.totalPerMinute * Economy.cashMultiplier(passes, false)
end

-- Machine income per minute while the player plays normally (typical manual rate), with passes.
function Economy.machineIncome(progress: Progress, passes: Passes?): number
	local income = Economy.incomePerMinute(progress, Config.Economy.manualSortsPerMinute, passes)
	return income.machinesPerMinute * Economy.cashMultiplier(passes, false)
end

-- Machine cash the cash register holds before machines pause.
function Economy.collectorCapacity(progress: Progress, passes: Passes?): number
	local collector = Config.Economy.collector
	local minutes = collector.capacityMinutes
		+ Economy.getTrack("collectorCapacity").effectPerLevel * Economy.level(progress, "collectorCapacity")
	return math.max(collector.minimumCapacity, math.floor(Economy.machineIncome(progress, passes) * minutes))
end

function Economy.offlineCapHours(progress: Progress): number
	local offline = Config.Economy.offline
	return offline.baseCapHours + Economy.getTrack("offlineCap").effectPerLevel * Economy.level(progress, "offlineCap")
end

-- Cash earned while away: a share of the machine income, capped. Passes apply, boosts do not.
function Economy.offlineEarnings(progress: Progress, secondsAway: number, passes: Passes?): number
	if secondsAway <= 0 then
		return 0
	end
	local cappedMinutes = math.min(secondsAway, Economy.offlineCapHours(progress) * 3600) / 60
	return math.floor(Economy.machineIncome(progress, passes) * Config.Economy.offline.efficiency * cappedMinutes)
end

-- Cash granted by a progress-scaled reward or cash pack.
function Economy.cashPackAmount(incomePerMinute: number, incomeMinutes: number, minimumCash: number): number
	return math.max(minimumCash, math.floor(incomePerMinute * incomeMinutes))
end

-- Progress after a rebirth: money and machines reset (all upgrades and purchases), rebirths + 1.
function Economy.rebirth(progress: Progress): Progress
	return {
		zone = progress.zone,
		rebirths = progress.rebirths + 1,
		upgrades = {},
		purchases = {},
	}
end

return Economy
