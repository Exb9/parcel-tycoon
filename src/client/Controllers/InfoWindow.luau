--!strict
-- Info window (Windows.Info): how to play (static texts with TextKey), the odds of the mystery package
-- bonus (decision: chances are shown although mystery packages are found, not bought) and the Roblox
-- group panel (join in game via GroupService:PromptJoinAsync, the server checks and pays the bonus).

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local InfoWindow = {}

local WINDOW = "Info"

local window: GuiObject? = nil

local function renderOdds()
	local odds = Rewards.mysteryOdds()
	local byId: { [string]: number } = {}
	local keys = {}
	for _, entry in odds do
		byId[entry.id] = entry.percent
		table.insert(keys, entry.id)
	end
	Ui.list(Ui.find(window, "Odds"), keys, nil, function(item, rewardId)
		Ui.setText(item, "Title", Text.get(`reward.{rewardId}`))
		Ui.setText(item, "Chance", Format.percent(byId[rewardId] / 100))
	end)
end

local function renderGroup()
	local social = State.get("social")
	local enabled = type(social) == "table" and social.groupEnabled == true
	Ui.setVisible(window, "Group", enabled)
	if not enabled then
		return
	end
	local bonus = Format.percent(Config.Rewards.group.cashBonus)
	local member = social.inGroup == true
	Ui.setText(window, "Group/Status", Text.get(if member then "group.member" else "group.desc", { bonus = bonus }))
	Ui.setVisible(window, "Group/Join", not member)
end

local function joinGroup()
	local groupId = Config.Rewards.group.groupId
	if groupId == 0 then
		return
	end
	local ok, status = pcall(function()
		return GroupService:PromptJoinAsync(groupId)
	end)
	if ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember) then
		Net.event(Net.CheckGroup):FireServer()
	end
end

local function render()
	if window == nil or not Windows.isOpen(WINDOW) then
		return
	end
	renderOdds()
	renderGroup()
end

function InfoWindow.init()
	window = Windows.get(WINDOW)
	Ui.onActivated(Ui.button(window, "Group/Join"), function()
		task.spawn(joinGroup)
	end)
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
		end
	end)
	State.watch({ "social" }, render)
	Text.changed:Connect(render)
end

return InfoWindow
