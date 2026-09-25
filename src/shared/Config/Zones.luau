--!strict
-- Zones from the brief: post office -> airport cargo -> space hub.
-- Only the post office is playable until phase 6; unlock rules, package types and mechanics of the
-- other zones are decided then.

export type Zone = {
	id: string,
	displayName: string,
	order: number,
	-- false = not built yet (phase 6).
	available: boolean,
}

local zones: { Zone } = {
	{ id = "postOffice", displayName = "Post Office", order = 1, available = true },
	{ id = "airportCargo", displayName = "Airport Cargo", order = 2, available = false },
	{ id = "spaceHub", displayName = "Space Hub", order = 3, available = false },
}

return {
	startingZone = "postOffice",
	zones = zones,
}
