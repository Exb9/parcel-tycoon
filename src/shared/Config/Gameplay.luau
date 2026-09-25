--!strict
-- Plot layout limits and server-side validation parameters for player actions.

return {
	-- One plot per player; keep equal to the place's max players setting.
	maxPlots = 6,

	-- Max distance (studs) between character and package when grabbing it.
	grabRange = 12,
	-- Max distance (studs) between character and exit when dropping a package into it.
	exitRange = 10,
	-- Minimum seconds between two grab/drop requests from the same player.
	actionCooldown = 0.25,
	-- Packages a player can carry at once.
	carryCapacity = 1,

	-- Physical packages allowed on one belt; spawners pause while a belt is full (no loss, no stress).
	maxPackagesPerBelt = 30,
}
