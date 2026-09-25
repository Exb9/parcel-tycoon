--!strict
-- Global leaderboards from the brief (money, rebirths, sorted packages) with OrderedDataStores.
-- The boards are built in Studio via the Studio MCP (docs/MAP_CONTRACT.md): the server only fills the
-- rows of Workspace.Lobby.Leaderboards.<boardId>.Board.Rows by cloning RowTemplate. Board titles are
-- localized by the client (TextKey "board.<id>").

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MapContract = require(ReplicatedStorage.Shared.MapContract)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session
type Board = typeof(Config.Leaderboards.boards[1])
type Entry = { userId: number, value: number }

local LeaderboardService = {
	priority = 90,
}

-- OrderedDataStore values are integers; stay in the range Luau numbers represent exactly.
local MAX_VALUE = 2 ^ 53 - 1
local ROW_ATTRIBUTE = "LeaderboardRow"

local settings = Config.Leaderboards
local stores: { [string]: OrderedDataStore } = {}
-- Last value written per user and board, so unchanged stats are not written again.
local written: { [number]: { [string]: number } } = {}
local names: { [number]: string } = {}
local warnedUnavailable = false

local function warnOnce(message: string)
	if not warnedUnavailable then
		warnedUnavailable = true
		warn(`[Leaderboards] {message} (in Studio: enable "Studio Access to API Services")`)
	end
end

local function statValue(session: Session, board: Board): number
	local value = (session.data.stats :: any)[board.stat]
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_VALUE)
end

local function writeStats(session: Session)
	local userId = session.userId
	local last = written[userId] or {}
	written[userId] = last
	for _, board in settings.boards do
		local value = statValue(session, board)
		if value > 0 and last[board.id] ~= value then
			local ok, err = pcall(function()
				stores[board.id]:SetAsync(tostring(userId), value)
			end)
			if ok then
				last[board.id] = value
			else
				warnOnce(`Could not write {board.id}: {err}`)
			end
		end
	end
end

-- Display names for the given users, cached; falls back to the user name.
local function resolveNames(userIds: { number })
	local missing = {}
	for _, userId in userIds do
		if names[userId] == nil then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, info in infos :: { any } do
			names[info.Id] = info.DisplayName
		end
	end
	for _, userId in missing do
		if names[userId] == nil then
			local found, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			names[userId] = if found then name else "?"
		end
	end
end

local function readBoard(board: Board): { Entry }?
	local ok, result = pcall(function()
		local pages = stores[board.id]:GetSortedAsync(false, settings.entries)
		return pages:GetCurrentPage()
	end)
	if not ok then
		warnOnce(`Could not read {board.id}: {result}`)
		return nil
	end
	local entries: { Entry } = {}
	for _, item in result :: { any } do
		local userId = tonumber(item.key)
		if userId and type(item.value) == "number" then
			table.insert(entries, { userId = userId, value = item.value })
		end
	end
	return entries
end

local function setText(row: Instance, name: string, text: string)
	local label = row:FindFirstChild(name, true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function render(board: Board, entries: { Entry })
	local lobby = Workspace:FindFirstChild(MapContract.LOBBY)
	local boards = lobby and lobby:FindFirstChild("Leaderboards")
	local part = boards and boards:FindFirstChild(board.id)
	local gui = part and part:FindFirstChild("Board")
	local rows = gui and gui:FindFirstChild("Rows", true)
	local template = rows and rows:FindFirstChild("RowTemplate")
	if rows == nil or template == nil or not template:IsA("GuiObject") then
		return
	end
	template.Visible = false
	for _, existing in rows:GetChildren() do
		if existing:GetAttribute(ROW_ATTRIBUTE) then
			existing:Destroy()
		end
	end
	for rank, entry in entries do
		local row = template:Clone()
		row.Name = `Row{rank}`
		row.LayoutOrder = rank
		row.Visible = true
		row:SetAttribute(ROW_ATTRIBUTE, true)
		setText(row, "Rank", `#{rank}`)
		setText(row, "PlayerName", names[entry.userId] or "?")
		setText(row, "Value", if board.format == "cash" then Format.cash(entry.value) else Format.number(entry.value))
		row.Parent = rows
	end
end

local function refreshAll()
	for _, board in settings.boards do
		local entries = readBoard(board)
		if entries then
			local userIds = {}
			for _, entry in entries do
				table.insert(userIds, entry.userId)
			end
			resolveNames(userIds)
			render(board, entries)
		end
	end
end

function LeaderboardService.init()
	for _, board in settings.boards do
		stores[board.id] = DataStoreService:GetOrderedDataStore(board.store)
	end
	Sessions.removing:Connect(function(session)
		task.spawn(function()
			writeStats(session)
			written[session.userId] = nil
		end)
	end)
end

function LeaderboardService.start()
	task.spawn(function()
		while true do
			refreshAll()
			task.wait(settings.refreshInterval)
		end
	end)
	while true do
		task.wait(settings.writeInterval)
		for _, session in Sessions.all() do
			writeStats(session)
		end
	end
end

return LeaderboardService
