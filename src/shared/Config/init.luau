--!strict
-- Central configuration: balancing, content and monetization live here so tuning needs no code changes.
-- Everything is deep-frozen; runtime code must never mutate config.

local function deepFreeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in value do
			deepFreeze(child)
		end
		table.freeze(value)
	end
	return value
end

return deepFreeze({
	Economy = require("@self/Economy"),
	Gameplay = require("@self/Gameplay"),
	Monetization = require("@self/Monetization"),
	PackageTypes = require("@self/PackageTypes"),
	Purchases = require("@self/Purchases"),
	Upgrades = require("@self/Upgrades"),
	Zones = require("@self/Zones"),
})
