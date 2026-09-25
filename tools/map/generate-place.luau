--[[
	Generates place/ParcelTycoon.rbxlx with the placeholder map (no code; Rojo syncs the code).

	    lune run tools/map/generate-place            -- refuses to overwrite an existing place
	    lune run tools/map/generate-place --force    -- rebuilds it (loses Studio edits to the map!)

	Once the place exists, the map is edited in Studio (Studio MCP) and saved there; this script is only
	for the initial placeholder or a deliberate reset.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local MapBuilder = require("./MapBuilder")
local MapContract = require("../../src/shared/MapContract")

local OUTPUT = "place/ParcelTycoon.rbxlx"

local force = table.find(process.args, "--force") ~= nil
if fs.isFile(OUTPUT) and not force then
	print(`{OUTPUT} already exists; pass --force to rebuild it (Studio edits to the map are lost).`)
	process.exit(1)
end

local game = roblox.Instance.new("DataModel")
local template = MapBuilder.build(roblox, game)

local problems = MapContract.validateTemplate(template)
for _, problem in MapContract.validateWorld(game:GetService("Workspace")) do
	table.insert(problems, problem)
end
if #problems > 0 then
	print("Map contract problems:\n  " .. table.concat(problems, "\n  "))
	process.exit(1)
end

if not fs.isDir("place") then
	fs.writeDir("place")
end
fs.writeFile(OUTPUT, roblox.serializePlace(game, true))
print(`Wrote {OUTPUT} ({#game:GetDescendants()} instances).`)
