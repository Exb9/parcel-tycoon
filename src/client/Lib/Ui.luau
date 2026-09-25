--!strict
-- Helpers for binding to the UI built in Studio via the Studio MCP (docs/UI_CONTRACT.md).
-- Everything is nil-safe: a missing element is reported once by `validate` and then skipped, so the
-- game keeps running while the UI is still being built.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sound = require(script.Parent.Sound)
local UiContract = require(ReplicatedStorage.Shared.UiContract)

local Ui = {}

-- Clones made by Ui.list carry this attribute (its value is the item key).
local LIST_ITEM = "ListItem"
local SCREEN_TIMEOUT = 8

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

-- Waits until the ScreenGuis from StarterGui have been copied into PlayerGui (at most SCREEN_TIMEOUT
-- seconds in total, so a UI that is not built yet does not hold up the rest of the game).
function Ui.waitForScreens()
	local deadline = os.clock() + SCREEN_TIMEOUT
	for _, element in UiContract.elements do
		local remaining = deadline - os.clock()
		if element.kind == "ScreenGui" and remaining > 0 then
			playerGui:WaitForChild(element.path, remaining)
		end
	end
end

function Ui.screen(name: string): ScreenGui?
	local screen = playerGui:FindFirstChild(name)
	if screen and screen:IsA("ScreenGui") then
		return screen
	end
	return nil
end

-- Finds a descendant by a slash-separated path, e.g. Ui.find(hud, "Menu/Shop").
function Ui.find(root: Instance?, path: string): Instance?
	local current = root
	for _, name in string.split(path, "/") do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

function Ui.object(root: Instance?, path: string): GuiObject?
	local found = Ui.find(root, path)
	if found and found:IsA("GuiObject") then
		return found
	end
	return nil
end

function Ui.button(root: Instance?, path: string): GuiButton?
	local found = Ui.find(root, path)
	if found and found:IsA("GuiButton") then
		return found
	end
	return nil
end

-- The label that shows an element's text: the element itself, or its TextLabel named "Text".
function Ui.textTarget(element: Instance?): (TextLabel | TextButton)?
	if element == nil then
		return nil
	end
	if element:IsA("TextLabel") or element:IsA("TextButton") then
		return element
	end
	local inner = element:FindFirstChild("Text", true)
	if inner and inner:IsA("TextLabel") then
		return inner
	end
	return nil
end

function Ui.setText(root: Instance?, path: string, text: string)
	local target: any = Ui.textTarget(Ui.find(root, path))
	if target and target.Text ~= text then
		target.Text = text
	end
end

function Ui.setVisible(root: Instance?, path: string, visible: boolean)
	local object = Ui.object(root, path)
	if object and object.Visible ~= visible then
		object.Visible = visible
	end
end

-- Width of a progress bar fill (0-1), keeping the height designed in Studio.
function Ui.setFill(root: Instance?, path: string, fraction: number)
	local fill = Ui.object(root, path)
	if fill then
		local size = fill.Size
		fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, size.Y.Scale, size.Y.Offset)
	end
end

-- Connects a button (with the click sound). Does nothing if the button is missing.
function Ui.onActivated(button: GuiButton?, handler: () -> ())
	if button == nil then
		return
	end
	button.Activated:Connect(function()
		Sound.play("click")
		handler()
	end)
end

-- Shows one clone of `container.Template` per key, in order. Existing clones are reused (their
-- connections stay), clones of keys that are gone are removed. `setup` runs once per new clone,
-- `render` on every call.
function Ui.list(
	container: Instance?,
	keys: { string },
	setup: ((item: GuiObject, key: string) -> ())?,
	render: (item: GuiObject, key: string, index: number) -> ()
)
	local template = container and container:FindFirstChild("Template")
	if container == nil or template == nil or not template:IsA("GuiObject") then
		return
	end
	template.Visible = false
	local existing: { [string]: GuiObject } = {}
	for _, child in container:GetChildren() do
		local key = child:GetAttribute(LIST_ITEM)
		if type(key) == "string" and child:IsA("GuiObject") then
			if table.find(keys, key) then
				existing[key] = child
			else
				child:Destroy()
			end
		end
	end
	for index, key in keys do
		local item: GuiObject? = existing[key]
		if item == nil then
			local clone = template:Clone()
			clone.Name = key
			clone:SetAttribute(LIST_ITEM, key)
			if setup then
				setup(clone, key)
			end
			clone.Parent = container
			item = clone
		end
		local shown = item :: GuiObject
		shown.LayoutOrder = index
		shown.Visible = true
		render(shown, key, index)
	end
end

local function matches(instance: Instance, kind: UiContract.Kind): boolean
	if kind == "ScreenGui" then
		return instance:IsA("ScreenGui")
	elseif kind == "Button" then
		return instance:IsA("GuiButton")
	elseif kind == "Frame" then
		return instance:IsA("GuiObject")
	elseif kind == "Text" then
		return Ui.textTarget(instance) ~= nil
	elseif kind == "Image" then
		return instance:IsA("ImageLabel") or instance:IsA("ImageButton")
	elseif kind == "TextBox" then
		return instance:IsA("TextBox")
	end
	return false
end

-- Reports every required element that is missing or of the wrong kind (docs/UI_CONTRACT.md).
function Ui.validate()
	local problems = {}
	for _, element in UiContract.elements do
		local found = Ui.find(playerGui, element.path)
		if found == nil then
			if not element.optional then
				table.insert(problems, `{element.path} ({element.kind}) is missing`)
			end
		elseif not matches(found, element.kind) then
			table.insert(problems, `{element.path} must be a {element.kind}`)
		elseif element.kind == "ScreenGui" and (found :: ScreenGui).ResetOnSpawn then
			table.insert(problems, `{element.path} needs ResetOnSpawn = false`)
		end
	end
	if #problems > 0 then
		warn("[UI] The UI does not match docs/UI_CONTRACT.md:\n[UI] " .. table.concat(problems, "\n[UI] "))
	end
end

return Ui
