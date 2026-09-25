--!strict
-- Unlockable zones. Only the post office exists until phase 6; later unlock requirements are placeholders.

export type Zone = {
	id: string,
	displayName: string,
	order: number,
	-- Requirements to unlock; nil for the starting zone.
	unlock: { rebirths: number }?,
}

local zones: { Zone } = {
	{ id = "postOffice", displayName = "Post Office", order = 1 },
	{ id = "airportCargo", displayName = "Airport Cargo", order = 2, unlock = { rebirths = 2 } },
	{ id = "spaceHub", displayName = "Space Hub", order = 3, unlock = { rebirths = 6 } },
}

return {
	startingZone = "postOffice",
	zones = zones,
}
