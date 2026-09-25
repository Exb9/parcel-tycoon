--!strict
-- HUD (PlayerGui.HUD, docs/UI_CONTRACT.md): cash, income, boost timer, carry hint, full cash register
-- and the menu buttons (bottom right, mobile first). The Invite button opens Roblox's friend invite
-- prompt; invites count for the referral reward (RewardService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Names = require(script.Parent.Parent.Lib.Names)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local Hud = {}

local MENU_WINDOWS = { "Shop", "Store", "Quests", "Daily", "Rebirth", "Style", "Info" }

local hud: ScreenGui? = nil

local function renderCash()
	local cash = State.cash()
	if cash == nil then
		return
	end
	local boosted = State.remaining("boost", "remaining") > 0
	local income = cash.income * (if boosted then Config.Economy.boostMultiplier else 1)
	Ui.setText(hud, "Cash", Format.cash(cash.cash))
	Ui.setText(hud, "Income", Text.get("hud.perMinute", { amount = Format.cash(income) }))
	Ui.setVisible(hud, "CollectorFull", not cash.autoCollect and cash.collector >= cash.collectorCapacity)
end

local function renderBoost()
	local remaining = State.remaining("boost", "remaining")
	Ui.setVisible(hud, "Boost", remaining > 0)
	if remaining > 0 then
		Ui.setText(hud, "Boost", Text.get("hud.boost", { time = Format.clock(remaining) }))
	end
end

local function renderCarry()
	local carrying = State.carrying()
	Ui.setVisible(hud, "CarryHint", carrying ~= nil)
	if carrying == nil then
		return
	end
	local hint = Text.get("hud.carry", { destination = Names.destination(carrying.typeId) })
	local rare = if carrying.rare ~= "" then Economy.findRare(carrying.rare) else nil
	if rare and rare.fragile then
		hint ..= "\n" .. Text.get("hud.carryFragile")
	end
	Ui.setText(hud, "CarryHint", hint)
end

local function renderBadges()
	local quests = State.quests()
	local questReady = false
	if quests then
		for _, quest in quests.daily do
			if not quest.claimed and quest.progress >= quest.target then
				questReady = true
			end
		end
	end
	local daily = State.daily()
	local cash = State.cash()
	local progress = State.progress()
	Ui.setVisible(hud, "Menu/Quests/Badge", questReady)
	Ui.setVisible(hud, "Menu/Daily/Badge", daily ~= nil and daily.canClaim)
	Ui.setVisible(hud, "Menu/Rebirth/Badge", cash ~= nil and progress ~= nil and cash.cash >= progress.rebirthCost)
end

local function setupInvite()
	local button = Ui.button(hud, "Menu/Invite")
	if button == nil then
		return
	end
	local player = Players.LocalPlayer
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	-- Studio cannot send invites; keep the button visible there so the layout can be tested.
	button.Visible = (ok and canInvite == true) or RunService:IsStudio()
	Ui.onActivated(button, function()
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end)
end

function Hud.init()
	hud = Ui.screen("HUD")
	for _, name in MENU_WINDOWS do
		Ui.onActivated(Ui.button(hud, `Menu/{name}`), function()
			Windows.toggle(name)
		end)
	end
	Ui.setVisible(hud, "Boost", false)
	Ui.setVisible(hud, "CarryHint", false)
	Ui.setVisible(hud, "CollectorFull", false)

	State.watch({ "cash" }, renderCash)
	State.watch({ "boost" }, renderBoost)
	State.watch({ "carrying" }, renderCarry)
	State.watch({ "quests", "daily", "cash", "progress" }, renderBadges)
	Text.changed:Connect(function()
		renderCash()
		renderCarry()
	end)
end

function Hud.start()
	task.spawn(setupInvite)
	-- The boost counts down locally; the server refreshes it every 30 seconds.
	local wasBoosted = false
	while true do
		task.wait(0.5)
		renderBoost()
		local boosted = State.remaining("boost", "remaining") > 0
		if boosted ~= wasBoosted then
			wasBoosted = boosted
			renderCash()
		end
	end
end

return Hud
