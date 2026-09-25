--!strict
-- Redeemable codes (for social media posts, events, updates). Server-only on purpose: everything in
-- ReplicatedStorage can be read by clients, so codes there would leak before they are announced.
-- Keys are normalized codes (upper case, letters and digits only, see Rewards.normalizeCode). Each player
-- can redeem a code once. `expires` is a UTC unix time (os.time()) or nil for no expiry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardsConfig = require(ReplicatedStorage.Shared.Config.Rewards)

export type Code = {
	reward: RewardsConfig.Reward,
	expires: number?,
}

local codes: { [string]: Code } = {
	WELCOME = { reward = { kind = "cash", incomeMinutes = 10, minimumCash = 500 } },
	PARCELS = { reward = { kind = "boost", minutes = 15 } },
}

return table.freeze(codes)
