--!strict
-- The contract between what the local session builds in Studio via the Studio MCP (map, warehouse,
-- belts, machine models, placeholder parts, world UI) and the code. See docs/MAP_CONTRACT.md.
-- The server validates it at startup and reports problems in the output ("[Map] ...").
-- Uses only APIs that exist both in Roblox and in Lune's roblox library, so tests can run it on fixtures.

local Config = require("./Config")

local MapContract = {}

MapContract.TEMPLATE_NAME = "PlotTemplate"
MapContract.PACKAGE_TEMPLATE_NAME = "PackageTemplate"
MapContract.COSMETICS_FOLDER = "CosmeticTemplates"
MapContract.SLOTS_FOLDER = "PlotSlots"
MapContract.PLOTS_FOLDER = "Plots"
MapContract.LOBBY = "Lobby"
-- Attribute that marks parts a belt or warehouse skin recolors.
MapContract.SKIN_ATTRIBUTE = "SkinSlot"
-- A package that reached the end waits in this last stretch of the belt; machines must stand before it.
MapContract.END_STRETCH = 12

export type BeltLayout = {
	origin: Vector3,
	direction: Vector3,
	length: number,
}

local function isPart(instance: Instance?): boolean
	return instance ~= nil and instance:IsA("BasePart")
end

-- Machines and chutes may be a Part or a Model with a PrimaryPart.
local function anchorPart(instance: Instance?): BasePart?
	if instance == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart
	end
	return nil
end
MapContract.anchorPart = anchorPart

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

-- Distance along the belt of a part's center (e.g. a sorting machine).
function MapContract.distanceAlong(layout: BeltLayout, part: BasePart): number
	return (part.CFrame.Position - layout.origin):Dot(layout.direction)
end

local function findGuiChild(parent: Instance?, guiName: string, labelName: string): boolean
	local gui = parent and parent:FindFirstChild(guiName)
	local label = gui and gui:FindFirstChild(labelName, true)
	return label ~= nil and label:IsA("TextLabel")
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
	if not isPart(model:FindFirstChild("OwnerSpawn")) then
		problem("PlotTemplate.OwnerSpawn (Part) is missing")
	end
	local sign = model:FindFirstChild("OwnerSign")
	if not isPart(sign) then
		problem("PlotTemplate.OwnerSign (Part) is missing")
	elseif not findGuiChild(sign, "OwnerGui", "OwnerName") then
		problem("PlotTemplate.OwnerSign needs SurfaceGui OwnerGui with TextLabel OwnerName")
	end
	local collector = model:FindFirstChild("Collector")
	if not isPart(collector) then
		problem("PlotTemplate.Collector (Part) is missing")
	elseif not findGuiChild(collector, "CollectorGui", "Amount") then
		problem("PlotTemplate.Collector needs BillboardGui CollectorGui with TextLabel Amount")
	end

	local exits = model:FindFirstChild("Exits")
	for typeIndex = 1, 3 do
		local path = `PlotTemplate.Exits.Exit{typeIndex}`
		local exit = exits and exits:FindFirstChild(`Exit{typeIndex}`)
		if not isPart(exit) then
			problem(`{path} (Part) is missing`)
			continue
		end
		if (exit :: Instance):GetAttribute("TypeIndex") ~= typeIndex then
			problem(`{path} needs attribute TypeIndex = {typeIndex}`)
		end
		if not findGuiChild(exit, "ExitGui", "Destination") then
			problem(`{path} needs BillboardGui ExitGui with TextLabel Destination`)
		end
	end

	local belts = model:FindFirstChild("Belts")
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
			problem(`{path}.Conveyor needs Attachments named Start and End on its top surface`)
			continue
		end
		if layout.length < 30 then
			problem(`{path} is too short ({math.floor(layout.length)} studs from Start to End, needs 30+)`)
		end
		local spawners = beltInstance:FindFirstChild("Spawners")
		for spawnerIndex = 1, 3 do
			if anchorPart(spawners and spawners:FindFirstChild(`Spawner{spawnerIndex}`)) == nil then
				problem(`{path}.Spawners.Spawner{spawnerIndex} (Part or Model with PrimaryPart) is missing`)
			end
		end
		local sorters = beltInstance:FindFirstChild("Sorters")
		for typeIndex = 1, 3 do
			local sorter = sorters and sorters:FindFirstChild(`Sorter{typeIndex}`)
			local anchor = anchorPart(sorter)
			if anchor == nil then
				problem(`{path}.Sorters.Sorter{typeIndex} (Part or Model with PrimaryPart) is missing`)
				continue
			end
			if (sorter :: Instance):GetAttribute("TypeIndex") ~= typeIndex then
				problem(`{path}.Sorters.Sorter{typeIndex} needs attribute TypeIndex = {typeIndex}`)
			end
			local distance = MapContract.distanceAlong(layout, anchor)
			local latest = layout.length - MapContract.END_STRETCH
			if distance < 2 or distance > latest then
				problem(
					`{path}.Sorters.Sorter{typeIndex} sits {math.floor(distance)} studs along the belt; it must be between 2 and {math.floor(
						latest
					)} (the last {MapContract.END_STRETCH} studs are where parcels wait for the player)`
				)
			end
		end
	end
	return problems
end

-- Problems with the package template (optional: without it the server spawns plain parts).
function MapContract.validatePackageTemplate(template: Instance?): { string }
	if template == nil then
		return { `ServerStorage.{MapContract.PACKAGE_TEMPLATE_NAME} is missing (plain parts are used instead)` }
	end
	if not template:IsA("BasePart") then
		return { `{MapContract.PACKAGE_TEMPLATE_NAME} must be a Part` }
	end
	if not findGuiChild(template, "Label", "Destination") then
		return { `{MapContract.PACKAGE_TEMPLATE_NAME} needs SurfaceGui Label with TextLabel Destination` }
	end
	return {}
end

-- Problems with the cosmetic templates in ServerStorage.CosmeticTemplates (one Trail per trail cosmetic).
function MapContract.validateCosmeticTemplates(folder: Instance?): { string }
	local problems = {}
	for _, item in Config.Cosmetics.items do
		if item.slot ~= "trail" then
			continue
		end
		local trail = folder and folder:FindFirstChild(item.id)
		if trail == nil or not trail:IsA("Trail") then
			table.insert(problems, `ServerStorage.{MapContract.COSMETICS_FOLDER}.{item.id} (Trail) is missing`)
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
			elseif (slot :: Instance):GetAttribute("SlotIndex") ~= slotIndex then
				table.insert(
					problems,
					`Workspace.{MapContract.SLOTS_FOLDER}.Slot{slotIndex} needs attribute SlotIndex = {slotIndex}`
				)
			end
		end
	end
	local lobby = workspace:FindFirstChild(MapContract.LOBBY)
	if lobby == nil then
		table.insert(problems, "Workspace.Lobby is missing")
		return problems
	end
	if lobby:FindFirstChildWhichIsA("SpawnLocation", true) == nil then
		table.insert(problems, "Workspace.Lobby needs a SpawnLocation")
	end
	local boards = lobby:FindFirstChild("Leaderboards")
	for _, board in Config.Leaderboards.boards do
		local part = boards and boards:FindFirstChild(board.id)
		if not isPart(part) then
			table.insert(problems, `Workspace.Lobby.Leaderboards.{board.id} (Part) is missing`)
		else
			local path = `Workspace.Lobby.Leaderboards.{board.id}`
			local gui = (part :: Instance):FindFirstChild("Board")
			local rows = gui and gui:FindFirstChild("Rows", true)
			local template = rows and rows:FindFirstChild("RowTemplate")
			if gui == nil or not gui:IsA("SurfaceGui") or template == nil or not template:IsA("GuiObject") then
				table.insert(problems, `{path} needs SurfaceGui Board with Frame Rows > Frame RowTemplate`)
			else
				for _, labelName in { "Rank", "PlayerName", "Value" } do
					local label = (template :: Instance):FindFirstChild(labelName, true)
					if label == nil or not label:IsA("TextLabel") then
						table.insert(problems, `{path} RowTemplate needs TextLabel {labelName}`)
					end
				end
			end
		end
	end
	local vip = lobby:FindFirstChild("Vip")
	if not isPart(vip and vip:FindFirstChild("Door")) then
		table.insert(problems, "Workspace.Lobby.Vip.Door (Part) is missing")
	end
	return problems
end

return MapContract
