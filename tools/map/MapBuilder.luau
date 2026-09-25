--[[
	Placeholder map for Parcel Tycoon, following docs/MAP_CONTRACT.md.

	Runs in two places:
	  * Lune: `lune run tools/map/generate-place` builds place/ParcelTycoon.rbxlx with it.
	  * Roblox Studio: execute this whole file in the command bar or via the Studio MCP (Edit mode).
	    It replaces Workspace.Ground/Lobby/PlotSlots and ServerStorage.PlotTemplate, nothing else.

	Everything is plain parts so the Studio MCP can replace pieces with nicer models later; only the
	names, attributes and attachments listed in the contract matter to the code.
]]

local MapBuilder = {}

-- Belt geometry shared with tests/BeltSim.luau: 48-stud belts, sorters 12/20/28 studs along.
MapBuilder.BELT_LENGTH = 48
MapBuilder.SORTER_DISTANCES = { 12, 20, 28 }
MapBuilder.BELT_Z = { -10, 4, 18, 32 }
MapBuilder.PLOT_SIZE = { x = 96, z = 100 }

function MapBuilder.build(env: any, game: any)
	local Instance = env.Instance
	local Vector3 = env.Vector3
	local CFrame = env.CFrame
	local Color3 = env.Color3
	local Enum = env.Enum
	local UDim2 = env.UDim2

	local Workspace = game:GetService("Workspace")
	local ServerStorage = game:GetService("ServerStorage")
	local Lighting = game:GetService("Lighting")

	for _, name in { "Ground", "Lobby", "PlotSlots" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local oldTemplate = ServerStorage:FindFirstChild("PlotTemplate")
	if oldTemplate then
		oldTemplate:Destroy()
	end

	local function hex(value: string)
		return Color3.fromHex(value)
	end

	local function part(parent: any, name: string, size: any, cframe: any, color: string, props: { [string]: any }?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Anchored = true
		p.Color = hex(color)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if props then
			for key, value in props do
				p[key] = value
			end
		end
		p.Parent = parent
		return p
	end

	local function label(target: any, face: any, text: string, textColor: string)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Label"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		local text_ = Instance.new("TextLabel")
		text_.Size = UDim2.fromScale(1, 1)
		text_.BackgroundTransparency = 1
		text_.Text = text
		text_.TextScaled = true
		text_.Font = Enum.Font.GothamBlack
		text_.TextColor3 = hex(textColor)
		text_.Parent = gui
		gui.Parent = target
		return gui
	end

	local function folder(parent: any, name: string)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end

	-- Lighting --------------------------------------------------------------------------------------
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.GlobalShadows = true
	Lighting.Ambient = hex("#6E6E78")
	Lighting.OutdoorAmbient = hex("#8C8C96")
	-- Plots are small enough to keep everything loaded; the code never waits for streamed parts.
	pcall(function()
		Workspace.StreamingEnabled = false
	end)

	-- Ground ----------------------------------------------------------------------------------------
	part(Workspace, "Ground", Vector3.new(520, 1, 460), CFrame.new(0, -0.6, 0), "#7CB342", {
		Material = Enum.Material.Grass,
	})

	-- Lobby -----------------------------------------------------------------------------------------
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = Workspace
	part(lobby, "Floor", Vector3.new(100, 1, 100), CFrame.new(0, -0.45, 0), "#ECEFF1", {
		Material = Enum.Material.Concrete,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = hex("#FFB300")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby

	-- Paths from the lobby to both plot rows.
	part(lobby, "PathEast", Vector3.new(34, 0.2, 16), CFrame.new(66, 0.05, 0), "#B0BEC5")
	part(lobby, "PathWest", Vector3.new(34, 0.2, 16), CFrame.new(-66, 0.05, 0), "#B0BEC5")
	part(lobby, "PathEastRow", Vector3.new(16, 0.2, 320), CFrame.new(65, 0.04, 0), "#B0BEC5")
	part(lobby, "PathWestRow", Vector3.new(16, 0.2, 320), CFrame.new(-65, 0.04, 0), "#B0BEC5")

	-- Leaderboards face the spawn (their Front face points to +Z).
	local boards = folder(lobby, "Leaderboards")
	for index, id in { "TopEarned", "TopRebirths", "TopSorted" } do
		local x = (index - 2) * 26
		local board =
			part(boards, id, Vector3.new(16, 11, 1), CFrame.new(x, 7.5, -42) * CFrame.Angles(0, math.pi, 0), "#263238")
		part(boards, id .. "PostL", Vector3.new(1, 13, 1), CFrame.new(x - 8.5, 6.5, -42.2), "#37474F")
		part(boards, id .. "PostR", Vector3.new(1, 13, 1), CFrame.new(x + 8.5, 6.5, -42.2), "#37474F")
		board:SetAttribute("Board", id)
	end

	-- VIP lounge in the south of the lobby. Only VIP characters can pass the door.
	local vip = Instance.new("Model")
	vip.Name = "Vip"
	vip.Parent = lobby
	local vipGold = "#FFC400"
	part(vip, "Floor", Vector3.new(40, 0.2, 22), CFrame.new(0, 0.1, 37), "#4A148C")
	part(vip, "WallBack", Vector3.new(40, 10, 1), CFrame.new(0, 5, 48.5), "#311B92")
	part(vip, "WallLeft", Vector3.new(1, 10, 23), CFrame.new(-20.5, 5, 37), "#311B92")
	part(vip, "WallRight", Vector3.new(1, 10, 23), CFrame.new(20.5, 5, 37), "#311B92")
	part(vip, "WallFrontLeft", Vector3.new(16, 10, 1), CFrame.new(-12.5, 5, 25.5), "#311B92")
	part(vip, "WallFrontRight", Vector3.new(16, 10, 1), CFrame.new(12.5, 5, 25.5), "#311B92")
	local door = part(vip, "Door", Vector3.new(9, 10, 1), CFrame.new(0, 5, 25.5), vipGold, {
		Transparency = 0.35,
		Material = Enum.Material.ForceField,
	})
	door:SetAttribute("VipDoor", true)
	-- Front face (-Z) looks north, towards the spawn.
	local vipSign = part(vip, "Sign", Vector3.new(12, 3, 0.5), CFrame.new(0, 11.5, 25.2), "#311B92")
	label(vipSign, Enum.NormalId.Front, "VIP", vipGold)
	part(vip, "GiftPad", Vector3.new(7, 0.6, 7), CFrame.new(0, 0.4, 40), vipGold, {
		Material = Enum.Material.Neon,
	})

	-- Plot slots: three on each side of the lobby, entrances facing the lobby ---------------------
	local slots = folder(Workspace, "PlotSlots")
	local slotIndex = 0
	for _, side in { 1, -1 } do
		for _, z in { -110, 0, 110 } do
			slotIndex += 1
			local slot = part(
				slots,
				"Slot" .. slotIndex,
				Vector3.new(4, 1, 4),
				CFrame.new(side * 130, -0.5, z) * CFrame.Angles(0, side * math.pi / 2, 0),
				"#FF00FF",
				{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
			)
			slot:SetAttribute("SlotIndex", slotIndex)
		end
	end

	-- Plot template (built around the origin; the server clones it onto a slot) ---------------------
	local template = Instance.new("Model")
	template.Name = "PlotTemplate"

	local function themed(p: any, role: string)
		p:SetAttribute("ThemeRole", role)
		return p
	end

	local floor = themed(
		part(
			template,
			"Floor",
			Vector3.new(MapBuilder.PLOT_SIZE.x, 1, MapBuilder.PLOT_SIZE.z),
			CFrame.new(0, -0.5, 0),
			"#CFD8DC"
		),
		"floor"
	)
	template.PrimaryPart = floor

	local walls = folder(template, "Walls")
	local wallHeight = 10
	themed(part(walls, "Back", Vector3.new(96, wallHeight, 1), CFrame.new(0, wallHeight / 2, 50.5), "#FFF3E0"), "wall")
	themed(
		part(walls, "Left", Vector3.new(1, wallHeight, 102), CFrame.new(-48.5, wallHeight / 2, 0), "#FFF3E0"),
		"wall"
	)
	themed(
		part(walls, "Right", Vector3.new(1, wallHeight, 102), CFrame.new(48.5, wallHeight / 2, 0), "#FFF3E0"),
		"wall"
	)
	themed(
		part(walls, "FrontLeft", Vector3.new(36, wallHeight, 1), CFrame.new(-30, wallHeight / 2, -50.5), "#FFF3E0"),
		"wall"
	)
	themed(
		part(walls, "FrontRight", Vector3.new(36, wallHeight, 1), CFrame.new(30, wallHeight / 2, -50.5), "#FFF3E0"),
		"wall"
	)
	themed(part(walls, "TrimBack", Vector3.new(97, 1, 1.4), CFrame.new(0, wallHeight + 0.5, 50.5), "#FFB300"), "trim")
	themed(part(walls, "TrimLeft", Vector3.new(1.4, 1, 102), CFrame.new(-48.5, wallHeight + 0.5, 0), "#FFB300"), "trim")
	themed(part(walls, "TrimRight", Vector3.new(1.4, 1, 102), CFrame.new(48.5, wallHeight + 0.5, 0), "#FFB300"), "trim")
	themed(
		part(walls, "TrimFrontLeft", Vector3.new(36, 1, 1.4), CFrame.new(-30, wallHeight + 0.5, -50.5), "#FFB300"),
		"trim"
	)
	themed(
		part(walls, "TrimFrontRight", Vector3.new(36, 1, 1.4), CFrame.new(30, wallHeight + 0.5, -50.5), "#FFB300"),
		"trim"
	)

	-- Entrance area: spawn pad, owner sign, cash register.
	part(template, "OwnerSpawn", Vector3.new(6, 0.4, 6), CFrame.new(0, 0.2, -42), "#FFFFFF", {
		Transparency = 0.5,
		CanCollide = false,
	})
	-- Front face points out of the entrance, towards the lobby.
	local sign = themed(part(template, "OwnerSign", Vector3.new(24, 5, 1), CFrame.new(0, 13, -50.5), "#FFB300"), "trim")
	sign.CanCollide = false
	part(template, "SignPostL", Vector3.new(1, 15, 1), CFrame.new(-12.5, 7.5, -50.5), "#455A64")
	part(template, "SignPostR", Vector3.new(1, 15, 1), CFrame.new(12.5, 7.5, -50.5), "#455A64")

	part(template, "Collector", Vector3.new(7, 0.6, 7), CFrame.new(-30, 0.3, -35), "#43A047", {
		Material = Enum.Material.Neon,
	})
	part(template, "Register", Vector3.new(4, 3, 2.5), CFrame.new(-30, 2, -39.5), "#2E7D32")

	-- Exits: colored chute pads on the right side. Colors and labels come from the zone at runtime.
	local exits = folder(template, "Exits")
	for typeIndex, z in { -8, 10, 28 } do
		local exit = part(exits, "Exit" .. typeIndex, Vector3.new(9, 0.6, 9), CFrame.new(36, 0.3, z), "#9E9E9E", {
			Material = Enum.Material.Neon,
		})
		exit:SetAttribute("TypeIndex", typeIndex)
		themed(
			part(exits, "Arch" .. typeIndex .. "L", Vector3.new(1, 9, 1), CFrame.new(36, 4.5, z - 5), "#FFB300"),
			"trim"
		)
		themed(
			part(exits, "Arch" .. typeIndex .. "R", Vector3.new(1, 9, 1), CFrame.new(36, 4.5, z + 5), "#FFB300"),
			"trim"
		)
		local top = part(exits, "Arch" .. typeIndex .. "Top", Vector3.new(1, 3, 11), CFrame.new(36, 10, z), "#FFB300")
		top:SetAttribute("ExitLabel", typeIndex)
		themed(top, "trim")
	end

	-- Belts run along +X; the queue ends near the exits.
	local belts = folder(template, "Belts")
	local beltLength = MapBuilder.BELT_LENGTH
	local conveyorLength = beltLength + 2
	local beltStartX = -31
	local conveyorCenterX = beltStartX + beltLength / 2
	for beltIndex, z in MapBuilder.BELT_Z do
		local belt = Instance.new("Model")
		belt.Name = "Belt" .. beltIndex
		belt:SetAttribute("BeltIndex", beltIndex)
		belt.Parent = belts

		local conveyor = themed(
			part(belt, "Conveyor", Vector3.new(conveyorLength, 1, 4), CFrame.new(conveyorCenterX, 2.5, z), "#37474F"),
			"belt"
		)
		local start = Instance.new("Attachment")
		start.Name = "Start"
		start.CFrame = CFrame.new(-beltLength / 2, 0.5, 0)
		start.Parent = conveyor
		local finish = Instance.new("Attachment")
		finish.Name = "End"
		finish.CFrame = CFrame.new(beltLength / 2, 0.5, 0)
		finish.Parent = conveyor

		part(
			belt,
			"RailNear",
			Vector3.new(conveyorLength, 0.6, 0.4),
			CFrame.new(conveyorCenterX, 3.1, z - 2.2),
			"#78909C"
		)
		part(
			belt,
			"RailFar",
			Vector3.new(conveyorLength, 0.6, 0.4),
			CFrame.new(conveyorCenterX, 3.1, z + 2.2),
			"#78909C"
		)
		for legIndex = 0, 4 do
			local x = beltStartX + legIndex * beltLength / 4
			part(belt, "Leg" .. legIndex, Vector3.new(1, 2, 3), CFrame.new(x, 1, z), "#546E7A")
		end
		part(belt, "EndStop", Vector3.new(0.6, 1.2, 4.4), CFrame.new(beltStartX + beltLength + 0.8, 3.4, z), "#FFB300")

		-- Recycling bin at the queue start, far side.
		local queueStart = beltStartX + beltLength - 14
		part(belt, "Bin", Vector3.new(3.4, 2.6, 3), CFrame.new(queueStart - 1.5, 1.3, z + 4.2), "#43A047")

		-- Spawner chutes hanging above the start of the belt.
		local spawners = folder(belt, "Spawners")
		for spawnerIndex = 1, 3 do
			local x = beltStartX + 1.5 + (spawnerIndex - 1) * 3.6
			part(spawners, "Spawner" .. spawnerIndex, Vector3.new(3, 3, 3.4), CFrame.new(x, 7.5, z), "#FFB300")
		end

		-- Sorting machines on the far side; they appear once bought.
		local sorters = folder(belt, "Sorters")
		for typeIndex, distance in MapBuilder.SORTER_DISTANCES do
			local sorter = part(
				sorters,
				"Sorter" .. typeIndex,
				Vector3.new(4, 5, 3),
				CFrame.new(beltStartX + distance, 2.5, z + 4.5),
				"#90A4AE"
			)
			sorter:SetAttribute("TypeIndex", typeIndex)
		end
	end

	template.Parent = ServerStorage
	return template
end

-- Running inside Roblox Studio (command bar or Studio MCP): build into the open place.
if game ~= nil and typeof(game) == "Instance" then
	MapBuilder.build({
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = Enum,
		UDim2 = UDim2,
	}, game)
	print("[MapBuilder] Placeholder map built. Save the place to keep it.")
end

return MapBuilder
