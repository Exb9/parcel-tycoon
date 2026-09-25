--!strict
-- Decides what the next spawned package is: type (by spawn weight) and rare variant (fixed chances).
-- Pure; the caller supplies the randomness.

local Config = require("./Config")
local Economy = require("./Economy")
local Rng = require("./Rng")

export type Roll = {
	typeIndex: number,
	-- Rare variant id or nil for a normal package.
	rare: string?,
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

	return { typeIndex = packageType.index, rare = rare }
end

return PackageRoll
