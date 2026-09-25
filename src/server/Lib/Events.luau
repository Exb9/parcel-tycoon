--!strict
-- Gameplay events other services react to (quests, stats, visuals).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(script.Parent.Types)

type Session = Types.Session
type Signal<T...> = Signal.Signal<T...>

export type SortInfo = {
	-- true = sorted by hand, false = by a machine.
	manual: boolean,
	typeIndex: number,
	rare: string?,
	-- Cash paid (0 for machine mistakes).
	value: number,
}

return {
	packageGrabbed = Signal.new() :: Signal<Session>,
	packageSorted = Signal.new() :: Signal<Session, SortInfo>,
	-- (session, amount, source) source: "sort" | "machine" | "collect" | "reward" | "offline" | "purchase"
	cashEarned = Signal.new() :: Signal<Session, number, string>,
	upgradeBought = Signal.new() :: Signal<Session, string>,
	purchaseBought = Signal.new() :: Signal<Session, string>,
	collected = Signal.new() :: Signal<Session, number>,
	rebirthed = Signal.new() :: Signal<Session>,
	-- Upgrades, purchases or zone changed: rates, belts and visible machines need a refresh.
	progressChanged = Signal.new() :: Signal<Session>,
	passesChanged = Signal.new() :: Signal<Session>,
	cosmeticsChanged = Signal.new() :: Signal<Session>,
	-- The player's plot was (re)built and belts can start.
	plotReady = Signal.new() :: Signal<Session>,
	-- The cash register just became full (machines pause).
	collectorFull = Signal.new() :: Signal<Session>,
	-- Friends, group or club changed the cash bonus.
	bonusChanged = Signal.new() :: Signal<Session>,
}
