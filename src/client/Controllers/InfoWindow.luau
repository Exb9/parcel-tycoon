--!strict
-- Info window (Windows.Info): how to play (static texts with TextKey) and the odds of the mystery
-- package bonus (decision: chances are shown although mystery packages are found, not bought).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local InfoWindow = {}

local WINDOW = "Info"

local window: GuiObject? = nil

local function render()
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

function InfoWindow.init()
	window = Windows.get(WINDOW)
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
		end
	end)
	Text.changed:Connect(function()
		if Windows.isOpen(WINDOW) then
			render()
		end
	end)
end

return InfoWindow
