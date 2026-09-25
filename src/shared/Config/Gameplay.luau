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
		-- Space between queued packages.
		gap = 0.5,
		-- Length of the queue at the end of the belt. Packages that do not fit fall into the recycling bin.
		queueLength = 14,
		-- Safety cap for packages on one belt.
		maxPackages = 30,
		-- Packages a sorting machine can take in a burst: it earns one "token" per sort interval and holds
		-- up to this many, so arrivals that bunch up are not missed (keeps real throughput close to
		-- Economy.incomePerMinute, which assumes min(arrivals, rate)).
		sorterBuffer = 3,
		-- Seconds the remove animations (sorted/recycled) play before the part is destroyed.
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
		heavyWalkSpeedMultiplier = 0.7,
		fragileWalkSpeedMultiplier = 0.8,
		-- A fragile package breaks when the carrier moves up or down faster than this (jumping, falling).
		fragileMaxVerticalSpeed = 18,
		-- Grace period after grabbing before a fragile package can break.
		fragileGraceSeconds = 0.6,
	},

	-- Horizontal distance to the cash register that collects it.
	collectorRadius = 5,
	-- Horizontal distance to the VIP gift pad that claims it.
	vipGiftRadius = 5,

	-- Characters spawn on their plot at this walk speed.
	walkSpeed = 16,
}
