--!strict
-- Friends bonus: extra cash for every friend on the same server (Config.Rewards.friends). Playing
-- together is what brings new players in (invites, Creator Rewards audience growth).

local Events = require(script.Parent.Parent.Lib.Events)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local FriendsService = {
	priority = 85,
}

-- Friendship per pair of user ids ("small:large"), checked once per server.
local friendships: { [string]: boolean } = {}

local function pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

local function areFriends(a: Session, b: Session): boolean
	local key = pairKey(a.userId, b.userId)
	local known = friendships[key]
	if known ~= nil then
		return known
	end
	local ok, result = pcall(function()
		return a.player:IsFriendsWithAsync(b.userId)
	end)
	local friends = ok and result == true
	if ok then
		friendships[key] = friends
	end
	return friends
end

local function setFriends(session: Session, count: number)
	if session.friendsOnServer ~= count then
		session.friendsOnServer = count
		StateService.mark(session, "social")
		Events.bonusChanged:Fire(session)
	end
end

-- Recounts the friends of every player on the server.
local function recount()
	local sessions = Sessions.all()
	local counts: { [Session]: number } = {}
	for _, session in sessions do
		counts[session] = 0
	end
	for i = 1, #sessions do
		for j = i + 1, #sessions do
			local a, b = sessions[i], sessions[j]
			if areFriends(a, b) then
				counts[a] += 1
				counts[b] += 1
			end
		end
	end
	for session, count in counts do
		if not session.removed then
			setFriends(session, count)
		end
	end
end

function FriendsService.init()
	Sessions.added:Connect(function()
		task.spawn(recount)
	end)
	Sessions.removing:Connect(function()
		task.defer(recount)
	end)
end

-- For the Studio debug hook (friends can't be tested alone).
FriendsService.setFriends = setFriends

return FriendsService
