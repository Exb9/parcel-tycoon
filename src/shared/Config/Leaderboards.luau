--!strict
-- Global leaderboards (OrderedDataStore). Board parts live in Workspace.Lobby.Leaderboards (docs/MAP_CONTRACT.md).

export type Board = {
	id: string,
	title: string,
	-- Field in PlayerData.stats that is ranked.
	stat: string,
	store: string,
}

local boards: { Board } = {
	{ id = "TopEarned", title = "Top Earners", stat = "totalEarned", store = "LB_TotalEarned_v1" },
	{ id = "TopRebirths", title = "Most Rebirths", stat = "rebirths", store = "LB_Rebirths_v1" },
	{ id = "TopSorted", title = "Most Parcels Sorted", stat = "sortedTotal", store = "LB_Sorted_v1" },
}

return {
	boards = boards,
	entries = 10,
	-- Seconds between writes of a player's stats and between board refreshes.
	writeInterval = 120,
	refreshInterval = 90,
}
