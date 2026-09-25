--!strict
-- HUD (PlayerGui.HUD, docs/UI_CONTRACT.md): cash, income, boost and Auto Collect timers, bonus, carry
-- hint, full cash register, tutorial hint, playtime gift, the 2x Cash video ad button and the menu
-- buttons (bottom right, mobile first). The Invite button opens Roblox's friend invite prompt; invites
-- count for the referral reward (RewardService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local AdsClient = require(script.Parent.Parent.Lib.AdsClient)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local Hud = {}

local MENU_WINDOWS = { "Shop", "Store", "Quests", "Daily", "Rebirth", "Style", "Codes", "Info" }
local BOOST_AD = "boost"

local hud: ScreenGui? = nil

local function renderCash()
	local cash = State.cash()
	if cash == nil then
		return
	end
	local boosted = State.remaining("boost", "remaining") > 0
	local bonus = if type(cash.bonus) == "number" then cash.bonus else 0
	local income = cash.income * (1 + bonus) * (if boosted then Config.Economy.boostMultiplier else 1)
	Ui.setText(hud, "Cash", Format.cash(cash.cash))
	Ui.setText(hud, "Income", Text.get("hud.perMinute", { amount = Format.cash(income) }))
	Ui.setVisible(hud, "CollectorFull", not cash.autoCollect and cash.collector >= cash.collectorCapacity)
	Ui.setVisible(hud, "Bonus", bonus > 0)
	if bonus > 0 then
		Ui.setText(hud, "Bonus", Text.get("hud.bonus", { percent = Format.percent(bonus) }))
	end
end

local function renderTimers()
	local remaining = State.remaining("boost", "remaining")
	Ui.setVisible(hud, "Boost", remaining > 0)
	if remaining > 0 then
		Ui.setText(hud, "Boost", Text.get("hud.boost", { time = Format.clock(remaining) }))
	end
	local autoCollect = State.remaining("boost", "autoCollectRemaining")
	Ui.setVisible(hud, "AutoCollect", autoCollect > 0)
	if autoCollect > 0 then
		Ui.setText(hud, "AutoCollect", Text.get("hud.autoCollect", { time = Format.clock(autoCollect) }))
	end
end

local function renderGift()
	local gift = State.get("gift")
	local secondsToNext = if type(gift) == "table" then gift.secondsToNext else -1
	Ui.setVisible(hud, "Gift", secondsToNext >= 0)
	if secondsToNext < 0 then
		return
	end
	local seconds = State.remaining("gift", "secondsToNext")
	Ui.setText(
		hud,
		"Gift",
		if seconds <= 0 then Text.get("gift.ready") else Text.get("gift.wait", { time = Format.clock(seconds) })
	)
end

local function renderTutorial()
	local tutorial = State.get("tutorial")
	local active = type(tutorial) == "table" and not tutorial.done and tutorial.step ~= ""
	Ui.setVisible(hud, "Tutorial", active)
	if active then
		Ui.setText(
			hud,
			"Tutorial",
			Text.get(`tutorial.{tutorial.step}`, { count = tutorial.count, target = tutorial.target })
		)
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

local function renderAdButton()
	Ui.setVisible(hud, "AdBoost", AdsClient.offered(BOOST_AD))
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
	for _, name in { "Boost", "AutoCollect", "CarryHint", "CollectorFull", "Bonus", "Tutorial", "Gift", "AdBoost" } do
		Ui.setVisible(hud, name, false)
	end
	Ui.onActivated(Ui.button(hud, "Gift"), function()
		if State.remaining("gift", "secondsToNext") <= 0 then
			Net.event(Net.ClaimGift):FireServer()
		end
	end)
	local adButton = Ui.button(hud, "AdBoost")
	AdsClient.register(adButton, BOOST_AD)
	Ui.onActivated(adButton, function()
		task.spawn(AdsClient.watchAsync, BOOST_AD)
	end)
	AdsClient.eligibilityChanged:Connect(renderAdButton)

	State.watch({ "cash" }, renderCash)
	State.watch({ "boost" }, renderTimers)
	State.watch({ "carrying" }, renderCarry)
	State.watch({ "gift" }, renderGift)
	State.watch({ "tutorial" }, renderTutorial)
	State.watch({ "quests", "daily", "cash", "progress" }, renderBadges)
	State.watch({ "ads" }, renderAdButton)
	Text.changed:Connect(function()
		renderCash()
		renderCarry()
		renderTutorial()
	end)
end

function Hud.start()
	task.spawn(setupInvite)
	task.spawn(AdsClient.start)
	-- Timers count down locally; the server refreshes them every 30 seconds.
	local wasBoosted = false
	while true do
		task.wait(0.5)
		renderTimers()
		renderGift()
		local boosted = State.remaining("boost", "remaining") > 0
		if boosted ~= wasBoosted then
			wasBoosted = boosted
			renderCash()
		end
	end
end

return Hud
