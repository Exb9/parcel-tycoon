--!strict
-- Prices and icons of passes, developer products and the club subscription, read from MarketplaceService
-- (never from the config, so Roblox regional pricing and price optimization keep working). Results are
-- cached; `changed` fires when one arrives. Offers with id 0 are not created yet: "Test" in Studio (the
-- server grants them directly), "Soon" in live games.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Text = require(script.Parent.Text)

export type Kind = "pass" | "product"
type Info = { price: number?, icon: number?, display: string? }

local Prices = {}

local ROBUX = utf8.char(0xE002)
local CLUB_KEY = "club"

-- Fires after a price arrived.
Prices.changed = Signal.new() :: Signal.Signal<>

local monetization = Config.Monetization
local infos: { [string]: Info } = {}
local requested: { [string]: boolean } = {}

local function idOf(kind: Kind, key: string): number
	local entry: { id: number }? = if kind == "pass" then monetization.gamepasses[key] else monetization.products[key]
	return if entry then entry.id else 0
end

local function simulated(): boolean
	return RunService:IsStudio() and monetization.simulateInStudio
end

local function load(cacheKey: string, fetch: () -> Info?)
	if requested[cacheKey] then
		return
	end
	requested[cacheKey] = true
	task.spawn(function()
		local ok, info = pcall(fetch)
		if ok and info then
			infos[cacheKey] = info
			Prices.changed:Fire()
		else
			-- Try again next time.
			requested[cacheKey] = nil
		end
	end)
end

local function info(kind: Kind, key: string): Info?
	local id = idOf(kind, key)
	if id == 0 then
		return nil
	end
	local cacheKey = `{kind}:{key}`
	load(cacheKey, function(): Info?
		local infoType = if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local result = MarketplaceService:GetProductInfoAsync(id, infoType)
		return { price = result.PriceInRobux, icon = result.IconImageAssetId }
	end)
	return infos[cacheKey]
end

-- Whether the offer can be bought here (created, or simulated in Studio).
function Prices.available(kind: Kind, key: string): boolean
	return idOf(kind, key) ~= 0 or simulated()
end

-- Price label: Robux symbol and amount, "Test" (Studio, not created yet), "Soon" (live, not created yet)
-- or "..." while loading.
function Prices.text(kind: Kind, key: string): string
	if idOf(kind, key) == 0 then
		return Text.get(if simulated() then "store.test" else "store.soon")
	end
	local loaded = info(kind, key)
	if loaded and loaded.price then
		return `{ROBUX} {Format.number(loaded.price)}`
	end
	return "..."
end

-- Icon asset id of a pass or product, once loaded.
function Prices.icon(kind: Kind, key: string): number?
	local loaded = info(kind, key)
	return if loaded and loaded.icon and loaded.icon ~= 0 then loaded.icon else nil
end

-- Club subscription: localized price with period ("$4.99/month" or Robux), "Test" or "Soon".
function Prices.clubText(): string
	local id = monetization.club.id
	if id == "" then
		return Text.get(if simulated() then "store.test" else "store.soon")
	end
	load(CLUB_KEY, function(): Info?
		local result = MarketplaceService:GetSubscriptionProductInfoAsync(id)
		local display = `{result.DisplayPrice or ""}{result.DisplaySubscriptionPeriod or ""}`
		return { display = display }
	end)
	local loaded = infos[CLUB_KEY]
	return if loaded and loaded.display then loaded.display else "..."
end

return Prices
