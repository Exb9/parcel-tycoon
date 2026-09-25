--!strict
-- World texts and hints on the map built in Studio (docs/MAP_CONTRACT.md):
--   * exit labels (ExitGui.Destination) show the destination of the package type the exit takes,
--   * the own cash register label (CollectorGui.Amount) shows how full it is,
--   * while carrying, the matching exit's optional Guide highlight lights up (only for the carrier),
--   * static world texts with a TextKey attribute (e.g. leaderboard titles) are translated,
--   * touching the VIP door without the VIP pass explains where to get it.
-- Parts can stream in and out, so everything is (re)applied when it appears.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Format)
local MapContract = require(ReplicatedStorage.Shared.MapContract)
local Names = require(script.Parent.Parent.Lib.Names)
local State = require(script.Parent.Parent.Lib.State)
local Text = require(script.Parent.Parent.Lib.Text)
local Toasts = require(script.Parent.Toasts)

local World = {}

local VIP_NOTICE_COOLDOWN = 5

local player = Players.LocalPlayer
local plotsFolder: Instance? = nil
local lastVipNotice = 0

local function ownPlot(): Instance?
	if plotsFolder == nil then
		return nil
	end
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Exit<N> parts of a plot by package type index.
local function exitsOf(plot: Instance): { [number]: BasePart }
	local exits = {}
	local folder = plot:FindFirstChild("Exits")
	if folder then
		for typeIndex = 1, 3 do
			local exit = folder:FindFirstChild(`Exit{typeIndex}`)
			if exit and exit:IsA("BasePart") then
				exits[typeIndex] = exit
			end
		end
	end
	return exits
end

local function labelExit(exit: BasePart)
	local typeId = exit:GetAttribute("PackageTypeId")
	local gui = exit:FindFirstChild("ExitGui")
	local label = gui and gui:FindFirstChild("Destination", true)
	if label and label:IsA("TextLabel") and type(typeId) == "string" then
		label.Text = Names.destination(typeId)
	end
end

local function watchExit(exit: BasePart)
	labelExit(exit)
	exit:GetAttributeChangedSignal("PackageTypeId"):Connect(function()
		labelExit(exit)
	end)
end

local function labelAllExits()
	if plotsFolder then
		for _, plot in plotsFolder:GetChildren() do
			for _, exit in exitsOf(plot) do
				labelExit(exit)
			end
		end
	end
end

local function renderCollector()
	local plot = ownPlot()
	local cash = State.cash()
	local collector = plot and plot:FindFirstChild("Collector")
	local gui = collector and collector:FindFirstChild("CollectorGui")
	local label = gui and gui:FindFirstChild("Amount", true)
	if cash == nil or label == nil or not label:IsA("TextLabel") then
		return
	end
	if cash.autoCollect then
		label.Text = ""
	elseif cash.collector >= cash.collectorCapacity then
		label.Text = Text.get("world.collectorFull")
	else
		label.Text = `{Format.cash(cash.collector)} / {Format.cash(cash.collectorCapacity)}`
	end
end

-- Lights up the exit the carried package belongs in (Exit<N>.Guide: a Highlight, ParticleEmitter or
-- Beam built in Studio; optional).
local function renderGuide()
	local plot = ownPlot()
	if plot == nil then
		return
	end
	local carrying = State.carrying()
	for typeIndex, exit in exitsOf(plot) do
		local guide = exit:FindFirstChild("Guide")
		if guide and (guide:IsA("Highlight") or guide:IsA("ParticleEmitter") or guide:IsA("Beam")) then
			(guide :: any).Enabled = carrying ~= nil and carrying.typeIndex == typeIndex
		end
	end
end

local function isVipDoor(part: BasePart): boolean
	local vip = part.Parent
	local lobby = vip and vip.Parent
	return part.Name == "Door" and vip ~= nil and vip.Name == "Vip" and lobby ~= nil and lobby.Name == MapContract.LOBBY
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Touched:Connect(function(hit: BasePart)
		if not isVipDoor(hit) or State.passes().vip then
			return
		end
		if os.clock() - lastVipNotice > VIP_NOTICE_COOLDOWN then
			lastVipNotice = os.clock()
			Toasts.show(Text.get("toast.vipOnly"), "toast", "wrong")
		end
	end)
end

function World.init()
	State.watch({ "cash" }, renderCollector)
	State.watch({ "carrying", "plot" }, renderGuide)
	Text.changed:Connect(function()
		labelAllExits()
		renderCollector()
	end)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function World.start()
	local lobby = Workspace:WaitForChild(MapContract.LOBBY, 30)
	if lobby then
		Text.watch(lobby)
	end
	local plots = Workspace:WaitForChild(MapContract.PLOTS_FOLDER, 30)
	if plots == nil then
		return
	end
	plotsFolder = plots
	Text.watch(plots)
	plots.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("BasePart") and string.match(descendant.Name, "^Exit%d$") then
			watchExit(descendant)
			renderGuide()
		elseif descendant.Name == "Collector" or descendant.Name == "CollectorGui" then
			renderCollector()
		end
	end)
	for _, plot in plots:GetChildren() do
		for _, exit in exitsOf(plot) do
			watchExit(exit)
		end
	end
	renderCollector()
	renderGuide()
end

return World
