--!strict
-- Client entry point. Every ModuleScript in Controllers/ is a controller with optional init() and start():
-- all init() run first (in name order, no yielding), then every start() runs in its own thread.
-- Controllers only send intents to the server; they never decide cash, purchases or sort results.
-- The UI they bind to is built in Studio via the Studio MCP (docs/UI_CONTRACT.md).

local State = require(script.Lib.State)
local Text = require(script.Lib.Text)
local Ui = require(script.Lib.Ui)

type Controller = {
	init: (() -> ())?,
	start: (() -> ())?,
}

Text.init()
Ui.waitForScreens()
Ui.validate()

local controllersFolder = script:FindFirstChild("Controllers")
local modules = if controllersFolder then controllersFolder:GetChildren() else {}
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

local controllers: { Controller } = {}
for _, module in modules do
	if module:IsA("ModuleScript") then
		table.insert(controllers, (require :: any)(module))
	end
end

for _, controller in controllers do
	if controller.init then
		controller.init()
	end
end

-- Screen texts built in Studio (TextKey attributes).
for _, name in { "HUD", "Windows", "Toasts" } do
	local screen = Ui.screen(name)
	if screen then
		Text.watch(screen)
	end
end

State.start()
task.spawn(Text.start)

for _, controller in controllers do
	if controller.start then
		task.spawn(controller.start)
	end
end
