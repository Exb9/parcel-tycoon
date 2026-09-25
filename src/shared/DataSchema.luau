--!strict
-- Saved player data: the template, the schema version and migrations between versions.
-- ProfileStore stores this table; keep it JSON-friendly (no Instances, no Vector3, no mixed tables).
--
-- Changing the shape of saved data:
--   1. bump VERSION,
--   2. add MIGRATIONS[VERSION] that upgrades data saved with VERSION - 1,
--   3. update the template (new fields with defaults are also filled in by ProfileStore's Reconcile),
--   4. add a case to tests/data.spec.luau.

local Economy = require("./Economy")

export type QuestState = {
	id: string,
	progress: number,
	target: number,
	claimed: boolean,
}

export type PlayerData = {
	schemaVersion: number,
	cash: number,
	-- Machine income waiting in the cash register.
	collector: number,
	progress: Economy.Progress,
	stats: {
		totalEarned: number,
		sortedManual: number,
		sortedMachine: number,
		sortedTotal: number,
		rareSorted: number,
		rebirths: number,
		playSeconds: number,
		robuxSpent: number,
	},
	-- os.time() of the last save while online (offline earnings).
	lastOnline: number,
	-- Login calendar: last UTC day index claimed and position in the 7-step calendar.
	daily: { lastClaimDay: number, step: number },
	-- Playtime gifts for the current UTC day.
	playtime: { day: number, seconds: number, claimed: { boolean } },
	quests: {
		day: number,
		daily: { QuestState },
		tutorialStep: number,
		tutorialProgress: number,
	},
	-- Cash boost end time (os.time()).
	boostUntil: number,
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	vip: { lastGiftDay: number },
	referrals: { day: number, rewardedToday: number, welcomed: boolean },
	-- Rebirth milestone rewards already given (by rebirth count as string key).
	milestones: { [string]: boolean },
	-- Recent developer product receipts, for idempotent ProcessReceipt handling.
	purchaseIds: { string },
}

local DataSchema = {}

DataSchema.VERSION = 1

function DataSchema.template(): PlayerData
	return {
		schemaVersion = DataSchema.VERSION,
		cash = 0,
		collector = 0,
		progress = Economy.newProgress(),
		stats = {
			totalEarned = 0,
			sortedManual = 0,
			sortedMachine = 0,
			sortedTotal = 0,
			rareSorted = 0,
			rebirths = 0,
			playSeconds = 0,
			robuxSpent = 0,
		},
		lastOnline = 0,
		daily = { lastClaimDay = -1, step = 0 },
		playtime = { day = -1, seconds = 0, claimed = { false, false, false, false } },
		quests = { day = -1, daily = {}, tutorialStep = 1, tutorialProgress = 0 },
		boostUntil = 0,
		cosmetics = { owned = {}, equipped = {} },
		vip = { lastGiftDay = -1 },
		referrals = { day = -1, rewardedToday = 0, welcomed = false },
		milestones = {},
		purchaseIds = {},
	}
end

-- MIGRATIONS[v] upgrades data saved with schema version v - 1 to version v.
local MIGRATIONS: { [number]: (data: any) -> () } = {
	-- v0 -> v1: data written before versioning existed; the reconcile step fills everything in.
	[1] = function(_data: any) end,
}

-- Fills missing fields from the template without touching existing values (like ProfileStore's
-- Reconcile, but usable in tests and for nested tables created later).
local function reconcile(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

-- Brings loaded data to the current schema version in place.
function DataSchema.migrate(data: any): PlayerData
	local version = if type(data.schemaVersion) == "number" then data.schemaVersion else 0
	for v = version + 1, DataSchema.VERSION do
		local migration = MIGRATIONS[v]
		assert(migration, `missing migration to schema version {v}`)
		migration(data)
		data.schemaVersion = v
	end
	reconcile(data, DataSchema.template())
	return data :: PlayerData
end

local function finiteOr(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

-- Repairs values that would break the game (NaN or negative cash, unknown zone, ...).
function DataSchema.sanitize(data: PlayerData)
	data.cash = math.max(0, finiteOr(data.cash, 0))
	data.collector = math.max(0, finiteOr(data.collector, 0))
	data.boostUntil = finiteOr(data.boostUntil, 0)
	data.lastOnline = finiteOr(data.lastOnline, 0)
	local progress = data.progress
	progress.rebirths = math.max(0, math.floor(finiteOr(progress.rebirths, 0)))
	local ok = pcall(Economy.getZone, progress.zone)
	if not ok then
		progress.zone = Economy.highestUnlockedZone(progress.rebirths)
	end
	for trackId, level in progress.upgrades do
		local track = Economy.findTrack(trackId)
		if track == nil then
			progress.upgrades[trackId] = nil
		else
			progress.upgrades[trackId] = math.clamp(math.floor(finiteOr(level, 0)), 0, track.maxLevel)
		end
	end
	for purchaseId in progress.purchases do
		if Economy.findPurchase(purchaseId) == nil then
			progress.purchases[purchaseId] = nil
		end
	end
end

return DataSchema
