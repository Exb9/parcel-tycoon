--!strict
-- Rebirth window (Windows.Rebirth): cost, the income bonus before and after, the Confirm button and the
-- rebirth milestone rewards. Cash, upgrades and machines reset; passes and styles stay
-- (EconomyService.rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local RebirthWindow = {}

local WINDOW = "Rebirth"

local window: GuiObject? = nil

local function multiplierText(value: number): string
	return (string.gsub(string.format("%.2f", value), "%.?0+$", ""))
end

local function render()
	local progress = State.progress()
	local cash = State.cash()
	if window == nil or progress == nil or cash == nil or not Windows.isOpen(WINDOW) then
		return
	end
	local cost = progress.rebirthCost
	Ui.setText(window, "Cost", Text.get("rebirth.cost", { amount = Format.cash(cost) }))
	Ui.setText(
		window,
		"Bonus",
		Text.get("rebirth.bonus", {
			from = multiplierText(Economy.rebirthMultiplier(progress.rebirths)),
			to = multiplierText(Economy.rebirthMultiplier(progress.rebirths + 1)),
		})
	)
	Ui.setFill(window, "Bar/Fill", if cost > 0 then cash.cash / cost else 1)

	-- Milestones: what each rebirth count unlocks, and which are done.
	local keys = {}
	local byKey: { [string]: typeof(Config.Rewards.rebirthMilestones[1]) } = {}
	for _, milestone in Config.Rewards.rebirthMilestones do
		local key = tostring(milestone.rebirths)
		table.insert(keys, key)
		byKey[key] = milestone
	end
	local claimed = progress.milestones or {}
	Ui.list(Ui.find(window, "Milestones"), keys, nil, function(item, key)
		local milestone = byKey[key]
		local parts = {}
		if milestone.cosmeticId then
			table.insert(parts, Names.cosmetic(milestone.cosmeticId))
		end
		local reward = milestone.reward
		if reward.kind == "boost" then
			table.insert(parts, Text.get("daily.boost", { minutes = reward.minutes or 0 }))
		else
			local grant = Rewards.resolve(reward, { incomePerMinute = cash.income })
			table.insert(parts, Format.cash(grant.cash))
		end
		Ui.setText(item, "Title", Text.get("milestone.title", { rebirths = milestone.rebirths }))
		Ui.setText(item, "Reward", table.concat(parts, " + "))
		Ui.setVisible(item, "Done", claimed[key] == true)
	end)
end

function RebirthWindow.init()
	window = Windows.get(WINDOW)
	Ui.onActivated(Ui.button(window, "Confirm"), function()
		Net.event(Net.Rebirth):FireServer()
		Windows.close()
	end)
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
		end
	end)
	State.watch({ "progress", "cash" }, render)
	Text.changed:Connect(render)
end

return RebirthWindow
