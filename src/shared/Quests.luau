--!strict
-- Daily quests (pure logic; QuestService applies it to player data).

local Config = require("./Config")
local DataSchema = require("./DataSchema")
local QuestsConfig = require("./Config/Quests")
local Rng = require("./Rng")

export type QuestDef = QuestsConfig.QuestDef
export type QuestKind = QuestsConfig.QuestKind
export type QuestState = DataSchema.QuestState
export type QuestData = typeof(DataSchema.template().quests)

export type QuestEvent = {
	kind: QuestKind,
	amount: number,
	typeIndex: number?,
}

export type EventResult = {
	-- Any quest progress changed.
	changed: boolean,
	-- Daily quests that just reached their target.
	completed: { string },
}

local Quests = {}

local SECONDS_PER_DAY = 86400

local dailyById: { [string]: QuestDef } = {}
for _, def in Config.Quests.dailyPool do
	dailyById[def.id] = def
end

-- UTC day number for an os.time() timestamp.
function Quests.dayIndex(unixTime: number): number
	return math.floor(unixTime / SECONDS_PER_DAY)
end

function Quests.def(questId: string): QuestDef?
	return dailyById[questId]
end

local function targetFor(def: QuestDef, incomePerMinute: number): number
	if def.targetIncomeMinutes then
		return math.max(Config.Quests.minimumEarnTarget, math.floor(incomePerMinute * def.targetIncomeMinutes))
	end
	return def.target or 1
end

-- Draws the daily quests for a player and day. Deterministic: the same player gets the same quests
-- on every server that day.
function Quests.drawDaily(day: number, userId: number, incomePerMinute: number): { QuestState }
	local rng = Rng.new(day * 7919 + userId)
	local pool = table.clone(Config.Quests.dailyPool)
	local quests: { QuestState } = {}
	for _ = 1, math.min(Config.Quests.dailyCount, #pool) do
		local def = table.remove(pool, Rng.int(rng, 1, #pool))
		assert(def, "daily pool index out of range")
		table.insert(quests, {
			id = def.id,
			progress = 0,
			target = targetFor(def, incomePerMinute),
			claimed = false,
		})
	end
	return quests
end

-- Re-draws the daily quests when a new UTC day started. Returns true if they changed.
function Quests.ensureDay(data: QuestData, day: number, userId: number, incomePerMinute: number): boolean
	if data.day == day then
		return false
	end
	data.day = day
	data.daily = Quests.drawDaily(day, userId, incomePerMinute)
	return true
end

local function matches(def: QuestDef, event: QuestEvent): boolean
	if def.kind ~= event.kind then
		return false
	end
	if def.typeIndex ~= nil and def.typeIndex ~= event.typeIndex then
		return false
	end
	return true
end

function Quests.applyEvent(data: QuestData, event: QuestEvent): EventResult
	local result: EventResult = { changed = false, completed = {} }
	for _, quest in data.daily do
		local def = dailyById[quest.id]
		if def and not quest.claimed and quest.progress < quest.target and matches(def, event) then
			result.changed = true
			quest.progress = math.min(quest.target, quest.progress + event.amount)
			if quest.progress >= quest.target then
				table.insert(result.completed, quest.id)
			end
		end
	end
	return result
end

function Quests.rewardCash(def: QuestDef, incomePerMinute: number): number
	return math.max(def.rewardMinimumCash, math.floor(incomePerMinute * def.rewardIncomeMinutes))
end

-- Claims a finished daily quest. Returns the cash reward, or nil if it cannot be claimed.
function Quests.claim(data: QuestData, questId: string, incomePerMinute: number): number?
	for _, quest in data.daily do
		if quest.id == questId then
			local def = dailyById[questId]
			if def == nil or quest.claimed or quest.progress < quest.target then
				return nil
			end
			quest.claimed = true
			return Quests.rewardCash(def, incomePerMinute)
		end
	end
	return nil
end

return Quests
