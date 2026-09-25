--!strict
-- Daily limits for rewarded video ads (pure logic; MonetizationService shows the ads).

local Config = require("./Config")

-- PlayerData.ads (DataSchema).
export type AdsData = { day: number, counts: { [string]: number } }

local Ads = {}

local function ensureDay(ads: AdsData, day: number)
	if ads.day ~= day then
		ads.day = day
		ads.counts = {}
	end
end

-- Ads the player can still watch today for a placement (Config.Monetization.ads key).
function Ads.remaining(ads: AdsData, day: number, placement: string): number
	local config = Config.Monetization.ads[placement]
	if config == nil then
		return 0
	end
	local count = if ads.day == day then ads.counts[placement] or 0 else 0
	return math.max(0, config.dailyLimit - count)
end

-- Counts a watched ad. Returns false if the daily limit was already reached.
function Ads.record(ads: AdsData, day: number, placement: string): boolean
	if Ads.remaining(ads, day, placement) <= 0 then
		return false
	end
	ensureDay(ads, day)
	ads.counts[placement] = (ads.counts[placement] or 0) + 1
	return true
end

-- The ad placement whose reward is this product, if any.
function Ads.placementForProduct(productKey: string): string?
	for placement, config in Config.Monetization.ads do
		if config.productKey == productKey then
			return placement
		end
	end
	return nil
end

return Ads
