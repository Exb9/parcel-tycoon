--!strict
-- The contract between the map built in Studio (tools/map/MapBuilder.luau, Studio MCP) and the code.
-- See docs/MAP_CONTRACT.md. Uses only APIs that exist both in Roblox and in Lune's roblox library,
-- so the tests can validate the generated place and the server can report problems at startup.

local Config = require("./Config")

local MapContract = {}

MapContract.TEMPLATE_NAME = "PlotTemplate"
MapContract.SLOTS_FOLDER = "PlotSlots"
MapContract.PLOTS_FOLDER = "Plots"
MapContract.LOBBY = "Lobby"
MapContract.THEME_ROLES = { "floor", "wall", "trim", "belt" }

export type BeltLayout = {
	origin: Vector3,
	direction: Vector3,
	length: number,
}

local function isPart(instance: Instance?): boolean
	return instance ~= nil and instance:IsA("BasePart")
end

-- World start point, direction and length of a belt from its Conveyor part.
function MapContract.beltLayout(conveyor: BasePart): BeltLayout?
	local start = conveyor:FindFirstChild("Start")
	local finish = conveyor:FindFirstChild("End")
	if not (start and start:IsA("Attachment") and finish and finish:IsA("Attachment")) then
		return nil
	end
	local origin = (conveyor.CFrame * start.CFrame).Position
	local target = (conveyor.CFrame * finish.CFrame).Position
	local offset = target - origin
	if offset.Magnitude < 1 then
		return nil
	end
	return { origin = origin, direction = offset.Unit, length = offset.Magnitude }
end

-- Distance along the belt of a part's center (e.g. a sorter).
function MapContract.distanceAlong(layout: BeltLayout, part: BasePart): number
	return (part.CFrame.Position - layout.origin):Dot(layout.direction)
end

-- Problems with the plot template; empty when it is usable.
function MapContract.validateTemplate(template: Instance?): { string }
	local problems = {}
	local function problem(text: string)
		table.insert(problems, text)
	end

	if template == nil then
		problem(`ServerStorage.{MapContract.TEMPLATE_NAME} is missing`)
		return problems
	end
	if not template:IsA("Model") then
		problem(`{MapContract.TEMPLATE_NAME} must be a Model`)
		return problems
	end
	local model = template :: Model
	local floor = model:FindFirstChild("Floor")
	if not isPart(floor) then
		problem("PlotTemplate.Floor (Part) is missing")
	elseif model.PrimaryPart ~= floor then
		problem("PlotTemplate.PrimaryPart must be Floor")
	end
	for _, name in { "OwnerSpawn", "OwnerSign", "Collector" } do
		if not isPart(model:FindFirstChild(name)) then
			problem(`PlotTemplate.{name} (Part) is missing`)
		end
	end

	local exits = model:FindFirstChild("Exits")
	for typeIndex = 1, 3 do
		local exit = exits and exits:FindFirstChild(`Exit{typeIndex}`)
		if not isPart(exit) then
			problem(`PlotTemplate.Exits.Exit{typeIndex} (Part) is missing`)
		elseif (exit :: Instance):GetAttribute("TypeIndex") ~= typeIndex then
			problem(`PlotTemplate.Exits.Exit{typeIndex} needs attribute TypeIndex = {typeIndex}`)
		end
	end

	local belts = model:FindFirstChild("Belts")
	local queueLength = Config.Gameplay.belt.queueLength
	local largestPackage = 0
	for _, packageType in Config.PackageTypes.types do
		largestPackage = math.max(largestPackage, packageType.size.z)
	end
	for beltIndex = 1, Config.Purchases.maxBelts do
		local path = `PlotTemplate.Belts.Belt{beltIndex}`
		local belt = belts and belts:FindFirstChild(`Belt{beltIndex}`)
		if belt == nil then
			problem(`{path} is missing`)
			continue
		end
		local beltInstance = belt :: Instance
		if beltInstance:GetAttribute("BeltIndex") ~= beltIndex then
			problem(`{path} needs attribute BeltIndex = {beltIndex}`)
		end
		local conveyor = beltInstance:FindFirstChild("Conveyor")
		if not isPart(conveyor) then
			problem(`{path}.Conveyor (Part) is missing`)
			continue
		end
		local layout = MapContract.beltLayout(conveyor :: BasePart)
		if layout == nil then
			problem(`{path}.Conveyor needs Attachments named Start and End`)
			continue
		end
		if layout.length < queueLength + 12 then
			problem(`{path} is too short ({math.floor(layout.length)} studs, needs {queueLength + 12})`)
		end
		if not isPart(beltInstance:FindFirstChild("Bin")) then
			problem(`{path}.Bin (Part) is missing`)
		end
		local spawners = beltInstance:FindFirstChild("Spawners")
		for spawnerIndex = 1, 3 do
			if not isPart(spawners and spawners:FindFirstChild(`Spawner{spawnerIndex}`)) then
				problem(`{path}.Spawners.Spawner{spawnerIndex} (Part) is missing`)
			end
		end
		local sorters = beltInstance:FindFirstChild("Sorters")
		for typeIndex = 1, 3 do
			local sorter = sorters and sorters:FindFirstChild(`Sorter{typeIndex}`)
			if not isPart(sorter) then
				problem(`{path}.Sorters.Sorter{typeIndex} (Part) is missing`)
				continue
			end
			local distance = MapContract.distanceAlong(layout, sorter :: BasePart)
			local latest = layout.length - queueLength - largestPackage - 1
			if distance < 2 or distance > latest then
				problem(
					`{path}.Sorters.Sorter{typeIndex} sits {math.floor(distance)} studs along the belt; it must be between 2 and {math.floor(
						latest
					)} so parcels pass it before the queue`
				)
			end
		end
	end
	return problems
end

-- Problems with the world (plot slots, lobby); empty when it is usable.
function MapContract.validateWorld(workspace: Instance): { string }
	local problems = {}
	local slots = workspace:FindFirstChild(MapContract.SLOTS_FOLDER)
	if slots == nil then
		table.insert(problems, `Workspace.{MapContract.SLOTS_FOLDER} is missing`)
	else
		for slotIndex = 1, Config.Gameplay.maxPlots do
			local slot = slots:FindFirstChild(`Slot{slotIndex}`)
			if not isPart(slot) then
				table.insert(problems, `Workspace.{MapContract.SLOTS_FOLDER}.Slot{slotIndex} (Part) is missing`)
			end
		end
	end
	local lobby = workspace:FindFirstChild(MapContract.LOBBY)
	if lobby == nil then
		table.insert(problems, "Workspace.Lobby is missing")
		return problems
	end
	if lobby:FindFirstChildWhichIsA("SpawnLocation") == nil then
		table.insert(problems, "Workspace.Lobby needs a SpawnLocation")
	end
	local boards = lobby:FindFirstChild("Leaderboards")
	for _, board in Config.Leaderboards.boards do
		if not isPart(boards and boards:FindFirstChild(board.id)) then
			table.insert(problems, `Workspace.Lobby.Leaderboards.{board.id} (Part) is missing`)
		end
	end
	local vip = lobby:FindFirstChild("Vip")
	for _, name in { "Door", "GiftPad" } do
		if not isPart(vip and vip:FindFirstChild(name)) then
			table.insert(problems, `Workspace.Lobby.Vip.{name} (Part) is missing`)
		end
	end
	return problems
end

return MapContract
