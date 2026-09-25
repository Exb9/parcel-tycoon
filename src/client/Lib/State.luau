--!strict
-- The local player's state as the server sends it (StateService). Read-only on the client: controllers
-- render it and send intents; the server decides everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Shared.DataSchema)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

export type Cash = {
	cash: number,
	collector: number,
	collectorCapacity: number,
	income: number,
	multiplier: number,
	autoCollect: boolean,
}

export type Progress = {
	zone: string,
	rebirths: number,
	upgrades: { [string]: number },
	purchases: { [string]: boolean },
	rebirthCost: number,
}

export type Quests = { day: number, daily: { DataSchema.QuestState }, secondsToReset: number }
export type Daily = { canClaim: boolean, step: number, nextStep: number, secondsToReset: number }
export type Cosmetics = { owned: { [string]: boolean }, equipped: { [string]: string } }
export type Carrying = { typeIndex: number, typeId: string, rare: string }

local State = {}

-- Section name -> latest value (shapes: see StateService.build).
local sections: { [string]: any } = {}
-- os.clock() when each section arrived, for countdowns.
local receivedAt: { [string]: number } = {}

-- Fires with the section name after it changed.
State.changed = Signal.new() :: Signal.Signal<string>

function State.get(section: string): any
	return sections[section]
end

function State.cash(): Cash?
	return sections.cash
end

function State.progress(): Progress?
	return sections.progress
end

function State.passes(): { [string]: boolean }
	return sections.passes or {}
end

function State.quests(): Quests?
	return sections.quests
end

function State.daily(): Daily?
	return sections.daily
end

function State.cosmetics(): Cosmetics?
	return sections.cosmetics
end

function State.carrying(): Carrying?
	local carrying = sections.carrying
	return if type(carrying) == "table" then carrying else nil
end

-- Seconds left on a countdown field of a section, counted down since it arrived.
function State.remaining(section: string, field: string): number
	local value = sections[section]
	local seconds = type(value) == "table" and value[field]
	if type(seconds) ~= "number" then
		return 0
	end
	return math.max(0, seconds - (os.clock() - (receivedAt[section] or os.clock())))
end

-- Calls `render` once all `watched` sections have arrived, and again whenever one of them changes.
function State.watch(watched: { string }, render: () -> ())
	local function ready(): boolean
		for _, section in watched do
			if sections[section] == nil then
				return false
			end
		end
		return true
	end
	State.changed:Connect(function(section)
		if table.find(watched, section) and ready() then
			render()
		end
	end)
	if ready() then
		render()
	end
end

function State.start()
	Net.event(Net.State).OnClientEvent:Connect(function(patch: any)
		if type(patch) ~= "table" then
			return
		end
		local now = os.clock()
		for section, value in patch do
			sections[section] = value
			receivedAt[section] = now
		end
		for section in patch do
			State.changed:Fire(section)
		end
	end)
	-- The first full state may have been sent before this script was listening.
	Net.event(Net.RequestState):FireServer()
end

return State
