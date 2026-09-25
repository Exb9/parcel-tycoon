--!strict
-- Rewarded video ads on the client. AdService only answers availability on the client, and Roblox asks to
-- check it right before an ad is played, so buttons are shown without a network call (placement set up,
-- daily limit not reached, player not known to be ineligible) and availability is checked on press.
-- The server plays the ad; the reward arrives through ProcessReceipt (MonetizationService).

local AdService = game:GetService("AdService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local State = require(script.Parent.State)

local AdsClient = {}

-- Fires when a button was pressed but no ad could be shown right now.
AdsClient.unavailable = Signal.new() :: Signal.Signal<>
-- Fires when the player turned out to be ineligible for ads (buttons should hide).
AdsClient.eligibilityChanged = Signal.new() :: Signal.Signal<>

local INELIGIBLE = {
	Enum.AdAvailabilityResult.PlayerIneligible,
	Enum.AdAvailabilityResult.DeviceIneligible,
	Enum.AdAvailabilityResult.PublisherIneligible,
	Enum.AdAvailabilityResult.ExperienceIneligible,
}

local ineligible = false

local function product(placement: string): typeof(Config.Monetization.products.boostSmall)?
	local config = Config.Monetization.ads[placement]
	return if config then Config.Monetization.products[config.productKey] else nil
end

local function simulated(): boolean
	return RunService:IsStudio() and Config.Monetization.simulateInStudio
end

-- Ads the player may still watch today for a placement (server state).
function AdsClient.remaining(placement: string): number
	local ads = State.get("ads")
	local count = if type(ads) == "table" then ads[placement] else nil
	return if type(count) == "number" then count else 0
end

-- Whether to show the button of a placement (no network call).
function AdsClient.offered(placement: string): boolean
	local reward = product(placement)
	if reward == nil or ineligible or AdsClient.remaining(placement) <= 0 then
		return false
	end
	return reward.id ~= 0 or simulated()
end

-- Asks AdService whether an ad can be played right now (yields) and remembers lasting ineligibility.
function AdsClient.availableAsync(placement: string): boolean
	local reward = product(placement)
	if reward == nil or not AdsClient.offered(placement) then
		return false
	end
	if reward.id == 0 then
		return simulated()
	end
	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	if not ok or type(result) ~= "table" then
		return false
	end
	local availability = result.AdAvailabilityResult
	if table.find(INELIGIBLE, availability) and not ineligible then
		ineligible = true
		AdsClient.eligibilityChanged:Fire()
	end
	return availability == Enum.AdAvailabilityResult.IsAvailable
end

-- Plays an ad for the placement if one is available now (yields).
function AdsClient.watchAsync(placement: string)
	if AdsClient.availableAsync(placement) then
		Net.event(Net.WatchAd):FireServer(placement)
	else
		AdsClient.unavailable:Fire()
	end
end

-- Reports the button as an ad opportunity (Creator Hub ad analytics).
function AdsClient.register(button: GuiButton?, placement: string)
	local config = Config.Monetization.ads[placement]
	local reward = product(placement)
	if button == nil or config == nil or reward == nil or reward.id == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			AdService:RegisterAdOpportunityAsync(button, if config.placementId ~= 0 then config.placementId else nil)
		end)
	end)
end

-- One availability check at startup finds players who can never see ads (e.g. under 13).
function AdsClient.start()
	for placement in Config.Monetization.ads do
		local reward = product(placement)
		if reward and reward.id ~= 0 then
			AdsClient.availableAsync(placement)
			return
		end
	end
end

return AdsClient
