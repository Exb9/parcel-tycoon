--!strict
-- Offer popup (Windows.Offer): one pass or product the server suggests at a fitting moment (OfferService),
-- e.g. the starter pack after the first machine. Neutral wording, a "Maybe later" close button, no timer.

local Names = require(script.Parent.Parent.Lib.Names)
local Prices = require(script.Parent.Parent.Lib.Prices)
local StoreWindow = require(script.Parent.StoreWindow)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local OfferWindow = {}

local WINDOW = "Offer"

type Kind = Prices.Kind

local window: GuiObject? = nil
local current: { kind: Kind, key: string }? = nil

local function render()
	local offer = current
	if window == nil or offer == nil then
		return
	end
	Ui.setText(window, "Title", if offer.kind == "pass" then Names.pass(offer.key) else Names.product(offer.key))
	Ui.setText(window, "Description", StoreWindow.describe(offer.kind, offer.key))
	Ui.setText(window, "Price", Prices.text(offer.kind, offer.key))
	local icon = Ui.find(window, "Icon")
	local iconId = Prices.icon(offer.kind, offer.key)
	if icon and icon:IsA("ImageLabel") and iconId then
		icon.Image = `rbxassetid://{iconId}`
	end
end

-- Shows an offer, unless the player is busy in another window.
function OfferWindow.show(kind: string, key: string)
	if window == nil or (kind ~= "pass" and kind ~= "product") then
		return
	end
	for _, name in { "Shop", "Store", "Quests", "Daily", "Rebirth", "Style", "Info", "Codes", "WelcomeBack" } do
		if Windows.isOpen(name) then
			return
		end
	end
	current = { kind = kind :: Kind, key = key }
	render()
	Windows.open(WINDOW)
end

function OfferWindow.init()
	window = Windows.get(WINDOW)
	Ui.onActivated(Ui.button(window, "Buy"), function()
		local offer = current
		if offer then
			StoreWindow.buy(offer.kind, offer.key)
		end
		Windows.close()
	end)
	Prices.changed:Connect(render)
end

return OfferWindow
