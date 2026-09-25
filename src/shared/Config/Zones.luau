--!strict
-- Zones. A player's warehouse runs in the highest zone they unlocked; unlocking happens through
-- rebirths, and the warehouse switches to the new zone at the start of the next run.
-- One plot template serves every zone: parts tagged with a ThemeRole get the zone's colors.

export type Theme = {
	floor: string,
	wall: string,
	trim: string,
	belt: string,
}

export type Express = {
	-- Share of normal packages that arrive as express deliveries.
	chance: number,
	-- Seconds after spawning in which a correct sort pays the bonus.
	seconds: number,
	valueMultiplier: number,
}

export type Zone = {
	id: string,
	displayName: string,
	order: number,
	-- Requirements to unlock; nil for the starting zone.
	unlock: { rebirths: number }?,
	-- false = shown as "coming soon" and never unlocked.
	available: boolean,
	theme: Theme,
	-- Zone mechanic: express deliveries with a time bonus.
	express: Express?,
}

local zones: { Zone } = {
	{
		id = "postOffice",
		displayName = "Post Office",
		order = 1,
		available = true,
		theme = { floor = "#CFD8DC", wall = "#FFF3E0", trim = "#FFB300", belt = "#37474F" },
	},
	{
		id = "airportCargo",
		displayName = "Airport Cargo",
		order = 2,
		unlock = { rebirths = 3 },
		available = true,
		theme = { floor = "#B0BEC5", wall = "#E3F2FD", trim = "#1E88E5", belt = "#263238" },
		express = { chance = 0.12, seconds = 30, valueMultiplier = 2 },
	},
	{
		id = "spaceHub",
		displayName = "Space Hub",
		order = 3,
		unlock = { rebirths = 6 },
		available = false,
		theme = { floor = "#37474F", wall = "#311B92", trim = "#00E5FF", belt = "#212121" },
	},
}

return {
	startingZone = "postOffice",
	zones = zones,
}
