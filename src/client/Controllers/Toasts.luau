--!strict
-- Shows the server's notices (Net.Notify) in PlayerGui.Toasts and plays their sounds.
-- "toast": small message in Toasts.Small (a few at once), "big": one at a time in Toasts.Big,
-- "silent": sound only, "welcome": welcome-back window, "offer": offer popup.
-- "Not enough cash" gets an "Open Shop" link (optional Action button in the small toast template).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdsClient = require(script.Parent.Parent.Lib.AdsClient)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local OfferWindow = require(script.Parent.OfferWindow)
local Sound = require(script.Parent.Parent.Lib.Sound)
local StoreWindow = require(script.Parent.StoreWindow)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local WelcomeWindow = require(script.Parent.WelcomeWindow)

local Toasts = {}

local SMALL_SECONDS = 2.5
-- Longer when the toast has a button to press.
local ACTION_SECONDS = 4.5
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

type Action = { label: string, run: () -> () }

-- Link buttons for some notices.
local ACTIONS: { [string]: Action } = {
	["toast.notEnough"] = {
		label = "toast.shopHint",
		run = function()
			StoreWindow.show("Products")
		end,
	},
}

local function showSmall(text: string, action: Action?)
	local item = clone("Small", text)
	if item == nil then
		return
	end
	local button = Ui.button(item, "Action")
	if button then
		button.Visible = action ~= nil
		if action then
			Ui.setText(item, "Action", Text.get(action.label))
			Ui.onActivated(button, action.run)
		end
	end
	table.insert(small, item)
	while #small > MAX_SMALL do
		local oldest = table.remove(small, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(if action and button then ACTION_SECONDS else SMALL_SECONDS, function()
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
function Toasts.show(text: string, style: string?, sound: string?, action: Action?)
	Sound.play(sound)
	if style == "silent" then
		return
	elseif style == "big" then
		table.insert(bigQueue, text)
		showNextBig()
	else
		showSmall(text, action)
	end
end

function Toasts.init()
	screen = Ui.screen("Toasts")
	Ui.setVisible(screen, "Small/Template", false)
	Ui.setVisible(screen, "Big/Template", false)
	AdsClient.unavailable:Connect(function()
		Toasts.show(Text.get("toast.adUnavailable"), "toast", nil)
	end)
	Net.event(Net.Notify).OnClientEvent:Connect(function(notice: any)
		if type(notice) ~= "table" or type(notice.key) ~= "string" then
			return
		end
		local args = if type(notice.args) == "table" then notice.args else {}
		if notice.style == "offer" then
			OfferWindow.show(tostring(args.offerKind), tostring(args.offerKey))
			return
		elseif notice.style == "welcome" then
			if WelcomeWindow.show(tostring(args.amount)) then
				Sound.play(notice.sound)
				return
			end
			-- No window built yet: show the text as a big toast.
			Toasts.show(Text.get(notice.key, Names.noticeArgs(notice.args)), "big", notice.sound)
			return
		end
		local text = if notice.key ~= "" then Text.get(notice.key, Names.noticeArgs(notice.args)) else ""
		Toasts.show(text, if notice.key == "" then "silent" else notice.style, notice.sound, ACTIONS[notice.key])
	end)
end

return Toasts
