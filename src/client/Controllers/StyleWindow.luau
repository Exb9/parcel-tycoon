--!strict
-- Style window (Windows.Style): the cosmetics the player owns, with a button to use or stop using each.
-- Cosmetics are bought in the Store (Styles tab).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Names = require(script.Parent.Parent.Lib.Names)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local StyleWindow = {}

local WINDOW = "Style"

local window: GuiObject? = nil
local slotById: { [string]: string } = {}
for _, item in Config.Cosmetics.items do
	slotById[item.id] = item.slot
end

local function isEquipped(cosmeticId: string): boolean
	local cosmetics = State.cosmetics()
	return cosmetics ~= nil and cosmetics.equipped[slotById[cosmeticId]] == cosmeticId
end

local function render()
	local cosmetics = State.cosmetics()
	if window == nil or cosmetics == nil or not Windows.isOpen(WINDOW) then
		return
	end
	local keys = {}
	for _, item in Config.Cosmetics.items do
		if cosmetics.owned[item.id] then
			table.insert(keys, item.id)
		end
	end
	Ui.list(Ui.find(window, "List"), keys, function(entry, cosmeticId)
		Ui.onActivated(Ui.button(entry, "Equip"), function()
			local slot = slotById[cosmeticId]
			Net.event(Net.Equip):FireServer(slot, if isEquipped(cosmeticId) then "" else cosmeticId)
		end)
	end, function(entry, cosmeticId)
		local equipped = isEquipped(cosmeticId)
		Ui.setText(entry, "Title", Names.cosmetic(cosmeticId))
		Ui.setText(entry, "Slot", Text.get(`style.{slotById[cosmeticId]}`))
		Ui.setText(entry, "Equip", Text.get(if equipped then "style.equipped" else "style.equip"))
		Ui.setVisible(entry, "Equipped", equipped)
	end)
	Ui.setVisible(window, "Empty", #keys == 0)
end

function StyleWindow.init()
	window = Windows.get(WINDOW)
	Windows.opened:Connect(function(name)
		if name == WINDOW then
			render()
		end
	end)
	State.watch({ "cosmetics" }, render)
	Text.changed:Connect(render)
end

return StyleWindow
