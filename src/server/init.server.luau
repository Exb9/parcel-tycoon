--!strict
-- Server entry point. Every ModuleScript in Services/ is a service with optional `priority` (lower
-- runs first, default 100), `init()` (synchronous setup) and `start()` (runs in its own thread).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

type Service = {
	priority: number?,
	init: (() -> ())?,
	start: (() -> ())?,
}

Net.setupServer()

local entries: { { name: string, service: Service } } = {}
local servicesFolder = script:FindFirstChild("Services")
if servicesFolder then
	for _, module in servicesFolder:GetChildren() do
		if module:IsA("ModuleScript") then
			table.insert(entries, { name = module.Name, service = (require :: any)(module) })
		end
	end
end
table.sort(entries, function(a, b)
	local pa, pb = a.service.priority or 100, b.service.priority or 100
	if pa ~= pb then
		return pa < pb
	end
	return a.name < b.name
end)

for _, entry in entries do
	local init = entry.service.init
	if init then
		init()
	end
end

for _, entry in entries do
	local start = entry.service.start
	if start then
		task.spawn(start)
	end
end
