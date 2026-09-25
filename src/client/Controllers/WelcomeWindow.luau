--!strict
-- Welcome-back window (Windows.WelcomeBack): what the machines earned offline (already paid), and the
-- chance to double it with a video ad ("time skip", Roblox's tycoon ad playbook) or the Robux product.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdsClient = require(script.Parent.Parent.Lib.AdsClient)
local Net = require(ReplicatedStorage.Shared.Net)
local Prices = require(script.Parent.Parent.Lib.Prices)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local WelcomeWindow = {}

local WINDOW = "WelcomeBack"
local AD_PLACEMENT = "doubleOffline"
local PRODUCT = "doubleOffline"

local window: GuiObject? = nil

local function renderPrice()
	Ui.setText(window, "DoublePrice", Prices.text("product", PRODUCT))
	Ui.setVisible(window, "DoubleBuy", Prices.available("product", PRODUCT))
end

-- Opens the window for the offline earnings (text already formatted, e.g. "$1.2K"). Returns false when
-- the window is not built (the caller shows a toast instead).
function WelcomeWindow.show(amount: string): boolean
	if window == nil then
		return false
	end
	Ui.setText(window, "Amount", Text.get("welcome.earned", { amount = amount }))
	renderPrice()
	Ui.setVisible(window, "DoubleAd", AdsClient.offered(AD_PLACEMENT))
	Windows.open(WINDOW)
	return true
end

function WelcomeWindow.init()
	window = Windows.get(WINDOW)
	Ui.onActivated(Ui.button(window, "Collect"), Windows.close)
	local adButton = Ui.button(window, "DoubleAd")
	AdsClient.register(adButton, AD_PLACEMENT)
	Ui.onActivated(adButton, function()
		Windows.close()
		task.spawn(AdsClient.watchAsync, AD_PLACEMENT)
	end)
	Ui.onActivated(Ui.button(window, "DoubleBuy"), function()
		Net.event(Net.Purchase):FireServer("product", PRODUCT)
		Windows.close()
	end)
	Prices.changed:Connect(function()
		if Windows.isOpen(WINDOW) then
			renderPrice()
		end
	end)
end

return WelcomeWindow
