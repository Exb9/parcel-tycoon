--!strict
-- Store window (Windows.Store): gamepasses, developer products (starter pack, cash packs, boosts, Auto
-- Collect time, instant machine), styles and the Parcel Club subscription. Prices come from
-- MarketplaceService (Lib/Prices). The "try Auto Collect" video ad button sits in the store as well.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdsClient = require(script.Parent.Parent.Lib.AdsClient)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local Prices = require(script.Parent.Parent.Lib.Prices)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local StoreWindow = {}

local WINDOW = "Store"
local AUTO_COLLECT_AD = "autoCollectTrial"

type Kind = Prices.Kind

local monetization = Config.Monetization
local window: GuiObject? = nil
local selectTab: ((string) -> ())? = nil

local function owned(kind: Kind, key: string): boolean
	if kind == "pass" then
		return State.passes()[key] == true
	end
	local product = monetization.products[key]
	local store = State.get("store")
	return product.oneTime == true and type(store) == "table" and store.oneTime[key] == true
end

-- Description of a pass or product, filled with the player's numbers.
function StoreWindow.describe(kind: Kind, key: string): string
	if kind == "pass" then
		local pass = monetization.gamepasses[key]
		return Text.get(if pass.cosmeticId then "product.cosmetic.desc" else `pass.{key}.desc`)
	end
	local product = monetization.products[key]
	local cash = State.cash()
	local income = if cash then cash.income else 0
	local function amount(): string
		return Format.cash(Economy.cashPackAmount(income, product.incomeMinutes or 0, product.minimumCash or 0))
	end
	if product.kind == "cash" or product.kind == "doubleOffline" then
		return Text.get("product.cash.desc", { amount = amount() })
	elseif product.kind == "boost" then
		return Text.get("product.cashBoost.desc", { minutes = product.minutes or 0 })
	elseif product.kind == "autoCollectTrial" then
		return Text.get("product.autoCollectTrial.desc", { minutes = product.minutes or 0 })
	elseif product.kind == "starterPack" then
		return Text.get("product.starterPack.desc", {
			amount = amount(),
			minutes = product.minutes or 0,
			style = if product.cosmeticId then Names.cosmetic(product.cosmeticId) else "",
		})
	elseif product.kind == "instantMachine" then
		local progress = State.progress()
		local nextMachine = progress and Economy.nextSorterPurchase(progress, State.passes())
		if nextMachine then
			return Text.get("product.instantMachine.desc", { name = Names.purchase(nextMachine.id) })
		end
		return Text.get("store.noMachine")
	end
	return ""
end

function StoreWindow.buy(kind: Kind, key: string)
	Net.event(Net.Purchase):FireServer(kind, key)
end

local function renderList(listName: string, kind: Kind, keys: { string })
	local shown = {}
	for _, key in keys do
		-- A bought starter pack disappears.
		if not (kind == "product" and owned(kind, key)) then
			table.insert(shown, key)
		end
	end
	Ui.list(Ui.find(window, listName), shown, function(item, key)
		Ui.onActivated(Ui.button(item, "Buy"), function()
			StoreWindow.buy(kind, key)
		end)
	end, function(item, key)
		local isOwned = owned(kind, key)
		Ui.setText(item, "Title", if kind == "pass" then Names.pass(key) else Names.product(key))
		Ui.setText(item, "Description", StoreWindow.describe(kind, key))
		Ui.setText(item, "Price", if isOwned then Text.get("store.owned") else Prices.text(kind, key))
		Ui.setVisible(item, "Buy", not isOwned)
		Ui.setVisible(item, "Owned", isOwned)
		local icon = Ui.find(item, "Icon")
		local iconId = Prices.icon(kind, key)
		if icon and icon:IsA("ImageLabel") and iconId then
			icon.Image = `rbxassetid://{iconId}`
		end
	end)
end

local function renderClub()
	local club = State.get("club")
	local available = type(club) == "table" and club.available == true
	Ui.setVisible(window, "ClubTab", available)
	if not available then
		return
	end
	local member = club.member == true
	local bonus = Format.percent(monetization.club.cashBonus)
	Ui.setText(window, "Club/Description", Text.get("club.desc", { bonus = bonus }))
	Ui.setText(window, "Club/Price", Prices.clubText())
	Ui.setVisible(window, "Club/Join", not member)
	Ui.setVisible(window, "Club/Member", member)
	Ui.setVisible(window, "Club/Claim", member and club.canClaim == true)
	Ui.setVisible(window, "Club/Claimed", member and club.canClaim ~= true)
end

local function renderAdButton()
	local cash = State.cash()
	local autoCollect = cash ~= nil and cash.autoCollect
	Ui.setVisible(window, "AdAutoCollect", not autoCollect and AdsClient.offered(AUTO_COLLECT_AD))
end

local function render()
	if window == nil or not Windows.isOpen(WINDOW) then
		return
	end
	renderList("Passes", "pass", monetization.gamepassOrder)
	renderList("Products", "product", monetization.productOrder)
	renderList("Styles", "pass", monetization.stylePassOrder)
	renderClub()
end

-- Opens the store on a tab ("Passes", "Products", "Styles" or "Club").
function StoreWindow.show(tabName: string)
	Windows.open(WINDOW)
	if selectTab then
		selectTab(tabName)
	end
end

function StoreWindow.init()
	window = Windows.get(WINDOW)
	selectTab = Windows.tabs(WINDOW, { "Passes", "Products", "Styles", "Club" })
	Ui.onActivated(Ui.button(window, "Club/Join"), function()
		Net.event(Net.Purchase):FireServer("club", "")
	end)
	Ui.onActivated(Ui.button(window, "Club/Claim"), function()
		Net.event(Net.ClaimClubGift):FireServer()
	end)
	local adButton = Ui.button(window, "AdAutoCollect")
	AdsClient.register(adButton, AUTO_COLLECT_AD)
	Ui.onActivated(adButton, function()
		task.spawn(AdsClient.watchAsync, AUTO_COLLECT_AD)
	end)
	AdsClient.eligibilityChanged:Connect(renderAdButton)
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
			renderAdButton()
		end
	end)
	State.watch({ "passes", "cosmetics", "progress", "store", "club" }, render)
	-- Cash pack amounts follow the income.
	State.watch({ "cash" }, function()
		if Windows.isOpen(WINDOW) then
			renderList("Products", "product", monetization.productOrder)
		end
	end)
	State.watch({ "ads", "cash" }, renderAdButton)
	Prices.changed:Connect(render)
	Text.changed:Connect(render)
end

return StoreWindow
