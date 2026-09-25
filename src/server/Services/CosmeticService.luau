--!strict
-- Cosmetics (trails, belt, package and warehouse skins) and the VIP area door.
-- Styles come from gamepasses, the starter pack, the club subscription and rebirth milestones
-- (shared/Styles). Belt and warehouse skins are applied by PlotService, package skins by BeltService,
-- both when cosmeticsChanged fires. Trails are Studio-built templates in ServerStorage.CosmeticTemplates
-- (docs/MAP_CONTRACT.md).

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(script.Parent.Parent.Lib.Events)
local MapContract = require(ReplicatedStorage.Shared.MapContract)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Styles = require(ReplicatedStorage.Shared.Styles)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session
type Cosmetic = typeof(Config.Cosmetics.items[1])

local CosmeticService = {
	priority = 35,
}

local VIP_DOOR_GROUP = "VipDoor"
local VIP_PLAYER_GROUP = "VipPlayers"
local TRAIL_NAME = "CosmeticTrail"

local itemsById: { [string]: Cosmetic } = {}
for _, item in Config.Cosmetics.items do
	itemsById[item.id] = item
end

function CosmeticService.item(cosmeticId: string): Cosmetic?
	return itemsById[cosmeticId]
end

function CosmeticService.owns(session: Session, cosmeticId: string): boolean
	return Styles.owns(session.data.cosmetics.owned, session.passes, session.clubMember, cosmeticId)
end

local function applyTrail(session: Session)
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	for _, name in { TRAIL_NAME, "TrailTop", "TrailBottom" } do
		local existing = root:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	local item = itemsById[session.data.cosmetics.equipped.trail or ""]
	if item == nil then
		return
	end
	local templates = ServerStorage:FindFirstChild(MapContract.COSMETICS_FOLDER)
	local template = templates and templates:FindFirstChild(item.id)
	if template == nil or not template:IsA("Trail") then
		return
	end
	local function attachment(name: string, height: number): Attachment
		local created = Instance.new("Attachment")
		created.Name = name
		created.Position = Vector3.new(0, height, 0)
		created.Parent = root
		return created
	end
	local trail = template:Clone()
	trail.Name = TRAIL_NAME
	trail.Attachment0 = attachment("TrailTop", 1)
	trail.Attachment1 = attachment("TrailBottom", -1)
	trail.Parent = root
end

-- Uses a style the player owns (e.g. right after buying it).
function CosmeticService.equip(session: Session, cosmeticId: string)
	local item = itemsById[cosmeticId]
	if item == nil or not CosmeticService.owns(session, cosmeticId) then
		return
	end
	session.data.cosmetics.equipped[item.slot] = cosmeticId
	StateService.mark(session, "cosmetics")
	if item.slot == "trail" then
		applyTrail(session)
	end
	Events.cosmeticsChanged:Fire(session)
end

-- Unlocks a style for good (starter pack, rebirth milestones) and equips it. Returns true if it is new.
function CosmeticService.grant(session: Session, cosmeticId: string): boolean
	local item = itemsById[cosmeticId]
	if item == nil or CosmeticService.owns(session, cosmeticId) then
		return false
	end
	session.data.cosmetics.owned[cosmeticId] = true
	StateService.notify(session, "toast.cosmetic", { cosmeticId = cosmeticId }, "big", "reward")
	CosmeticService.equip(session, cosmeticId)
	return true
end

-- Stops using styles the player no longer owns. Called when the club subscription ended (passes are
-- loaded by then; calling it before the pass checks finished would drop pass styles).
function CosmeticService.dropUnowned(session: Session)
	local equipped = session.data.cosmetics.equipped
	local changed = false
	for slot, cosmeticId in equipped do
		if not CosmeticService.owns(session, cosmeticId) then
			equipped[slot] = nil
			changed = true
		end
	end
	StateService.mark(session, "cosmetics")
	if changed then
		applyTrail(session)
		Events.cosmeticsChanged:Fire(session)
	end
end

local function onEquip(player: Player, slot: any, cosmeticId: any)
	if not RateLimit.allow(player, "Equip", 4, 6) then
		return
	end
	local session = Sessions.get(player)
	if
		session == nil
		or type(slot) ~= "string"
		or type(cosmeticId) ~= "string"
		or table.find(Config.Cosmetics.slots, slot :: any) == nil
	then
		return
	end
	local equipped = session.data.cosmetics.equipped
	if cosmeticId == "" then
		equipped[slot] = nil
	else
		local item = itemsById[cosmeticId]
		if item == nil or item.slot ~= slot or not CosmeticService.owns(session, cosmeticId) then
			return
		end
		equipped[slot] = cosmeticId
	end
	StateService.mark(session, "cosmetics")
	if slot == "trail" then
		applyTrail(session)
	end
	Events.cosmeticsChanged:Fire(session)
end

-- VIP area (gamepass "VIP-Bereich"): VIP characters pass through Workspace.Lobby.Vip.Door.

local function characterGroup(session: Session): string
	return if session.passes.vip then VIP_PLAYER_GROUP else "Default"
end

local function setCharacterGroup(character: Model, group: string)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end

local function applyVip(session: Session)
	local character = session.player.Character
	if character then
		setCharacterGroup(character, characterGroup(session))
	end
end

local function setupVipDoor()
	PhysicsService:RegisterCollisionGroup(VIP_DOOR_GROUP)
	PhysicsService:RegisterCollisionGroup(VIP_PLAYER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(VIP_DOOR_GROUP, VIP_PLAYER_GROUP, false)
	local lobby = Workspace:FindFirstChild(MapContract.LOBBY)
	local vip = lobby and lobby:FindFirstChild("Vip")
	local door = vip and vip:FindFirstChild("Door")
	if door and door:IsA("BasePart") then
		door.CollisionGroup = VIP_DOOR_GROUP
	end
end

local function onCharacterAdded(session: Session, character: Model)
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = characterGroup(session)
		end
	end)
	setCharacterGroup(character, characterGroup(session))
	task.spawn(function()
		character:WaitForChild("HumanoidRootPart", 10)
		if not session.removed and session.player.Character == character then
			applyTrail(session)
		end
	end)
end

function CosmeticService.init()
	setupVipDoor()
	Net.event(Net.Equip).OnServerEvent:Connect(onEquip)

	Sessions.added:Connect(function(session)
		session.player.CharacterAdded:Connect(function(character)
			onCharacterAdded(session, character)
		end)
		if session.player.Character then
			onCharacterAdded(session, session.player.Character)
		end
	end)
	Events.passesChanged:Connect(applyVip)
end

return CosmeticService
