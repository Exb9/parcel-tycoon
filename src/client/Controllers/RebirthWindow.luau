--!strict
-- Rebirth window (Windows.Rebirth): cost, the income bonus before and after, and the Confirm button.
-- Cash, upgrades and machines reset; passes and styles stay (EconomyService.rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
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
