--!strict
-- Decides what the next spawned package is: type (by spawn weight), rare variant (fixed chances)
-- and whether it is an express delivery (zone mechanic). Pure; the caller supplies the randomness.

local Config = require("./Config")
local Economy = require("./Economy")
local Rng = require("./Rng")

export type Roll = {
	typeIndex: number,
	-- Rare variant id or nil for a normal package.
	rare: string?,
	express: boolean,
}

local PackageRoll = {}

function PackageRoll.roll(zoneId: string, random: () -> number): Roll
	local packageType = Rng.pickWeighted(Economy.packageTypesForZone(zoneId), function(t)
		return t.spawnWeight
	end, random)

	local rare: string? = nil
	local roll = random()
	for _, variant in Config.PackageTypes.rareVariants do
		if roll < variant.chance then
			rare = variant.id
			break
		end
		roll -= variant.chance
	end

	local express = false
	local zone = Economy.getZone(zoneId)
	if rare == nil and zone.express and random() < zone.express.chance then
		express = true
	end

	return { typeIndex = packageType.index, rare = rare, express = express }
end

return PackageRoll
