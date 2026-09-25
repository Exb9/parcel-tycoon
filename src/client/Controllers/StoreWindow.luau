--!strict
-- Store window (Windows.Store): gamepasses, developer products (cash packs, boost, instant machine) and
-- cosmetics. Prices are read from MarketplaceService:GetProductInfoAsync, never from the config, so
-- regional pricing and price optimization keep working. Offers with id 0 are not created yet: "Test" in
-- Studio (the server grants them directly), "Soon" in live games.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local StoreWindow = {}

local WINDOW = "Store"
local ROBUX = utf8.char(0xE002)

type Offer = { kind: "pass" | "product", key: string, id: number }
type Info = { price: number?, icon: number? }

local monetization = Config.Monetization
local window: GuiObject? = nil
local selectTab: ((string) -> ())? = nil
local infos: { [string]: Info } = {}
local requested: { [string]: boolean } = {}

local function offerKey(offer: Offer): string
	return `{offer.kind}:{offer.key}`
end

local function offers(kind: "pass" | "product", keys: { string }): { Offer }
	local list = {}
	for _, key in keys do
		local id = if kind == "pass" then monetization.gamepasses[key].id else monetization.products[key].id
		table.insert(list, { kind = kind, key = key, id = id })
	end
	return list
end

local render: () -> ()

-- Loads price and icon once per offer, then re-renders.
local function requestInfo(offer: Offer)
	local key = offerKey(offer)
	if offer.id == 0 or requested[key] then
		return
	end
	requested[key] = true
	task.spawn(function()
		local infoType = if offer.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, result = pcall(function()
			return MarketplaceService:GetProductInfoAsync(offer.id, infoType)
		end)
		if ok and type(result) == "table" then
			infos[key] = { price = result.PriceInRobux, icon = result.IconImageAssetId }
			render()
		else
			requested[key] = nil
		end
	end)
end

local function priceText(offer: Offer): string
	if offer.id == 0 then
		local simulated = RunService:IsStudio() and monetization.simulateInStudio
		return Text.get(if simulated then "store.test" else "store.soon")
	end
	local info = infos[offerKey(offer)]
	if info and info.price then
		return `{ROBUX} {Format.number(info.price)}`
	end
	return "..."
end

local function owned(offer: Offer): boolean
	if offer.kind == "pass" then
		return State.passes()[offer.key] == true
	end
	local product = monetization.products[offer.key]
	local cosmetics = State.cosmetics()
	return product.kind == "cosmetic"
		and product.cosmeticId ~= nil
		and cosmetics ~= nil
		and cosmetics.owned[product.cosmeticId] == true
end

local function description(offer: Offer): string
	if offer.kind == "pass" then
		return Text.get(`pass.{offer.key}.desc`)
	end
	local product = monetization.products[offer.key]
	if product.kind == "cash" then
		local cash = State.cash()
		local income = if cash then cash.income else 0
		local amount = Economy.cashPackAmount(income, product.incomeMinutes or 0, product.minimumCash or 0)
		return Text.get("product.cash.desc", { amount = Format.cash(amount) })
	elseif product.kind == "boost" then
		return Text.get("product.cashBoost.desc", { minutes = product.minutes or 0 })
	elseif product.kind == "instantMachine" then
		local progress = State.progress()
		local nextMachine = progress and Economy.nextSorterPurchase(progress, State.passes())
		if nextMachine then
			return Text.get("product.instantMachine.desc", { name = Names.purchase(nextMachine.id) })
		end
		return Text.get("store.noMachine")
	end
	return Text.get("product.cosmetic.desc")
end

local function renderList(listName: string, list: { Offer })
	local byKey: { [string]: Offer } = {}
	local keys = {}
	for _, offer in list do
		byKey[offer.key] = offer
		table.insert(keys, offer.key)
		requestInfo(offer)
	end
	Ui.list(Ui.find(window, listName), keys, function(item, key)
		Ui.onActivated(Ui.button(item, "Buy"), function()
			local offer = byKey[key]
			Net.event(Net.Purchase):FireServer(offer.kind, offer.key)
		end)
	end, function(item, key)
		local offer = byKey[key]
		local isOwned = owned(offer)
		local title = if offer.kind == "pass" then Names.pass(offer.key) else Names.product(offer.key)
		Ui.setText(item, "Title", title)
		Ui.setText(item, "Description", description(offer))
		Ui.setText(item, "Price", if isOwned then Text.get("store.owned") else priceText(offer))
		Ui.setVisible(item, "Buy", not isOwned)
		Ui.setVisible(item, "Owned", isOwned)
		local info = infos[offerKey(offer)]
		local icon = Ui.find(item, "Icon")
		if icon and icon:IsA("ImageLabel") and info and info.icon and info.icon ~= 0 then
			icon.Image = `rbxassetid://{info.icon}`
		end
	end)
end

function render()
	if window == nil or not Windows.isOpen(WINDOW) then
		return
	end
	renderList("Passes", offers("pass", monetization.gamepassOrder))
	renderList("Products", offers("product", monetization.productOrder))
	renderList("Styles", offers("product", monetization.cosmeticProductOrder))
end

-- Opens the store on a tab ("Passes", "Products" or "Styles").
function StoreWindow.show(tabName: string)
	Windows.open(WINDOW)
	if selectTab then
		selectTab(tabName)
	end
end

function StoreWindow.init()
	window = Windows.get(WINDOW)
	selectTab = Windows.tabs(WINDOW, { "Passes", "Products", "Styles" })
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
		end
	end)
	State.watch({ "passes", "cosmetics", "progress" }, render)
	-- Cash pack amounts follow the income.
	State.watch({ "cash" }, function()
		if Windows.isOpen(WINDOW) then
			renderList("Products", offers("product", monetization.productOrder))
		end
	end)
	Text.changed:Connect(render)
end

return StoreWindow
