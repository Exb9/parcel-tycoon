--!strict
-- The contracts with what the local session builds in Studio via the Studio MCP:
--   * docs/UI_CONTRACT.md lists exactly the elements of src/shared/UiContract.luau,
--   * every TextKey the build specs ask for exists in the localization table,
--   * MapContract accepts a template that follows docs/MAP_CONTRACT.md and reports broken ones.
-- The instances below are an in-memory test fixture only; the real map is built in Studio.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Config = require("../src/shared/Config")
local Csv = require("./Csv")
local MapContract = require("../src/shared/MapContract")
local Test = require("./Test")
local UiContractDoc = require("../tools/lib/UiContractDoc")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

-- Docs -----------------------------------------------------------------------------------------------

Test.test("docs/UI_CONTRACT.md lists the current UI contract (lune run tools/ui-contract-doc)", function()
	local document = fs.readFile(UiContractDoc.DOC_PATH)
	Test.truthy(UiContractDoc.updated(document) == document, "element tree is out of date")
end)

Test.test("every TextKey in the build specs exists in the localization table", function()
	local keys = {}
	for _, row in Csv.read("src/localization/GameText.csv") do
		keys[row.Key] = true
	end
	local prefixes = {
		menu = true,
		hud = true,
		shop = true,
		store = true,
		quests = true,
		daily = true,
		rebirth = true,
		style = true,
		info = true,
		world = true,
		board = true,
		ads = true,
		club = true,
		group = true,
		welcome = true,
		offer = true,
		codes = true,
	}
	for _, path in { "docs/UI_CONTRACT.md", "docs/MAP_CONTRACT.md" } do
		local document = fs.readFile(path)
		for key in string.gmatch(document, "[`„]([a-z]+%.[%w%.]+)[`“]") do
			local prefix = string.match(key, "^(%a+)%.")
			if prefix and prefixes[prefix] then
				Test.truthy(keys[key], `{path} mentions TextKey {key}, which is not in GameText.csv`)
			end
		end
	end
end)

-- Map fixture ----------------------------------------------------------------------------------------

local function part(name: string, parent: any, position: any, size: any?): any
	local created = Instance.new("Part")
	created.Name = name
	created.Anchored = true
	created.Size = size or Vector3.new(4, 1, 4)
	created.CFrame = CFrame.new(position.X, position.Y, position.Z)
	created.Parent = parent
	return created
end

local function folder(name: string, parent: any): any
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local function gui(className: string, name: string, parent: any, labels: { string }): any
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	for _, labelName in labels do
		local label = Instance.new("TextLabel")
		label.Name = labelName
		label.Parent = created
	end
	return created
end

-- A plot template laid out like the reference layout in docs/MAP_CONTRACT.md.
local function buildTemplate(): any
	local model = Instance.new("Model")
	model.Name = MapContract.TEMPLATE_NAME
	local floor = part("Floor", model, Vector3.new(0, -0.5, 0), Vector3.new(96, 1, 100))
	model.PrimaryPart = floor
	part("OwnerSpawn", model, Vector3.new(0, 0.5, -40))
	gui("SurfaceGui", "OwnerGui", part("OwnerSign", model, Vector3.new(-30, 4, -50)), { "OwnerName" })
	gui("BillboardGui", "CollectorGui", part("Collector", model, Vector3.new(40, 0.5, -30)), { "Title", "Amount" })
	local exits = folder("Exits", model)
	for typeIndex, x in { -20, 0, 20 } do
		local exit = part(`Exit{typeIndex}`, exits, Vector3.new(x, 0.5, -22), Vector3.new(8, 1, 8))
		exit:SetAttribute("TypeIndex", typeIndex)
		gui("BillboardGui", "ExitGui", exit, { "Destination" })
	end
	local belts = folder("Belts", model)
	for beltIndex, x in { -18, -6, 6, 18 } do
		local belt = Instance.new("Model")
		belt.Name = `Belt{beltIndex}`
		belt:SetAttribute("BeltIndex", beltIndex)
		belt.Parent = belts
		-- 48 studs long, running from z = +40 (Start) to z = -8 (End).
		local conveyor = part("Conveyor", belt, Vector3.new(x, 0.5, 16), Vector3.new(4, 1, 48))
		for name, z in { Start = 24, End = -24 } do
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			attachment.CFrame = CFrame.new(0, 0.5, z)
			attachment.Parent = conveyor
		end
		local spawners = folder("Spawners", belt)
		for spawnerIndex = 1, 3 do
			part(`Spawner{spawnerIndex}`, spawners, Vector3.new(x + spawnerIndex - 2, 6, 42))
		end
		local sorters = folder("Sorters", belt)
		for typeIndex, z in { 28, 20, 12 } do
			local sorter = part(`Sorter{typeIndex}`, sorters, Vector3.new(x + 3.5, 2, z), Vector3.new(3, 4, 3))
			sorter:SetAttribute("TypeIndex", typeIndex)
		end
	end
	return model
end

local function buildWorld(): any
	local workspace = Instance.new("Folder")
	local slots = folder(MapContract.SLOTS_FOLDER, workspace)
	for slotIndex = 1, Config.Gameplay.maxPlots do
		local slot = part(`Slot{slotIndex}`, slots, Vector3.new(slotIndex * 130, 0, 130))
		slot:SetAttribute("SlotIndex", slotIndex)
	end
	local lobby = Instance.new("Model")
	lobby.Name = MapContract.LOBBY
	lobby.Parent = workspace
	local spawn = Instance.new("SpawnLocation")
	spawn.Parent = lobby
	local boards = folder("Leaderboards", lobby)
	for _, board in Config.Leaderboards.boards do
		local surface = gui("SurfaceGui", "Board", part(board.id, boards, Vector3.new(0, 8, 0)), { "Title" })
		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.Parent = surface
		gui("Frame", "RowTemplate", rows, { "Rank", "PlayerName", "Value" })
	end
	part("Door", folder("Vip", lobby), Vector3.new(30, 4, 0))
	return workspace
end

local function hasProblem(problems: { string }, fragment: string): boolean
	for _, problem in problems do
		if string.find(problem, fragment, 1, true) then
			return true
		end
	end
	return false
end

Test.test("a template following the reference layout passes the map contract", function()
	local problems = MapContract.validateTemplate(buildTemplate())
	Test.equal(#problems, 0, table.concat(problems, "; "))
end)

Test.test("the reference layout puts the machines at 12, 20 and 28 studs along a 48-stud belt", function()
	local template = buildTemplate()
	local belt = template.Belts.Belt1
	local layout = MapContract.beltLayout(belt.Conveyor)
	assert(layout, "belt layout")
	Test.near(layout.length, 48, 1e-6)
	for typeIndex, expected in { 12, 20, 28 } do
		Test.near(MapContract.distanceAlong(layout, belt.Sorters[`Sorter{typeIndex}`]), expected, 1e-6)
	end
end)

Test.test("broken templates are reported", function()
	local template = buildTemplate()
	template.Exits.Exit2:Destroy()
	template.Belts.Belt3:SetAttribute("BeltIndex", 7)
	-- Sorter3 of belt 1 moved into the last 12 studs, where parcels wait for the player.
	local sorter = template.Belts.Belt1.Sorters.Sorter3
	sorter.CFrame = CFrame.new(-14.5, 2, -4)
	local problems = MapContract.validateTemplate(template)
	Test.truthy(hasProblem(problems, "Exits.Exit2"), "missing exit")
	Test.truthy(hasProblem(problems, "BeltIndex = 3"), "wrong belt index")
	Test.truthy(hasProblem(problems, "Belt1.Sorters.Sorter3 sits"), "machine in the waiting area")
	Test.truthy(hasProblem(MapContract.validateTemplate(nil), "PlotTemplate is missing"), "missing template")
end)

Test.test("the world contract accepts a complete lobby and reports missing parts", function()
	local world = buildWorld()
	local problems = MapContract.validateWorld(world)
	Test.equal(#problems, 0, table.concat(problems, "; "))
	world.Lobby.Vip.Door:Destroy()
	world.Lobby.Leaderboards.TopSorted.Board.Rows.RowTemplate.Value:Destroy()
	problems = MapContract.validateWorld(world)
	Test.truthy(hasProblem(problems, "Vip.Door"), "missing VIP door")
	Test.truthy(hasProblem(problems, "TopSorted RowTemplate needs TextLabel Value"), "missing row label")
end)

Test.test("package and cosmetic templates are checked", function()
	local package = Instance.new("Part")
	gui("SurfaceGui", "Label", package, { "Destination", "Tag" })
	Test.equal(#MapContract.validatePackageTemplate(package), 0)
	Test.equal(#MapContract.validatePackageTemplate(Instance.new("Part")), 1)
	local cosmetics = Instance.new("Folder")
	local trails = {}
	for _, item in Config.Cosmetics.items do
		if item.slot == "trail" then
			table.insert(trails, item.id)
		end
	end
	Test.equal(#MapContract.validateCosmeticTemplates(cosmetics), #trails)
	for _, trailId in trails do
		local trail = Instance.new("Trail")
		trail.Name = trailId
		trail.Parent = cosmetics
	end
	Test.equal(#MapContract.validateCosmeticTemplates(cosmetics), 0)
end)
