--!strict
-- Shows the server's notices (Net.Notify) in PlayerGui.Toasts and plays their sounds.
-- "toast": small message in Toasts.Small (a few at once), "big": one at a time in Toasts.Big,
-- "silent": sound only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Lib.Sound)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)

local Toasts = {}

local SMALL_SECONDS = 2.5
local BIG_SECONDS = 3
local MAX_SMALL = 4

local screen: ScreenGui? = nil
local small: { GuiObject } = {}
local bigQueue: { string } = {}
local showingBig = false

local function clone(containerName: string, text: string): GuiObject?
	local container = Ui.object(screen, containerName)
	local template = Ui.object(container, "Template")
	if container == nil or template == nil then
		return nil
	end
	template.Visible = false
	local item = template:Clone()
	item.Name = "Toast"
	local label: any = Ui.textTarget(item)
	if label then
		label.Text = text
	end
	item.Visible = true
	item.Parent = container
	return item
end

local function showSmall(text: string)
	local item = clone("Small", text)
	if item == nil then
		return
	end
	table.insert(small, item)
	while #small > MAX_SMALL do
		local oldest = table.remove(small, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(SMALL_SECONDS, function()
		local index = table.find(small, item)
		if index then
			table.remove(small, index)
		end
		item:Destroy()
	end)
end

local function showNextBig()
	if showingBig or #bigQueue == 0 then
		return
	end
	showingBig = true
	local item = clone("Big", table.remove(bigQueue, 1) :: string)
	task.delay(BIG_SECONDS, function()
		if item then
			item:Destroy()
		end
		showingBig = false
		showNextBig()
	end)
end

-- Shows a text directly (for client-side messages).
function Toasts.show(text: string, style: string?, sound: string?)
	Sound.play(sound)
	if style == "silent" then
		return
	elseif style == "big" then
		table.insert(bigQueue, text)
		showNextBig()
	else
		showSmall(text)
	end
end

function Toasts.init()
	screen = Ui.screen("Toasts")
	Ui.setVisible(screen, "Small/Template", false)
	Ui.setVisible(screen, "Big/Template", false)
	Net.event(Net.Notify).OnClientEvent:Connect(function(notice: any)
		if type(notice) ~= "table" or type(notice.key) ~= "string" then
			return
		end
		local text = if notice.key ~= "" then Text.get(notice.key, Names.noticeArgs(notice.args)) else ""
		Toasts.show(text, if notice.key == "" then "silent" else notice.style, notice.sound)
	end)
end

return Toasts
