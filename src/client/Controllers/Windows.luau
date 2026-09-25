--!strict
-- Opens and closes the windows in PlayerGui.Windows (docs/UI_CONTRACT.md). One window is open at a
-- time; every window has a Close button. Tabs switch between lists inside a window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Ui = require(script.Parent.Parent.Lib.Ui)
local UiContract = require(ReplicatedStorage.Shared.UiContract)

local Windows = {}

-- Fires with the window name after it opened.
Windows.opened = Signal.new() :: Signal.Signal<string>

local screen: ScreenGui? = nil
local current: string? = nil

function Windows.get(name: string): GuiObject?
	return Ui.object(screen, name)
end

function Windows.isOpen(name: string): boolean
	return current == name
end

function Windows.close()
	if current then
		Ui.setVisible(screen, current, false)
		current = nil
	end
end

function Windows.open(name: string)
	if current == name then
		return
	end
	Windows.close()
	if Windows.get(name) == nil then
		return
	end
	Ui.setVisible(screen, name, true)
	current = name
	Windows.opened:Fire(name)
end

function Windows.toggle(name: string)
	if current == name then
		Windows.close()
	else
		Windows.open(name)
	end
end

-- Tabs: `<Tab>Tab` buttons show the matching `<Tab>` element and hide the others. Returns a function
-- that selects a tab from code.
function Windows.tabs(windowName: string, tabNames: { string }, onSelect: ((tabName: string) -> ())?): (string) -> ()
	local window = Windows.get(windowName)
	local function selectTab(selected: string)
		for _, tabName in tabNames do
			Ui.setVisible(window, tabName, tabName == selected)
			Ui.setVisible(window, `{tabName}Tab/Selected`, tabName == selected)
		end
		if onSelect then
			onSelect(selected)
		end
	end
	for _, tabName in tabNames do
		Ui.onActivated(Ui.button(window, `{tabName}Tab`), function()
			selectTab(tabName)
		end)
	end
	selectTab(tabNames[1])
	return selectTab
end

function Windows.init()
	screen = Ui.screen("Windows")
	for _, name in UiContract.windows do
		Ui.setVisible(screen, name, false)
		Ui.onActivated(Ui.button(screen, `{name}/Close`), Windows.close)
	end
end

return Windows
