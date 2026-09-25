--!strict
-- Server entry point. Every ModuleScript in Services/ is a service with optional init() and start():
-- all init() run first (in name order, no yielding), then every start() runs in its own thread.

type Service = {
	init: (() -> ())?,
	start: (() -> ())?,
}

local servicesFolder = script:FindFirstChild("Services")
local modules = if servicesFolder then servicesFolder:GetChildren() else {}
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

local services: { Service } = {}
for _, module in modules do
	if module:IsA("ModuleScript") then
		table.insert(services, (require :: any)(module))
	end
end

for _, service in services do
	if service.init then
		service.init()
	end
end

for _, service in services do
	if service.start then
		task.spawn(service.start)
	end
end
