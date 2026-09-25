--!strict
-- Lune test runner: `lune run tests` (from the repo root) executes every *.spec.luau in this folder.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Test = require("@self/Test")

local specs = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(specs, (string.gsub(name, "%.luau$", "")))
	end
end
table.sort(specs)

local failures = 0
for _, spec in specs do
	print(spec)
	require(`@self/{spec}`)
	failures += Test.run()
end

process.exit(if failures == 0 then 0 else 1)
