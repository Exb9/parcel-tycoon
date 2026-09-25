--!strict
-- The contract between the UI the local session builds in Studio via the Studio MCP (StarterGui) and
-- the client code, which only binds to these names. docs/UI_CONTRACT.md describes the same elements
-- for the builder (tests/contract.spec.luau keeps both in sync). The client checks the contract when it
-- starts and reports gaps in the output ("[UI] ...").
--
-- Kinds:
--   ScreenGui  a ScreenGui in StarterGui with ResetOnSpawn = false
--   Button     any GuiButton (TextButton or ImageButton)
--   Frame      any GuiObject (the code only toggles Visible or clones it)
--   Text       a TextLabel/TextButton, or a GuiObject with a TextLabel named "Text" inside; the code
--              writes its text
--   Image      an ImageLabel
-- Static texts (titles, button captions) are not listed: they get a TextKey attribute instead
-- (keys in src/localization/GameText.csv) and the client translates them.
-- Pure data, so Lune can load it.

export type Kind = "ScreenGui" | "Button" | "Frame" | "Text" | "Image"

export type Element = {
	-- Slash-separated path below PlayerGui (the ScreenGuis are copied there from StarterGui).
	path: string,
	kind: Kind,
	optional: boolean?,
}

local elements: { Element } = {}

local function add(path: string, kind: Kind, optional: boolean?)
	table.insert(elements, { path = path, kind = kind, optional = optional })
end

-- HUD ---------------------------------------------------------------------------------------------
add("HUD", "ScreenGui")
add("HUD/Cash", "Text")
add("HUD/Income", "Text")
add("HUD/Boost", "Text")
add("HUD/CarryHint", "Text")
add("HUD/CollectorFull", "Frame")
add("HUD/Menu", "Frame")
for _, name in { "Shop", "Store", "Quests", "Daily", "Rebirth", "Style", "Invite", "Info" } do
	add(`HUD/Menu/{name}`, "Button")
end
for _, name in { "Quests", "Daily", "Rebirth" } do
	add(`HUD/Menu/{name}/Badge`, "Frame", true)
end

-- Windows -----------------------------------------------------------------------------------------
add("Windows", "ScreenGui")

local function window(name: string)
	add(`Windows/{name}`, "Frame")
	add(`Windows/{name}/Close`, "Button")
end

local function tab(windowName: string, tabName: string)
	add(`Windows/{windowName}/{tabName}Tab`, "Button")
	add(`Windows/{windowName}/{tabName}Tab/Selected`, "Frame", true)
end

local function list(path: string, fields: { { name: string, kind: Kind, optional: boolean? } })
	add(path, "Frame")
	add(`{path}/Template`, "Frame")
	for _, field in fields do
		add(`{path}/Template/{field.name}`, field.kind, field.optional)
	end
end

window("Shop")
tab("Shop", "Upgrades")
tab("Shop", "Machines")
list("Windows/Shop/Upgrades", {
	{ name = "Title", kind = "Text" },
	{ name = "Description", kind = "Text" },
	{ name = "Level", kind = "Text" },
	{ name = "Price", kind = "Text" },
	{ name = "Buy", kind = "Button" },
	{ name = "Locked", kind = "Frame", optional = true },
})
list("Windows/Shop/Machines", {
	{ name = "Title", kind = "Text" },
	{ name = "Description", kind = "Text" },
	{ name = "Price", kind = "Text" },
	{ name = "Buy", kind = "Button" },
	{ name = "Locked", kind = "Frame", optional = true },
})
-- Inside the Machines list (after the items), shown when everything is built.
add("Windows/Shop/Machines/AllBuilt", "Frame")

window("Store")
tab("Store", "Passes")
tab("Store", "Products")
tab("Store", "Styles")
for _, name in { "Passes", "Products", "Styles" } do
	list(`Windows/Store/{name}`, {
		{ name = "Title", kind = "Text" },
		{ name = "Description", kind = "Text" },
		{ name = "Price", kind = "Text" },
		{ name = "Buy", kind = "Button" },
		{ name = "Icon", kind = "Image", optional = true },
		{ name = "Owned", kind = "Frame", optional = true },
	})
end

window("Quests")
list("Windows/Quests/List", {
	{ name = "Title", kind = "Text" },
	{ name = "Progress", kind = "Text" },
	{ name = "Bar", kind = "Frame" },
	{ name = "Bar/Fill", kind = "Frame" },
	{ name = "Reward", kind = "Text" },
	{ name = "Claim", kind = "Button" },
	{ name = "Done", kind = "Frame", optional = true },
})
add("Windows/Quests/ResetTimer", "Text")

window("Daily")
add("Windows/Daily/Days", "Frame")
for day = 1, 7 do
	add(`Windows/Daily/Days/Day{day}`, "Frame")
	add(`Windows/Daily/Days/Day{day}/Title`, "Text")
	add(`Windows/Daily/Days/Day{day}/Reward`, "Text")
	add(`Windows/Daily/Days/Day{day}/Claimed`, "Frame", true)
	add(`Windows/Daily/Days/Day{day}/Next`, "Frame", true)
end
add("Windows/Daily/Claim", "Button")
add("Windows/Daily/Status", "Text")

window("Rebirth")
add("Windows/Rebirth/Cost", "Text")
add("Windows/Rebirth/Bonus", "Text")
add("Windows/Rebirth/Confirm", "Button")
add("Windows/Rebirth/Bar", "Frame", true)
add("Windows/Rebirth/Bar/Fill", "Frame", true)

window("Style")
list("Windows/Style/List", {
	{ name = "Title", kind = "Text" },
	{ name = "Slot", kind = "Text" },
	{ name = "Equip", kind = "Button" },
	{ name = "Equipped", kind = "Frame", optional = true },
})
add("Windows/Style/Empty", "Frame")

window("Info")
list("Windows/Info/Odds", {
	{ name = "Title", kind = "Text" },
	{ name = "Chance", kind = "Text" },
})

-- Toasts ------------------------------------------------------------------------------------------
add("Toasts", "ScreenGui")
add("Toasts/Small", "Frame")
add("Toasts/Small/Template", "Text")
add("Toasts/Big", "Frame")
add("Toasts/Big/Template", "Text")

return {
	elements = elements,
	windows = { "Shop", "Store", "Quests", "Daily", "Rebirth", "Style", "Info" },
}
