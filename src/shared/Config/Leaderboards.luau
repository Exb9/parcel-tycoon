--!strict
-- Global leaderboards (OrderedDataStore). Board parts live in Workspace.Lobby.Leaderboards (docs/MAP_CONTRACT.md).

-- Board titles are texts "board.<id>" in GameText.csv (the title label built in Studio gets TextKey = "board.<id>").

export type Board = {
	id: string,
	-- Field in PlayerData.stats that is ranked.
	stat: string,
	-- OrderedDataStore name.
	store: string,
	-- How the value is shown: "cash" ($1.2M) or "number" (1.2M).
	format: "cash" | "number",
}

local boards: { Board } = {
	{ id = "TopEarned", stat = "totalEarned", store = "LB_TotalEarned_v1", format = "cash" },
	{ id = "TopRebirths", stat = "rebirths", store = "LB_Rebirths_v1", format = "number" },
	{ id = "TopSorted", stat = "sortedTotal", store = "LB_Sorted_v1", format = "number" },
}

return {
	boards = boards,
	entries = 10,
	-- Seconds between writes of a player's stats and between board refreshes.
	writeInterval = 120,
	refreshInterval = 90,
}
