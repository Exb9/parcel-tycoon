--!strict
-- Gives every player a warehouse: picks a free slot, clones ServerStorage.PlotTemplate (built in Studio
-- via the Studio MCP, docs/MAP_CONTRACT.md) onto it, shows only what the player has bought, colors the
-- exits to match the package types and applies belt/warehouse skins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Events = require(script.Parent.Parent.Lib.Events)
local MapContract = require(ReplicatedStorage.Shared.MapContract)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session
type Plot = Types.Plot
type BeltSlot = Types.BeltSlot

local PlotService = {
	priority = 30,
}

type Look = { color: Color3, material: Enum.Material }

local template: Model? = nil
local slots: { [number]: BasePart } = {}
local occupied: { [number]: Session } = {}
local plotsFolder: Folder
local stashRoot: Folder
-- Original look of skinnable parts, to restore when a skin is removed.
local originalLooks: { [BasePart]: Look } = {}

local cosmeticsById = {}
for _, item in Config.Cosmetics.items do
	cosmeticsById[item.id] = item
end

local function materialByName(name: string?): Enum.Material?
	if name == nil then
		return nil
	end
	local ok, material = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok then material else nil
end

local function child(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	assert(found, `{parent:GetFullName()}.{name} is missing (docs/MAP_CONTRACT.md)`)
	return found
end

local function part(parent: Instance, name: string): BasePart
	local found = child(parent, name)
	assert(found:IsA("BasePart"), `{found:GetFullName()} must be a Part`)
	return found
end

local function anchor(parent: Instance, name: string): (Instance, BasePart)
	local found = child(parent, name)
	local anchorPart = MapContract.anchorPart(found)
	assert(anchorPart, `{found:GetFullName()} must be a Part or a Model with a PrimaryPart`)
	return found, anchorPart
end

local function setShown(plot: Plot, instance: Instance, shown: boolean)
	if shown then
		local parent = plot.originalParents[instance]
		if parent and instance.Parent ~= parent then
			instance.Parent = parent
		end
	elseif instance.Parent ~= plot.stash then
		local known: Instance? = plot.originalParents[instance]
		if known == nil then
			plot.originalParents[instance] = instance.Parent :: Instance
		end
		instance.Parent = plot.stash
	end
end

local function buildBelts(model: Model): { BeltSlot }
	local belts = {}
	local beltsFolder = child(model, "Belts")
	for beltIndex = 1, Config.Purchases.maxBelts do
		local beltModel = child(beltsFolder, `Belt{beltIndex}`)
		assert(beltModel:IsA("Model"), `Belt{beltIndex} must be a Model`)
		local conveyor = part(beltModel, "Conveyor")
		local layout = MapContract.beltLayout(conveyor)
		assert(layout, `Belt{beltIndex}.Conveyor needs Start and End attachments`)
		local spawners = {}
		local spawnersFolder = child(beltModel, "Spawners")
		for spawnerIndex = 1, 3 do
			local spawner = anchor(spawnersFolder, `Spawner{spawnerIndex}`)
			table.insert(spawners, spawner)
		end
		local sorters, anchors, positions = {}, {}, {}
		local sortersFolder = child(beltModel, "Sorters")
		for typeIndex = 1, 3 do
			local sorter, sorterAnchor = anchor(sortersFolder, `Sorter{typeIndex}`)
			table.insert(sorters, sorter)
			table.insert(anchors, sorterAnchor)
			table.insert(positions, MapContract.distanceAlong(layout, sorterAnchor))
		end
		local packages = Instance.new("Folder")
		packages.Name = "Packages"
		packages.Parent = beltModel
		table.insert(belts, {
			index = beltIndex,
			model = beltModel,
			conveyor = conveyor,
			layout = layout,
			spawners = spawners,
			sorters = sorters,
			sorterAnchors = anchors,
			sorterPositions = positions,
			packages = packages,
		})
	end
	return belts
end

local function forEachSkinPart(plot: Plot, callback: (BasePart, string) -> ())
	for _, root in { plot.model :: Instance, plot.stash :: Instance } do
		for _, descendant in root:GetDescendants() do
			local slot = descendant:GetAttribute(MapContract.SKIN_ATTRIBUTE)
			if type(slot) == "string" and descendant:IsA("BasePart") then
				callback(descendant, slot)
			end
		end
	end
end

-- Exit colors (package types) and belt/warehouse skins.
function PlotService.applyLook(session: Session)
	local plot = session.plot
	if plot == nil then
		return
	end
	local data = session.data
	local equipped = data.cosmetics.equipped
	local skins = {
		belt = cosmeticsById[equipped.belt or ""],
		warehouse = cosmeticsById[equipped.warehouse or ""],
	}
	forEachSkinPart(plot, function(skinPart, slot)
		local original = originalLooks[skinPart]
		if original == nil then
			original = { color = skinPart.Color, material = skinPart.Material }
			originalLooks[skinPart] = original
		end
		local skin = (skins :: any)[slot]
		if skin then
			skinPart.Color = if skin.color then Color3.fromHex(skin.color) else original.color
			skinPart.Material = materialByName(skin.material) or original.material
		else
			skinPart.Color = original.color
			skinPart.Material = original.material
		end
	end)
	for typeIndex, exit in plot.exits do
		local packageType = Economy.packageTypeAt(data.progress.zone, typeIndex)
		if packageType then
			exit.Color = Color3.fromHex(packageType.color)
			exit:SetAttribute("PackageTypeId", packageType.id)
		end
	end
	plot.model:SetAttribute("Zone", data.progress.zone)
end

-- Shows the belts, chutes and machines the player owns.
function PlotService.applyVisibility(session: Session)
	local plot = session.plot
	if plot == nil then
		return
	end
	local progress = session.data.progress
	local activeBelts = Economy.activeBelts(progress)
	local spawnerCount = Economy.spawnerCount(progress)
	for _, belt in plot.belts do
		setShown(plot, belt.model, table.find(activeBelts, belt.index) ~= nil)
		for spawnerIndex, spawner in belt.spawners do
			setShown(plot, spawner, spawnerIndex <= spawnerCount)
		end
		for typeIndex, sorter in belt.sorters do
			setShown(plot, sorter, Economy.hasSorter(progress, belt.index, typeIndex))
		end
	end
end

function PlotService.refresh(session: Session)
	PlotService.applyVisibility(session)
	PlotService.applyLook(session)
end

local function writeSign(plot: Plot, player: Player)
	local gui = plot.sign:FindFirstChild("OwnerGui")
	local label = gui and gui:FindFirstChild("OwnerName", true)
	if label and label:IsA("TextLabel") then
		label.Text = player.DisplayName
	end
end

-- Moves the player's character onto their plot.
function PlotService.teleportHome(session: Session)
	local plot = session.plot
	local character = session.player.Character
	if plot == nil or character == nil then
		return
	end
	character:PivotTo(plot.ownerSpawn.CFrame * CFrame.new(0, 4, 0))
end

local function onCharacterAdded(session: Session, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root == nil or session.removed then
			return
		end
		-- Let the default spawn finish first, then move home.
		task.wait(0.1)
		if character.Parent ~= nil and session.player.Character == character then
			PlotService.teleportHome(session)
		end
	end)
end

local function assign(session: Session)
	if template == nil then
		warn("[Map] No plot template; the player stays in the lobby.")
		return
	end
	local slotIndex: number? = nil
	for index = 1, Config.Gameplay.maxPlots do
		if slots[index] and occupied[index] == nil then
			slotIndex = index
			break
		end
	end
	if slotIndex == nil then
		warn(`[Plots] No free plot for {session.player.Name}; add PlotSlots or lower max players.`)
		return
	end

	local model = template:Clone()
	model.Name = `Plot{slotIndex}`
	model:SetAttribute("OwnerUserId", session.userId)
	model:SetAttribute("SlotIndex", slotIndex)
	model:PivotTo(slots[slotIndex].CFrame)

	local stash = Instance.new("Folder")
	stash.Name = model.Name
	stash.Parent = stashRoot

	local exitsFolder = child(model, "Exits")
	local exits = {}
	for typeIndex = 1, 3 do
		table.insert(exits, part(exitsFolder, `Exit{typeIndex}`))
	end

	local plot: Plot = {
		slotIndex = slotIndex,
		model = model,
		belts = buildBelts(model),
		exits = exits,
		collector = part(model, "Collector"),
		ownerSpawn = part(model, "OwnerSpawn"),
		sign = part(model, "OwnerSign"),
		stash = stash,
		originalParents = {},
	}
	occupied[slotIndex] = session
	session.plot = plot

	writeSign(plot, session.player)
	PlotService.refresh(session)
	model.Parent = plotsFolder

	session.player.CharacterAdded:Connect(function(character)
		onCharacterAdded(session, character)
	end)
	if session.player.Character then
		onCharacterAdded(session, session.player.Character)
	end

	StateService.mark(session, "plot")
	Events.plotReady:Fire(session)
end

local function release(session: Session)
	local plot = session.plot
	if plot == nil then
		return
	end
	session.plot = nil
	occupied[plot.slotIndex] = nil
	for skinPart in originalLooks do
		if skinPart:IsDescendantOf(plot.model) or skinPart:IsDescendantOf(plot.stash) then
			originalLooks[skinPart] = nil
		end
	end
	plot.model:Destroy()
	plot.stash:Destroy()
end

function PlotService.init()
	local templateInstance = ServerStorage:FindFirstChild(MapContract.TEMPLATE_NAME)
	local problems = MapContract.validateTemplate(templateInstance)
	for _, problem in MapContract.validateWorld(Workspace) do
		table.insert(problems, problem)
	end
	for _, problem in
		MapContract.validatePackageTemplate(ServerStorage:FindFirstChild(MapContract.PACKAGE_TEMPLATE_NAME))
	do
		table.insert(problems, problem)
	end
	for _, problem in MapContract.validateCosmeticTemplates(ServerStorage:FindFirstChild(MapContract.COSMETICS_FOLDER)) do
		table.insert(problems, problem)
	end
	if #problems > 0 then
		warn("[Map] The map does not match docs/MAP_CONTRACT.md:\n[Map] " .. table.concat(problems, "\n[Map] "))
	end
	if templateInstance and templateInstance:IsA("Model") and #MapContract.validateTemplate(templateInstance) == 0 then
		template = templateInstance
	end

	local slotsFolder = Workspace:FindFirstChild(MapContract.SLOTS_FOLDER)
	if slotsFolder then
		for _, slot in slotsFolder:GetChildren() do
			local index = slot:GetAttribute("SlotIndex")
			if slot:IsA("BasePart") and type(index) == "number" then
				slots[index] = slot
			end
		end
	end

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = MapContract.PLOTS_FOLDER
	plotsFolder.Parent = Workspace
	stashRoot = Instance.new("Folder")
	stashRoot.Name = "PlotStash"
	stashRoot.Parent = ServerStorage

	Sessions.added:Connect(assign)
	Sessions.removing:Connect(release)
	Events.progressChanged:Connect(PlotService.refresh)
	Events.passesChanged:Connect(PlotService.refresh)
	Events.cosmeticsChanged:Connect(PlotService.applyLook)
end

return PlotService
