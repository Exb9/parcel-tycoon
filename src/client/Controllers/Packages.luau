--!strict
-- Animates the packages on every belt locally. The server replicates a motion segment per package
-- (attributes D0, T0, Speed, Stop; shared/BeltQueue) and the client evaluates the same formula every
-- frame, so belts look smooth without physics or network traffic. Packages a machine takes get a short
-- "into the machine" animation (Leave, LeaveAt, LeaveTarget). Also fills the package labels.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BeltQueue = require(ReplicatedStorage.Shared.BeltQueue)
local Config = require(ReplicatedStorage.Shared.Config)
local MapContract = require(ReplicatedStorage.Shared.MapContract)
local Names = require(script.Parent.Parent.Lib.Names)
local Text = require(script.Parent.Parent.Lib.Text)

local Packages = {}

local PACKAGE_TAG = "Package"

type Tracked = {
	part: BasePart,
	layout: MapContract.BeltLayout,
	lift: number,
	-- Last distance along the belt that was applied (skip resting packages).
	shown: number,
}

local tracked: { [BasePart]: Tracked } = {}
local layouts: { [Instance]: MapContract.BeltLayout } = {}

-- Layout of the belt a package lies on: <Belt>/Packages/<part>, with <Belt>/Conveyor.
local function layoutFor(part: BasePart): MapContract.BeltLayout?
	local folder = part.Parent
	if folder == nil then
		return nil
	end
	local cached = layouts[folder]
	if cached then
		return cached
	end
	local belt = folder.Parent
	local conveyor = belt and belt:FindFirstChild("Conveyor")
	if conveyor == nil or not conveyor:IsA("BasePart") then
		return nil
	end
	local layout = MapContract.beltLayout(conveyor)
	if layout then
		layouts[folder] = layout
		folder.Destroying:Connect(function()
			layouts[folder] = nil
		end)
	end
	return layout
end

local function label(part: BasePart)
	local gui = part:FindFirstChild("Label")
	if gui == nil then
		return
	end
	local typeId = part:GetAttribute("TypeId")
	local destination = gui:FindFirstChild("Destination", true)
	if destination and destination:IsA("TextLabel") and type(typeId) == "string" then
		destination.Text = Names.destination(typeId)
	end
	local rare = part:GetAttribute("Rare")
	local tag = gui:FindFirstChild("Tag", true)
	if tag and tag:IsA("TextLabel") then
		local isRare = type(rare) == "string" and rare ~= ""
		tag.Visible = isRare
		if isRare then
			tag.Text = Text.get(`rare.{rare}`)
		end
	end
end

local function onAdded(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	label(instance)
	-- The part may arrive before its folder is parented; try again on the first frame.
	tracked[instance] = {
		part = instance,
		layout = layoutFor(instance) :: any,
		lift = instance.Size.Y / 2,
		shown = -1,
	}
end

local function onRemoved(instance: Instance)
	if instance:IsA("BasePart") then
		tracked[instance] = nil
	end
end

local function numberAttribute(part: BasePart, name: string): number?
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else nil
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local leaveSeconds = Config.Gameplay.belt.leaveSeconds
	for part, entry in tracked do
		if entry.layout == nil then
			entry.layout = layoutFor(part) :: any
			if entry.layout == nil then
				continue
			end
		end
		local d0 = numberAttribute(part, "D0")
		local t0 = numberAttribute(part, "T0")
		local speed = numberAttribute(part, "Speed")
		local stop = numberAttribute(part, "Stop")
		if d0 == nil or t0 == nil or speed == nil or stop == nil then
			continue
		end
		local layout = entry.layout
		local item: BeltQueue.Item = { id = 0, length = 0, d0 = d0, t0 = t0, speed = speed, stop = stop }
		local leaveAt = numberAttribute(part, "LeaveAt")
		local distance = BeltQueue.distanceAt(item, leaveAt or now)
		local position = layout.origin + layout.direction * distance + Vector3.new(0, entry.lift, 0)
		if leaveAt then
			local target = part:GetAttribute("LeaveTarget")
			if typeof(target) == "Vector3" then
				local alpha = math.clamp((now - leaveAt) / leaveSeconds, 0, 1)
				position = position:Lerp(target, alpha)
				table.insert(parts, part)
				table.insert(cframes, CFrame.lookAt(position, position + layout.direction))
			end
			continue
		end
		if math.abs(distance - entry.shown) > 1e-3 then
			entry.shown = distance
			table.insert(parts, part)
			table.insert(cframes, CFrame.lookAt(position, position + layout.direction))
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Packages.init()
	CollectionService:GetInstanceAddedSignal(PACKAGE_TAG):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(PACKAGE_TAG):Connect(onRemoved)
	for _, instance in CollectionService:GetTagged(PACKAGE_TAG) do
		onAdded(instance)
	end
	Text.changed:Connect(function()
		for part in tracked do
			label(part)
		end
	end)
end

function Packages.start()
	RunService.RenderStepped:Connect(step)
end

return Packages
