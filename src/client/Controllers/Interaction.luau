--!strict
-- Picking up packages (decision "Sortieren = Tragen"): tap or click a package on your belt and the
-- avatar carries it; walking into the matching exit sorts it (checked by the server). A tap close to a
-- package also counts, because small parcels are hard to hit on a phone. Gamepads grab the nearest
-- package with ButtonX. The server validates distance, cooldown and ownership again.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MapContract = require(ReplicatedStorage.Shared.MapContract)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)

local Interaction = {}

local PACKAGE_TAG = "Package"
-- How far from the tapped point a package may be and still count as tapped.
local TAP_TOLERANCE = 3
local RAY_LENGTH = 500

local player = Players.LocalPlayer
local carry = Config.Gameplay.carry
local lastRequest = 0

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isMine(part: Instance): boolean
	return part:GetAttribute("Owner") == player.UserId and CollectionService:HasTag(part, PACKAGE_TAG)
end

local function inReach(part: BasePart): boolean
	local root = rootPart()
	return root ~= nil and (root.Position - part.Position).Magnitude <= carry.grabRange + carry.grabSlack
end

local function requestGrab(part: BasePart)
	if State.carrying() ~= nil or not inReach(part) or os.clock() - lastRequest < carry.grabCooldown then
		return
	end
	local id = part:GetAttribute("Id")
	if type(id) == "number" then
		lastRequest = os.clock()
		Net.event(Net.Grab):FireServer(id)
	end
end

-- The own package closest to `position`, within `maxDistance`.
local function nearestPackage(position: Vector3, maxDistance: number): BasePart?
	local best: BasePart? = nil
	local bestDistance = maxDistance
	for _, instance in CollectionService:GetTagged(PACKAGE_TAG) do
		if instance:IsA("BasePart") and isMine(instance) and instance:GetAttribute("Leave") == nil then
			local distance = (instance.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = instance, distance
			end
		end
	end
	return best
end

local function onScreenPoint(screenPosition: Vector2)
	local camera = Workspace.CurrentCamera
	local plots = Workspace:FindFirstChild(MapContract.PLOTS_FOLDER)
	if camera == nil or plots == nil or State.carrying() ~= nil then
		return
	end
	-- Input positions are in GUI space (below the top bar), which ScreenPointToRay expects.
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plots }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if result == nil then
		return
	end
	local hit = result.Instance
	if hit:IsA("BasePart") and isMine(hit) then
		requestGrab(hit)
		return
	end
	local nearest = nearestPackage(result.Position, TAP_TOLERANCE)
	if nearest then
		requestGrab(nearest)
	end
end

function Interaction.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onScreenPoint(Vector2.new(input.Position.X, input.Position.Y))
		elseif input.KeyCode == Enum.KeyCode.ButtonX then
			local root = rootPart()
			local nearest = root and nearestPackage(root.Position, carry.grabRange)
			if nearest then
				requestGrab(nearest)
			end
		end
	end)
	-- Taps only (not camera drags) on touch screens.
	UserInputService.TouchTap:Connect(function(positions, gameProcessed)
		if not gameProcessed and positions[1] then
			onScreenPoint(positions[1])
		end
	end)
end

return Interaction
