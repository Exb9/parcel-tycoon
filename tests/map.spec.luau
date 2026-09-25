--!strict
local roblox = require("@lune/roblox")

local BeltSim = require("./BeltSim")
local Config = require("../src/shared/Config")
local MapBuilder = require("../tools/map/MapBuilder")
local MapContract = require("../src/shared/MapContract")
local Test = require("./Test")

local game = roblox.Instance.new("DataModel")
local template = MapBuilder.build(roblox, game)
local workspace = game:GetService("Workspace")

Test.test("placeholder template fulfils the map contract", function()
	local problems = MapContract.validateTemplate(template)
	Test.equal(#problems, 0, table.concat(problems, "; "))
end)

Test.test("placeholder world fulfils the map contract", function()
	local problems = MapContract.validateWorld(workspace)
	Test.equal(#problems, 0, table.concat(problems, "; "))
end)

Test.test("belt geometry matches the belt simulation", function()
	Test.equal(MapBuilder.BELT_LENGTH, BeltSim.BELT_LENGTH)
	for index, distance in MapBuilder.SORTER_DISTANCES do
		Test.equal(distance, BeltSim.SORTER_POSITIONS[index])
	end
	local belt = template.Belts.Belt1
	local layout = MapContract.beltLayout(belt.Conveyor)
	assert(layout, "belt layout")
	Test.near(layout.length, 48, 1e-6)
	for typeIndex = 1, 3 do
		local sorter = belt.Sorters:FindFirstChild(`Sorter{typeIndex}`)
		Test.near(MapContract.distanceAlong(layout, sorter), MapBuilder.SORTER_DISTANCES[typeIndex], 1e-6)
	end
end)

Test.test("plot slots do not overlap and face the lobby", function()
	local slots = workspace.PlotSlots:GetChildren()
	Test.equal(#slots, Config.Gameplay.maxPlots)
	for _, a in slots do
		for _, b in slots do
			if a ~= b then
				local dx = math.abs(a.CFrame.Position.X - b.CFrame.Position.X)
				local dz = math.abs(a.CFrame.Position.Z - b.CFrame.Position.Z)
				-- Plots are 96 wide (along world Z) and 100 deep (along world X).
				Test.truthy(dx >= 100 or dz >= 96, `{a.Name} overlaps {b.Name}`)
			end
		end
		-- The entrance (template -Z) must point towards the lobby at the origin.
		local entrance = a.CFrame:VectorToWorldSpace(roblox.Vector3.new(0, 0, -1))
		local towardsLobby = -a.CFrame.Position
		Test.truthy(entrance:Dot(towardsLobby) > 0, `{a.Name} faces away from the lobby`)
	end
end)

Test.test("contract validation reports missing parts", function()
	local broken = template:Clone()
	broken.Belts.Belt2.Sorters.Sorter3:Destroy()
	broken.Exits.Exit1:SetAttribute("TypeIndex", 5)
	local problems = MapContract.validateTemplate(broken)
	Test.equal(#problems, 2, table.concat(problems, "; "))
	Test.equal(#MapContract.validateTemplate(nil), 1)
end)
