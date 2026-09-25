--!strict
-- Belts, packages, sorting machines, carrying, exits, the cash register and fragile packages.
--
-- Package motion follows the shared BeltQueue model: the server keeps the authoritative line-up and
-- replicates a few attributes per package (D0, T0, Speed, Stop); clients animate the parts locally.
-- The server never trusts client positions: grab checks use the server's own formula.
-- When a belt is full the chute pauses (decision 25.09.2026); nothing is thrown away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BeltQueue = require(ReplicatedStorage.Shared.BeltQueue)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local MapContract = require(ReplicatedStorage.Shared.MapContract)
local Net = require(ReplicatedStorage.Shared.Net)
local PackageRoll = require(ReplicatedStorage.Shared.PackageRoll)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session
type BeltSlot = Types.BeltSlot

local BeltService = {
	priority = 50,
}

local PACKAGE_TAG = "Package"
local COLLECTOR_FULL_NOTICE_SECONDS = 60
local COLLECT_INTERVAL = 0.4

local beltConfig = Config.Gameplay.belt
local carryConfig = Config.Gameplay.carry

type Payload = {
	typeIndex: number,
	typeId: string,
	rare: string?,
	part: BasePart,
	-- Half the package height: its center sits this far above the belt surface.
	lift: number,
}

type SorterState = {
	typeIndex: number,
	position: number,
	anchor: BasePart,
	tokens: number,
}

type BeltState = {
	slot: BeltSlot,
	queue: BeltQueue.Belt,
	credit: number,
	nextRoll: PackageRoll.Roll?,
	sorters: { SorterState },
}

type PlotState = {
	session: Session,
	belts: { [number]: BeltState },
	byId: { [number]: { belt: BeltState, item: BeltQueue.Item } },
	supply: number,
	speed: number,
	sorterRate: number,
	accuracy: number,
	lastCollectorNotice: number,
	lastCollect: number,
}

local plots: { [Session]: PlotState } = {}
local nextPackageId = 0
local random = Random.new()
local carriedFolder: Folder
local packageTemplate: BasePart? = nil

local cosmeticsById = {}
for _, item in Config.Cosmetics.items do
	cosmeticsById[item.id] = item
end

local function randomNumber(): number
	return random:NextNumber()
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function rootPart(session: Session): BasePart?
	local character = session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Replication of the belt model ------------------------------------------------------------------

local function replicate(items: { BeltQueue.Item })
	for _, item in items do
		local part = (item.payload :: Payload).part
		part:SetAttribute("D0", item.d0)
		part:SetAttribute("T0", item.t0)
		part:SetAttribute("Speed", item.speed)
		part:SetAttribute("Stop", item.stop)
	end
end

local function removeFromBelt(state: PlotState, belt: BeltState, item: BeltQueue.Item, now: number)
	state.byId[item.id] = nil
	replicate(BeltQueue.remove(belt.queue, item, now))
end

-- Belts --------------------------------------------------------------------------------------------

local function newBeltState(slot: BeltSlot, speed: number): BeltState
	return {
		slot = slot,
		queue = BeltQueue.new(slot.layout.length, beltConfig.gap, speed, beltConfig.maxPackages),
		credit = 0,
		nextRoll = nil,
		sorters = {},
	}
end

local function clearBelt(state: PlotState, belt: BeltState)
	for _, item in belt.queue.items do
		state.byId[item.id] = nil
		(item.payload :: Payload).part:Destroy()
	end
	table.clear(belt.queue.items)
	belt.credit = 0
	belt.nextRoll = nil
end

local function refreshRates(state: PlotState)
	local session = state.session
	local progress = session.data.progress
	state.supply = Economy.supplyPerBelt(progress, session.passes)
	state.sorterRate = Economy.sorterRate(progress)
	state.accuracy = Economy.sorterAccuracy(progress)
	local speed = Economy.beltSpeed(progress, session.passes)
	if math.abs(speed - state.speed) > 1e-6 then
		state.speed = speed
		local now = serverNow()
		for _, belt in state.belts do
			replicate(BeltQueue.setSpeed(belt.queue, speed, now))
		end
	end
end

-- Creates or removes belt states to match the purchases, and sets up the owned sorting machines.
local function syncBelts(state: PlotState)
	local session = state.session
	local plot = session.plot
	if plot == nil then
		return
	end
	local progress = session.data.progress
	local active = Economy.activeBelts(progress)
	for _, beltIndex in active do
		if state.belts[beltIndex] == nil and plot.belts[beltIndex] then
			state.belts[beltIndex] = newBeltState(plot.belts[beltIndex], state.speed)
		end
	end
	for beltIndex, belt in state.belts do
		if table.find(active, beltIndex) == nil then
			clearBelt(state, belt)
			state.belts[beltIndex] = nil
		end
	end
	for beltIndex, belt in state.belts do
		local sorters = {}
		for typeIndex = 1, 3 do
			if Economy.hasSorter(progress, beltIndex, typeIndex) then
				local existing: SorterState? = nil
				for _, sorter in belt.sorters do
					if sorter.typeIndex == typeIndex then
						existing = sorter
					end
				end
				table.insert(sorters, existing or {
					typeIndex = typeIndex,
					position = belt.slot.sorterPositions[typeIndex],
					anchor = belt.slot.sorterAnchors[typeIndex],
					tokens = beltConfig.sorterBuffer,
				})
			end
		end
		belt.sorters = sorters
	end
end

local function newPackagePart(session: Session, size: Vector3, color: Color3, rare: string?): BasePart
	local part: BasePart
	if packageTemplate then
		part = packageTemplate:Clone()
		-- The template carries the rare looks as children named after the rare ids (golden, fragile,
		-- mystery); keep only the one this package needs.
		for _, variant in Config.PackageTypes.rareVariants do
			local look = part:FindFirstChild(variant.id)
			if look and variant.id ~= rare then
				look:Destroy()
			end
		end
	else
		local plain = Instance.new("Part")
		plain.Material = Enum.Material.SmoothPlastic
		plain.TopSurface = Enum.SurfaceType.Smooth
		plain.BottomSurface = Enum.SurfaceType.Smooth
		part = plain
	end
	part.Name = "Package"
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	local skin = cosmeticsById[session.data.cosmetics.equipped.package or ""]
	if skin and skin.material then
		local ok, material = pcall(function()
			return (Enum.Material :: any)[skin.material]
		end)
		if ok and material then
			part.Material = material
		end
	end
	return part
end

local function spawnPackage(state: PlotState, belt: BeltState, roll: PackageRoll.Roll, now: number): boolean
	local session = state.session
	local packageType = Economy.packageTypeAt(session.data.progress.zone, roll.typeIndex)
	if packageType == nil then
		return false
	end
	local size = Vector3.new(packageType.size.x, packageType.size.y, packageType.size.z)
	if not BeltQueue.canSpawn(belt.queue, size.Z, now) then
		return false
	end

	nextPackageId += 1
	local id = nextPackageId
	local layout = belt.slot.layout
	local lift = size.Y / 2
	local position = layout.origin + layout.direction * (size.Z / 2) + Vector3.new(0, lift, 0)

	local part = newPackagePart(session, size, Color3.fromHex(packageType.color), roll.rare)
	part.CFrame = CFrame.lookAt(position, position + layout.direction)
	part:SetAttribute("Id", id)
	part:SetAttribute("Owner", session.userId)
	part:SetAttribute("TypeIndex", roll.typeIndex)
	part:SetAttribute("TypeId", packageType.id)
	part:SetAttribute("Rare", roll.rare or "")

	local payload: Payload = {
		typeIndex = roll.typeIndex,
		typeId = packageType.id,
		rare = roll.rare,
		part = part,
		lift = lift,
	}
	local item, changed = BeltQueue.spawn(belt.queue, id, size.Z, payload, now)
	replicate(changed)
	part:AddTag(PACKAGE_TAG)
	part.Parent = belt.slot.packages
	state.byId[id] = { belt = belt, item = item }
	return true
end

local function machineSort(state: PlotState, belt: BeltState, sorter: SorterState, item: BeltQueue.Item, now: number)
	local session = state.session
	local payload = item.payload :: Payload
	local data = session.data
	local packageType = Economy.packageTypeAt(data.progress.zone, payload.typeIndex)
	removeFromBelt(state, belt, item, now)
	local part = payload.part
	-- Clients play a short "into the machine" animation, then the part is removed.
	part:SetAttribute("Leave", "sorted")
	part:SetAttribute("LeaveAt", now)
	part:SetAttribute("LeaveTarget", sorter.anchor.Position)
	task.delay(beltConfig.leaveSeconds, function()
		part:Destroy()
	end)
	if packageType == nil then
		return
	end
	local value = 0
	if randomNumber() < state.accuracy then
		value = Economy.packageValue(data.progress, packageType) * EconomyService.cashMultiplier(session)
		EconomyService.depositMachine(session, value)
		data.stats.sortedMachine += 1
		data.stats.sortedTotal += 1
	end
	Events.packageSorted:Fire(session, {
		manual = false,
		typeIndex = payload.typeIndex,
		rare = nil,
		value = value,
	})
end

local function stepBelt(state: PlotState, belt: BeltState, dt: number, now: number, collectorFull: boolean)
	local session = state.session

	-- Spawning: the chute pauses while there is no room at the start of the belt.
	belt.credit = math.min(belt.credit + state.supply / 60 * dt, 1.5)
	if belt.credit >= 1 then
		local roll = belt.nextRoll or PackageRoll.roll(session.data.progress.zone, randomNumber)
		belt.nextRoll = roll
		if spawnPackage(state, belt, roll, now) then
			belt.credit -= 1
			belt.nextRoll = nil
		end
	end

	-- Sorting machines take a matching package that passes or waits in front of them.
	for _, sorter in belt.sorters do
		sorter.tokens = math.min(beltConfig.sorterBuffer, sorter.tokens + state.sorterRate / 60 * dt)
		if sorter.tokens < 1 then
			continue
		end
		local reach = beltConfig.sorterReach
		for _, item in BeltQueue.inRange(belt.queue, now, sorter.position - reach, sorter.position + reach) do
			local payload = item.payload :: Payload
			local rare = if payload.rare then Economy.findRare(payload.rare) else nil
			if payload.typeIndex == sorter.typeIndex and (rare == nil or rare.machinesCanSort) then
				if collectorFull then
					if os.clock() - state.lastCollectorNotice > COLLECTOR_FULL_NOTICE_SECONDS then
						state.lastCollectorNotice = os.clock()
						StateService.notify(session, "toast.collectorFull", nil, "toast", "wrong")
					end
				else
					sorter.tokens -= 1
					machineSort(state, belt, sorter, item, now)
				end
				break
			end
		end
	end
end

-- Carrying -----------------------------------------------------------------------------------------

-- Ends carrying (the part is destroyed).
local function releaseCarry(session: Session)
	local carry = session.carrying
	if carry == nil then
		return
	end
	session.carrying = nil
	carry.part:Destroy()
	StateService.mark(session, "carrying")
end

local function attach(session: Session, id: number, payload: Payload, root: BasePart, position: Vector3)
	local part = payload.part
	part:SetAttribute("Carrier", session.userId)
	part:RemoveTag(PACKAGE_TAG)
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = root.CFrame * CFrame.new(0, 0.6, -(part.Size.Z / 2 + 1.3))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = carriedFolder

	session.carrying = {
		id = id,
		typeIndex = payload.typeIndex,
		typeId = payload.typeId,
		rare = payload.rare,
		part = part,
		grabbedAt = serverNow(),
		grabPosition = position,
	}
	StateService.mark(session, "carrying")
	StateService.notify(session, "", nil, "silent", "grab")
	Events.packageGrabbed:Fire(session)
end

local function onGrab(player: Player, packageId: any)
	if not RateLimit.allow(player, "Grab", 8, 8) then
		return
	end
	local session = Sessions.get(player)
	if session == nil or type(packageId) ~= "number" or session.carrying ~= nil then
		return
	end
	local state = plots[session]
	local root = rootPart(session)
	if state == nil or root == nil then
		return
	end
	if os.clock() - session.lastGrab < carryConfig.grabCooldown then
		return
	end
	local entry = state.byId[packageId]
	if entry == nil then
		return
	end
	local now = serverNow()
	local item = entry.item
	local payload = item.payload :: Payload
	local layout = entry.belt.slot.layout
	local position = layout.origin
		+ layout.direction * BeltQueue.distanceAt(item, now)
		+ Vector3.new(0, payload.lift, 0)
	if (root.Position - position).Magnitude > carryConfig.grabRange + carryConfig.grabSlack then
		return
	end
	session.lastGrab = os.clock()
	removeFromBelt(state, entry.belt, item, now)
	attach(session, item.id, payload, root, position)
end

local function sortCarried(session: Session, exit: BasePart, exitTypeIndex: number)
	local carry = session.carrying
	if carry == nil then
		return
	end
	local data = session.data
	local packageType = Economy.packageTypeAt(data.progress.zone, carry.typeIndex)
	if packageType == nil then
		releaseCarry(session)
		return
	end
	local value = Economy.packageValue(data.progress, packageType) * EconomyService.cashMultiplier(session)

	if exitTypeIndex ~= carry.typeIndex then
		-- Wrong exit: no cash, the package stays in the player's hands.
		if os.clock() - session.lastWrongNotice > 1.5 then
			session.lastWrongNotice = os.clock()
			StateService.notify(session, "toast.wrong", { typeId = carry.typeId }, "toast", "wrong")
			local penalty = math.floor(value * Config.Economy.wrongSortPenalty)
			if penalty > 0 then
				EconomyService.spend(session, math.min(penalty, data.cash))
			end
		end
		return
	end

	-- Anti-teleport: the package cannot have travelled faster than a running player.
	local elapsed = serverNow() - carry.grabbedAt
	local travel = (exit.Position - carry.grabPosition).Magnitude
	if elapsed <= 0 or travel / elapsed > carryConfig.maxTravelSpeed then
		return
	end

	local rare = if carry.rare then Economy.findRare(carry.rare) else nil
	local paid = math.floor(value * (if rare then rare.valueMultiplier else 1))
	releaseCarry(session)
	EconomyService.earn(session, paid, "sort")
	if rare and rare.id == "golden" then
		StateService.notify(session, "toast.golden", { amount = Format.cash(paid) }, "big", "rare")
	else
		StateService.notify(session, "toast.sorted", { amount = Format.cash(paid) }, "toast", "sort")
	end
	if rare and rare.bonusReward then
		local entry = Rewards.rollMystery(randomNumber)
		EconomyService.grantReward(session, entry.reward, { packageValue = value, cashNotice = "toast.mystery" })
	end

	data.stats.sortedManual += 1
	data.stats.sortedTotal += 1
	if rare then
		data.stats.rareSorted += 1
	end
	StateService.mark(session, "stats")
	Events.packageSorted:Fire(session, {
		manual = true,
		typeIndex = carry.typeIndex,
		rare = carry.rare,
		value = paid,
	})
end

local function stepCarry(session: Session)
	local carry = session.carrying
	local plot = session.plot
	if carry == nil or plot == nil then
		return
	end
	local root = rootPart(session)
	if root == nil or carry.part.Parent == nil then
		releaseCarry(session)
		return
	end
	local rare = if carry.rare then Economy.findRare(carry.rare) else nil
	if
		rare
		and rare.fragile
		and serverNow() - carry.grabbedAt > carryConfig.fragileGraceSeconds
		and math.abs(root.AssemblyLinearVelocity.Y) > carryConfig.fragileMaxVerticalSpeed
	then
		releaseCarry(session)
		StateService.notify(session, "toast.broken", nil, "big", "breakFragile")
		return
	end
	for typeIndex, exit in plot.exits do
		local offset = root.Position - exit.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= carryConfig.exitRadius and math.abs(offset.Y) < 8 then
			sortCarried(session, exit, typeIndex)
			return
		end
	end
end

local function stepCollector(session: Session, state: PlotState)
	local plot = session.plot
	if plot == nil or session.data.collector < 1 or os.clock() - state.lastCollect < COLLECT_INTERVAL then
		return
	end
	local root = rootPart(session)
	if root == nil then
		return
	end
	local offset = root.Position - plot.collector.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.Gameplay.collectorRadius and math.abs(offset.Y) < 8 then
		state.lastCollect = os.clock()
		EconomyService.collect(session)
	end
end

-- Lifecycle ----------------------------------------------------------------------------------------

local function resetPlot(state: PlotState)
	for _, belt in state.belts do
		clearBelt(state, belt)
	end
	table.clear(state.belts)
	table.clear(state.byId)
	releaseCarry(state.session)
	syncBelts(state)
	refreshRates(state)
end

local function onPlotReady(session: Session)
	local existing = plots[session]
	if existing then
		resetPlot(existing)
		return
	end
	local state: PlotState = {
		session = session,
		belts = {},
		byId = {},
		supply = 0,
		speed = Economy.beltSpeed(session.data.progress, session.passes),
		sorterRate = 0,
		accuracy = 1,
		lastCollectorNotice = 0,
		lastCollect = 0,
	}
	plots[session] = state
	syncBelts(state)
	refreshRates(state)

	session.player.CharacterRemoving:Connect(function()
		releaseCarry(session)
	end)
end

local function onProgressChanged(session: Session)
	local state = plots[session]
	if state then
		syncBelts(state)
		refreshRates(state)
	end
end

function BeltService.init()
	carriedFolder = Instance.new("Folder")
	carriedFolder.Name = "CarriedPackages"
	carriedFolder.Parent = Workspace

	local templateInstance = ServerStorage:FindFirstChild(MapContract.PACKAGE_TEMPLATE_NAME)
	if templateInstance and templateInstance:IsA("BasePart") then
		packageTemplate = templateInstance
	end

	Net.event(Net.Grab).OnServerEvent:Connect(onGrab)

	Events.plotReady:Connect(onPlotReady)
	Events.progressChanged:Connect(onProgressChanged)
	Events.passesChanged:Connect(onProgressChanged)
	Events.rebirthed:Connect(function(session)
		local state = plots[session]
		if state then
			resetPlot(state)
		end
	end)
	Sessions.removing:Connect(function(session)
		releaseCarry(session)
		plots[session] = nil
	end)
end

function BeltService.start()
	RunService.Heartbeat:Connect(function(dt)
		local now = serverNow()
		for session, state in plots do
			if session.removed or session.plot == nil then
				continue
			end
			local collectorFull = EconomyService.collectorFull(session)
			for _, belt in state.belts do
				stepBelt(state, belt, dt, now, collectorFull)
			end
			stepCarry(session)
			stepCollector(session, state)
		end
	end)
end

-- Studio debug hook helpers (DebugService) --------------------------------------------------------

-- Grabs the front-most package on the player's belts, ignoring distance.
function BeltService.debugGrabAny(session: Session): boolean
	local state = plots[session]
	local root = rootPart(session)
	if state == nil or root == nil or session.carrying then
		return false
	end
	for _, entry in state.byId do
		removeFromBelt(state, entry.belt, entry.item, serverNow())
		attach(session, entry.item.id, entry.item.payload :: Payload, root, root.Position)
		return true
	end
	return false
end

-- Sorts the carried package into its correct exit.
function BeltService.debugSortCarried(session: Session): boolean
	local carry = session.carrying
	local plot = session.plot
	if carry == nil or plot == nil then
		return false
	end
	carry.grabbedAt -= 10
	sortCarried(session, plot.exits[carry.typeIndex], carry.typeIndex)
	return session.carrying == nil
end

-- Makes the next package on the player's first belt a rare one (to check its look and handling).
function BeltService.debugNextRare(session: Session, rareId: string): boolean
	local state = plots[session]
	local belt = state and state.belts[1]
	if belt == nil or Economy.findRare(rareId) == nil then
		return false
	end
	belt.nextRoll = { typeIndex = random:NextInteger(1, 3), rare = rareId }
	return true
end

function BeltService.debugPackageCount(session: Session): number
	local state = plots[session]
	local count = 0
	if state then
		for _ in state.byId do
			count += 1
		end
	end
	return count
end

return BeltService
