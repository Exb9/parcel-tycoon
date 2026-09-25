--!strict
-- Daily quests window (Windows.Quests): three quests per day with progress, reward and Claim button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local QuestsWindow = {}

local WINDOW = "Quests"

local window: GuiObject? = nil

local function questText(def: Quests.QuestDef, quest: Quests.QuestState): string
	if def.kind == "earn" then
		return Text.get("quest.earn", { amount = Format.cash(quest.target) })
	end
	local args: { [string]: any } = { target = quest.target }
	if def.typeIndex then
		args.type = Names.packageType(def.typeIndex)
	end
	return Text.get(`quest.{def.kind}`, args)
end

local function render()
	local quests = State.quests()
	local cash = State.cash()
	if window == nil or quests == nil or not Windows.isOpen(WINDOW) then
		return
	end
	local income = if cash then cash.income else 0
	local byId: { [string]: Quests.QuestState } = {}
	local keys = {}
	for _, quest in quests.daily do
		byId[quest.id] = quest
		table.insert(keys, quest.id)
	end
	Ui.list(Ui.find(window, "List"), keys, function(item, questId)
		Ui.onActivated(Ui.button(item, "Claim"), function()
			Net.event(Net.ClaimQuest):FireServer(questId)
		end)
	end, function(item, questId)
		local quest = byId[questId]
		local def = Quests.def(questId)
		if def == nil then
			item.Visible = false
			return
		end
		local done = quest.progress >= quest.target
		local progressText = if def.kind == "earn"
			then `{Format.cash(quest.progress)}/{Format.cash(quest.target)}`
			else `{Format.number(quest.progress)}/{Format.number(quest.target)}`
		Ui.setText(item, "Title", questText(def, quest))
		Ui.setText(item, "Progress", if quest.claimed then Text.get("quests.claimed") else progressText)
		Ui.setFill(item, "Bar/Fill", if quest.target > 0 then quest.progress / quest.target else 1)
		Ui.setText(item, "Reward", Text.get("quests.reward", { amount = Format.cash(Quests.rewardCash(def, income)) }))
		Ui.setVisible(item, "Claim", done and not quest.claimed)
		Ui.setVisible(item, "Done", quest.claimed)
	end)
end

local function renderTimer()
	if Windows.isOpen(WINDOW) then
		local seconds = State.remaining("quests", "secondsToReset")
		Ui.setText(window, "ResetTimer", Text.get("quests.newIn", { time = Format.clock(seconds) }))
	end
end

function QuestsWindow.init()
	window = Windows.get(WINDOW)
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
			renderTimer()
		end
	end)
	State.watch({ "quests" }, render)
	Text.changed:Connect(render)
end

function QuestsWindow.start()
	while true do
		task.wait(1)
		renderTimer()
	end
end

return QuestsWindow
