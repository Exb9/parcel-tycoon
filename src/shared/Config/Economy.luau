--!strict
-- Core economy numbers: spawn and sorter rates, collector, offline earnings and rebirth.
-- See docs/BALANCING.md for the targets these values are tuned against.

return {
	startingCash = 0,

	-- Packages per minute from one spawner chute at belt speed level 0.
	spawnsPerMinute = 14,
	-- Packages per minute a sorting machine handles at machine speed level 0.
	sorterBaseRate = 9,
	-- Balancing assumption for a young player sorting by hand (~5 s per package incl. walking).
	-- Only the simulation uses it; in game the manual rate is whatever the player achieves.
	manualSortsPerMinute = 12,

	-- Fraction of the package value subtracted for a wrong exit (0 = just no cash).
	wrongSortPenalty = 0,

	-- Machines pay into the plot's collector; it stops filling once it holds this many minutes of
	-- machine income. The Auto Collect pass pays machine income straight to the balance instead.
	collectorCapacityMinutes = 15,

	offline = {
		-- Share of the machine income rate paid while offline.
		efficiency = 0.3,
		-- Base cap; the "offlineCap" upgrade adds to it.
		baseCapHours = 2,
	},

	rebirth = {
		-- Cash needed for the first rebirth; each further rebirth costs costGrowth times more.
		baseCost = 150000,
		costGrowth = 2,
		-- Additive income bonus per rebirth (x1.5, x2, x2.5, ...).
		incomeBonusPerRebirth = 0.5,
	},
}
