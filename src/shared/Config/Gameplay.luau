--!strict
-- Plot, belt and interaction parameters, including the limits the server uses to validate
-- player actions. Distances are in studs, times in seconds.

return {
	-- One plot per player; keep equal to the place's max players setting.
	maxPlots = 6,

	belt = {
		-- Belt surface speed at belt speed level 0; grows with the beltSpeed upgrade up to maxSpeed.
		baseSpeed = 5,
		maxSpeed = 14,
		-- Space between packages resting on the belt.
		gap = 0.5,
		-- Safety cap for packages on one belt. When the belt is full, the chute pauses (nothing is lost).
		maxPackages = 30,
		-- A sorting machine reaches this far along the belt on each side of its position: it takes a
		-- matching package that passes it or waits in front of it.
		sorterReach = 4,
		-- Packages a sorting machine can take in a quick burst (smooths bunched-up arrivals so the real
		-- throughput matches Economy.incomePerMinute). Internal, not an upgrade.
		sorterBuffer = 3,
		-- Seconds the "sorted by a machine" animation plays before the part is removed.
		leaveSeconds = 0.4,
	},

	carry = {
		-- Packages a player can carry at once.
		capacity = 1,
		-- Max distance between character and package when grabbing, plus slack for latency.
		grabRange = 12,
		grabSlack = 4,
		-- Horizontal distance to an exit's center that counts as "in the chute".
		exitRadius = 4.5,
		-- Anti-teleport: a package cannot travel faster than this from the belt to the exit.
		maxTravelSpeed = 40,
		-- Minimum seconds between two grab requests.
		grabCooldown = 0.25,
		-- A fragile package breaks when the carrier moves up or down faster than this (jumping, falling).
		fragileMaxVerticalSpeed = 18,
		-- Grace period after grabbing before a fragile package can break.
		fragileGraceSeconds = 0.6,
	},

	-- Horizontal distance to the cash register that collects it.
	collectorRadius = 5,
}
