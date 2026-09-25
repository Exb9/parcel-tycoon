--!strict
-- Tutorial chain and daily quests (pure logic; QuestService applies it to player data).

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
	purchaseId: string?,
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

function Quests.dailyDef(questId: string): QuestDef?
	return dailyById[questId]
end

-- The current tutorial quest, or nil once the tutorial is done.
function Quests.tutorialDef(data: QuestData): QuestDef?
	return Config.Quests.tutorial[data.tutorialStep]
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
		local index = Rng.int(rng, 1, #pool)
		local def = table.remove(pool, index)
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
	if def.purchaseId ~= nil and def.purchaseId ~= event.purchaseId then
		return false
	end
	return true
end

-- Events feed several quest kinds: a manual sort also counts for "sortType" and "sortRare" quests
-- through separate events sent by the caller.
export type EventResult = {
	-- The tutorial step that was completed by this event (its reward is due), if any.
	tutorialCompleted: QuestDef?,
	-- Daily quests that just reached their target.
	dailyCompleted: { string },
}

function Quests.applyEvent(data: QuestData, event: QuestEvent): EventResult
	local result: EventResult = { tutorialCompleted = nil, dailyCompleted = {} }

	local tutorial = Quests.tutorialDef(data)
	if tutorial and matches(tutorial, event) then
		data.tutorialProgress += event.amount
		if data.tutorialProgress >= (tutorial.target or 1) then
			result.tutorialCompleted = tutorial
			data.tutorialStep += 1
			data.tutorialProgress = 0
		end
	end

	for _, quest in data.daily do
		local def = dailyById[quest.id]
		if def and not quest.claimed and quest.progress < quest.target and matches(def, event) then
			quest.progress = math.min(quest.target, quest.progress + event.amount)
			if quest.progress >= quest.target then
				table.insert(result.dailyCompleted, quest.id)
			end
		end
	end

	return result
end

-- Claims a finished daily quest. Returns the cash reward, or nil if it cannot be claimed.
function Quests.claimDaily(data: QuestData, questId: string, incomePerMinute: number): number?
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

function Quests.rewardCash(def: QuestDef, incomePerMinute: number): number
	if def.rewardCash then
		return def.rewardCash
	end
	local minutes = def.rewardIncomeMinutes or 0
	return math.max(def.rewardMinimumCash or 0, math.floor(incomePerMinute * minutes))
end

return Quests
