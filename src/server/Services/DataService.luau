--!strict
-- Loads and saves player data with ProfileStore (session locking, auto-save, migrations).
-- In Studio without "Enable Studio Access to API Services", ProfileStore uses a mock store, so
-- nothing is saved between test sessions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataSchema = require(ReplicatedStorage.Shared.DataSchema)
local Sessions = require(script.Parent.Parent.Lib.Sessions)

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local STORE_NAME = "PlayerData_v1"

local DataService = {
	priority = 10,
}

local store: any = nil
local loading: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	if loading[player] or Sessions.get(player) then
		return
	end
	loading[player] = true
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	loading[player] = nil

	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin!")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	local data = DataSchema.migrate(profile.Data)
	DataSchema.sanitize(data)

	profile.OnSessionEnd:Connect(function()
		Sessions.remove(player)
		if player.Parent == Players then
			player:Kick("Your data was opened on another server. Please rejoin!")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local session = Sessions.create(player, profile, data)
	Sessions.added:Fire(session)
end

local function onPlayerRemoving(player: Player)
	local session = Sessions.get(player)
	if session == nil then
		return
	end
	session.data.lastOnline = os.time()
	Sessions.remove(player)
	session.profile:EndSession()
end

function DataService.init()
	store = ProfileStore.New(STORE_NAME, DataSchema.template() :: any)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function DataService.start()
	-- Players who joined before the connection above (e.g. Play Solo in Studio).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

-- Sends a message to another player's profile; it is handled when their session is active
-- (Profile:MessageHandler). Yields.
function DataService.message(userId: number, message: { [string]: any }): boolean
	local ok, result = pcall(function()
		return store:MessageAsync(`Player_{userId}`, message)
	end)
	if not ok then
		warn(`[Data] Message to {userId} failed: {result}`)
	end
	return ok and result == true
end

-- Saves now if the profile is active (used before rare critical moments; ProfileStore also auto-saves).
function DataService.save(session: any)
	if session.profile:IsActive() then
		session.profile:Save()
	end
end

return DataService
