--!strict
-- Shop window (Windows.Shop): repeatable upgrades and the one-off purchases (machines, chutes, belts),
-- all bought with in-game cash. The server checks prices and requirements again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local StoreWindow = require(script.Parent.StoreWindow)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local ShopWindow = {}

local WINDOW = "Shop"

local window: GuiObject? = nil

local function progressWithLevel(progress: Economy.Progress, trackId: string, level: number): Economy.Progress
	local upgrades = table.clone(progress.upgrades)
	upgrades[trackId] = level
	return { zone = progress.zone, rebirths = progress.rebirths, upgrades = upgrades, purchases = progress.purchases }
end

local function upgradeDescription(progress: Economy.Progress, trackId: string, level: number, maxed: boolean): string
	if trackId == "sorterAccuracy" then
		local shownLevel = if maxed then level else level + 1
		local accuracy = Economy.sorterAccuracy(progressWithLevel(progress, trackId, shownLevel))
		return Text.get("upgrade.sorterAccuracy.desc", { percent = Format.percent(accuracy) })
	end
	return Text.get(`upgrade.{trackId}.desc`)
end

local function renderUpgrades(progress: Economy.Progress, cash: number)
	local keys = {}
	for _, track in Config.Upgrades.tracks do
		table.insert(keys, track.id)
	end
	Ui.list(Ui.find(window, "Upgrades"), keys, function(item, trackId)
		Ui.onActivated(Ui.button(item, "Buy"), function()
			Net.event(Net.BuyUpgrade):FireServer(trackId)
		end)
	end, function(item, trackId)
		local track = Economy.getTrack(trackId)
		local level = Economy.level(progress, trackId)
		local cost = Economy.upgradeCost(trackId, level)
		Ui.setText(item, "Title", Names.upgrade(trackId))
		Ui.setText(item, "Description", upgradeDescription(progress, trackId, level, cost == nil))
		Ui.setText(item, "Level", Text.get("shop.level", { level = level, max = track.maxLevel }))
		Ui.setText(item, "Price", if cost then Format.cash(cost) else Text.get("shop.max"))
		Ui.setVisible(item, "Buy", cost ~= nil)
		Ui.setVisible(item, "Locked", cost ~= nil and cash < cost)
	end)
end

-- Purchases the player can see now: not owned, and the purchase before it in its chain is owned.
local function visiblePurchases(progress: Economy.Progress): { Economy.Purchase }
	local list = {}
	for _, purchase in Config.Purchases.purchases do
		if
			not Economy.owns(progress, purchase.id)
			and (purchase.requires == nil or Economy.owns(progress, purchase.requires))
		then
			table.insert(list, purchase)
		end
	end
	table.sort(list, function(a, b)
		return a.cost < b.cost
	end)
	return list
end

local function renderMachines(progress: Economy.Progress, cash: number, passes: { [string]: boolean })
	local purchases = visiblePurchases(progress)
	local keys = {}
	for _, purchase in purchases do
		table.insert(keys, purchase.id)
	end
	Ui.list(Ui.find(window, "Machines"), keys, function(item, purchaseId)
		Ui.onActivated(Ui.button(item, "Buy"), function()
			local purchase = Economy.getPurchase(purchaseId)
			if purchase.requiresPass and not State.passes()[purchase.requiresPass] then
				-- Show where the pass is sold instead.
				StoreWindow.show("Passes")
				return
			end
			Net.event(Net.BuyPurchase):FireServer(purchaseId)
		end)
	end, function(item, purchaseId)
		local purchase = Economy.getPurchase(purchaseId)
		local needsPass = purchase.requiresPass ~= nil and not passes[purchase.requiresPass]
		Ui.setText(item, "Title", Names.purchase(purchaseId))
		Ui.setText(item, "Description", Names.purchaseDescription(purchaseId))
		if needsPass then
			Ui.setText(
				item,
				"Price",
				Text.get("shop.needsPass", { pass = Names.pass(purchase.requiresPass :: string) })
			)
		else
			Ui.setText(item, "Price", Format.cash(purchase.cost))
		end
		Ui.setVisible(item, "Locked", needsPass or cash < purchase.cost)
	end)
	Ui.setVisible(window, "Machines/AllBuilt", #purchases == 0)
end

local function render()
	local progress = State.progress()
	local cash = State.cash()
	if window == nil or progress == nil or cash == nil or not Windows.isOpen(WINDOW) then
		return
	end
	renderUpgrades(progress, cash.cash)
	renderMachines(progress, cash.cash, State.passes())
end

function ShopWindow.init()
	window = Windows.get(WINDOW)
	Windows.tabs(WINDOW, { "Upgrades", "Machines" })
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
		end
	end)
	State.watch({ "cash", "progress", "passes" }, render)
	Text.changed:Connect(render)
end

return ShopWindow
