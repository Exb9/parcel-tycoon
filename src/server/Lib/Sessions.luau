--!strict
-- Registry of loaded players. A session exists from "data loaded" until "player leaving".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(script.Parent.Types)

type Session = Types.Session

local Sessions = {}

local byPlayer: { [Player]: Session } = {}

-- Fired once the player's data is loaded and the session is registered.
Sessions.added = Signal.new() :: Signal.Signal<Session>
-- Fired when the player leaves, before the data is saved and released.
Sessions.removing = Signal.new() :: Signal.Signal<Session>

function Sessions.create(player: Player, profile: any, data: any): Session
	local session: Session = {
		player = player,
		userId = player.UserId,
		profile = profile,
		data = data,
		passes = {},
		plot = nil,
		carrying = nil,
		lastGrab = 0,
		lastWrongNotice = 0,
		joinedAt = os.clock(),
		dirty = {},
		removed = false,
	}
	byPlayer[player] = session
	return session
end

function Sessions.get(player: Player): Session?
	local session = byPlayer[player]
	if session and not session.removed then
		return session
	end
	return nil
end

function Sessions.all(): { Session }
	local list = {}
	for _, session in byPlayer do
		if not session.removed then
			table.insert(list, session)
		end
	end
	return list
end

-- Unregisters the session and fires `removing`. Safe to call twice.
function Sessions.remove(player: Player): Session?
	local session = byPlayer[player]
	if session == nil or session.removed then
		return nil
	end
	Sessions.removing:Fire(session)
	session.removed = true
	byPlayer[player] = nil
	return session
end

return Sessions
