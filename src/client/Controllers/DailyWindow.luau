--!strict
-- Daily rewards window (Windows.Daily): the 7-day calendar from Config.Rewards.daily, one claim per UTC day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local DailyWindow = {}

local WINDOW = "Daily"

local window: GuiObject? = nil

local function rewardText(reward: Rewards.Reward, income: number): string
	if reward.kind == "boost" then
		return Text.get("daily.boost", { minutes = reward.minutes or 0 })
	end
	local grant = Rewards.resolve(reward, { incomePerMinute = income })
	return Format.cash(grant.cash)
end

local function render()
	local daily = State.daily()
	local cash = State.cash()
	if window == nil or daily == nil or not Windows.isOpen(WINDOW) then
		return
	end
	local income = if cash then cash.income else 0
	-- A finished week starts over with the next claim.
	local newWeek = daily.canClaim and daily.nextStep == 1
	for day, reward in Config.Rewards.daily do
		local path = `Days/Day{day}`
		Ui.setText(window, `{path}/Title`, Text.get("daily.day", { day = day }))
		Ui.setText(window, `{path}/Reward`, rewardText(reward, income))
		Ui.setVisible(window, `{path}/Claimed`, not newWeek and day <= daily.step)
		Ui.setVisible(window, `{path}/Next`, daily.canClaim and day == daily.nextStep)
	end
	Ui.setVisible(window, "Claim", daily.canClaim)
	Ui.setVisible(window, "Status", not daily.canClaim)
	if not daily.canClaim then
		local seconds = State.remaining("daily", "secondsToReset")
		Ui.setText(window, "Status", `{Text.get("daily.comeBack")} ({Format.clock(seconds)})`)
	end
end

function DailyWindow.init()
	window = Windows.get(WINDOW)
	Ui.onActivated(Ui.button(window, "Claim"), function()
		Net.event(Net.ClaimDaily):FireServer()
	end)
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
		end
	end)
	State.watch({ "daily" }, render)
	Text.changed:Connect(render)
end

function DailyWindow.start()
	while true do
		task.wait(1)
		render()
	end
end

return DailyWindow
