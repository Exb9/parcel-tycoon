--!strict
-- Cash, the cash register, boosts, rewards, shop purchases, rebirths and offline earnings.
-- The only place that changes a player's cash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Events = require(script.Parent.Parent.Lib.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local EconomyService = {
	priority = 40,
}

local LAST_ONLINE_INTERVAL = 30

function EconomyService.boostActive(session: Session): boolean
	return session.data.boostUntil > os.time()
end

-- Multiplier on cash from sorting: passes and the active boost.
function EconomyService.cashMultiplier(session: Session): number
	return Economy.cashMultiplier(session.passes, EconomyService.boostActive(session))
end

-- Income estimate per minute for progress-scaled rewards (typical manual play, passes, no boost).
function EconomyService.income(session: Session): number
	return Economy.estimatedIncome(session.data.progress, session.passes)
end

local function updateLeaderstats(session: Session)
	local leaderstats = session.player:FindFirstChild("leaderstats")
	if leaderstats == nil then
		return
	end
	local cash = leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("StringValue") then
		cash.Value = Format.cash(session.data.cash)
	end
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = session.data.progress.rebirths
	end
end

-- Adds cash. `source`: "sort" | "machine" | "collect" | "reward" | "offline" | "purchase".
-- Sorting income counts towards totalEarned (leaderboard); collected machine cash was counted on deposit.
function EconomyService.earn(session: Session, amount: number, source: string)
	if amount <= 0 or amount ~= amount then
		return
	end
	local data = session.data
	data.cash += amount
	if source == "sort" or source == "machine" or source == "offline" then
		data.stats.totalEarned += amount
	end
	StateService.mark(session, "cash", "stats")
	updateLeaderstats(session)
	Events.cashEarned:Fire(session, amount, source)
end

function EconomyService.spend(session: Session, amount: number): boolean
	if amount < 0 or session.data.cash < amount then
		return false
	end
	session.data.cash -= amount
	StateService.mark(session, "cash")
	updateLeaderstats(session)
	return true
end

function EconomyService.collectorCapacity(session: Session): number
	return Economy.collectorCapacity(session.data.progress, session.passes)
end

function EconomyService.collectorFull(session: Session): boolean
	return not session.passes.autoCollect and session.data.collector >= EconomyService.collectorCapacity(session)
end

-- Machine income goes into the cash register (or straight to the balance with Auto Collect).
-- Returns false when the register is full; machines pause then.
function EconomyService.depositMachine(session: Session, amount: number): boolean
	if session.passes.autoCollect then
		EconomyService.earn(session, amount, "machine")
		return true
	end
	local data = session.data
	local capacity = EconomyService.collectorCapacity(session)
	if data.collector >= capacity then
		return false
	end
	local accepted = math.min(amount, capacity - data.collector)
	data.collector += accepted
	data.stats.totalEarned += accepted
	StateService.mark(session, "cash", "stats")
	Events.cashEarned:Fire(session, accepted, "machine")
	return true
end

function EconomyService.collect(session: Session): number
	local amount = math.floor(session.data.collector)
	if amount <= 0 then
		return 0
	end
	session.data.collector = 0
	EconomyService.earn(session, amount, "collect")
	StateService.notify(session, "toast.collected", { amount = Format.cash(amount) }, "toast", "collect")
	Events.collected:Fire(session, amount)
	return amount
end

function EconomyService.addBoost(session: Session, minutes: number)
	if minutes <= 0 then
		return
	end
	local data = session.data
	data.boostUntil = math.max(os.time(), data.boostUntil) + math.floor(minutes * 60)
	StateService.mark(session, "boost", "cash")
end

export type GrantOptions = {
	-- Value of the package that triggered the reward (mystery packages).
	packageValue: number?,
	-- Text key for the cash toast (default "toast.cash"); false = no toast.
	cashNotice: (string | boolean)?,
}

-- Applies a reward definition (Config.Rewards) and shows what the player got.
function EconomyService.grantReward(session: Session, reward: Rewards.Reward, options: GrantOptions?): Rewards.Grant
	local opts: GrantOptions = options or {}
	local grant = Rewards.resolve(reward, {
		incomePerMinute = EconomyService.income(session),
		packageValue = opts.packageValue,
	})
	if grant.cash > 0 then
		EconomyService.earn(session, grant.cash, "reward")
		if opts.cashNotice ~= false then
			local key = if type(opts.cashNotice) == "string" then opts.cashNotice else "toast.cash"
			StateService.notify(session, key, { amount = Format.cash(grant.cash) }, "big", "reward")
		end
	end
	if grant.boostMinutes > 0 then
		EconomyService.addBoost(session, grant.boostMinutes)
		StateService.notify(session, "toast.boost", { minutes = grant.boostMinutes }, "big", "reward")
	end
	return grant
end

-- Marks a one-off purchase as owned without paying (Instant Machine product, debug).
function EconomyService.grantPurchase(session: Session, purchaseId: string)
	session.data.progress.purchases[purchaseId] = true
	StateService.mark(session, "progress", "cash")
	Events.purchaseBought:Fire(session, purchaseId)
	Events.progressChanged:Fire(session)
end

function EconomyService.buyUpgrade(session: Session, trackId: string): boolean
	if Economy.findTrack(trackId) == nil then
		return false
	end
	local progress = session.data.progress
	local level = Economy.level(progress, trackId)
	local cost = Economy.upgradeCost(trackId, level)
	if cost == nil then
		return false
	end
	if not EconomyService.spend(session, cost) then
		StateService.notify(session, "toast.notEnough", nil, "toast", "wrong")
		return false
	end
	progress.upgrades[trackId] = level + 1
	StateService.mark(session, "progress", "cash")
	StateService.notify(session, "toast.bought", { trackId = trackId }, "toast", "buy")
	Events.upgradeBought:Fire(session, trackId)
	Events.progressChanged:Fire(session)
	return true
end

function EconomyService.buyPurchase(session: Session, purchaseId: string): boolean
	local purchase = Economy.findPurchase(purchaseId)
	if purchase == nil or not Economy.isPurchaseAvailable(session.data.progress, purchaseId, session.passes) then
		return false
	end
	if not EconomyService.spend(session, purchase.cost) then
		StateService.notify(session, "toast.notEnough", nil, "toast", "wrong")
		return false
	end
	StateService.notify(session, "toast.bought", { purchaseId = purchaseId }, "toast", "buy")
	EconomyService.grantPurchase(session, purchaseId)
	return true
end

function EconomyService.rebirth(session: Session): boolean
	local data = session.data
	local cost = Economy.rebirthCost(data.progress.rebirths)
	if data.cash < cost then
		StateService.notify(session, "toast.notEnough", nil, "toast", "wrong")
		return false
	end
	data.progress = Economy.rebirth(data.progress)
	data.cash = Config.Economy.startingCash
	data.collector = 0
	data.stats.rebirths = data.progress.rebirths
	StateService.mark(session, "cash", "progress", "stats")
	updateLeaderstats(session)
	StateService.notify(
		session,
		"toast.rebirth",
		{ multiplier = Economy.rebirthMultiplier(data.progress.rebirths) },
		"big",
		"reward"
	)
	Events.rebirthed:Fire(session)
	Events.progressChanged:Fire(session)
	return true
end

local function createLeaderstats(session: Session)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = session.player
	updateLeaderstats(session)
end

-- Pays what the machines earned while the player was away. Returns the amount.
function EconomyService.payOfflineEarnings(session: Session, secondsAway: number): number
	local data = session.data
	local earned = Economy.offlineEarnings(data.progress, secondsAway, session.passes)
	if earned > 0 then
		EconomyService.earn(session, earned, "offline")
		StateService.notify(session, "toast.offline", { amount = Format.cash(earned) }, "big", "reward")
	end
	return earned
end

function EconomyService.init()
	Net.event(Net.BuyUpgrade).OnServerEvent:Connect(function(player: Player, trackId: any)
		local session = Sessions.get(player)
		if session and type(trackId) == "string" and RateLimit.allow(player, "Buy", 10, 10) then
			EconomyService.buyUpgrade(session, trackId)
		end
	end)
	Net.event(Net.BuyPurchase).OnServerEvent:Connect(function(player: Player, purchaseId: any)
		local session = Sessions.get(player)
		if session and type(purchaseId) == "string" and RateLimit.allow(player, "Buy", 10, 10) then
			EconomyService.buyPurchase(session, purchaseId)
		end
	end)
	Net.event(Net.Rebirth).OnServerEvent:Connect(function(player: Player)
		local session = Sessions.get(player)
		if session and RateLimit.allow(player, "Rebirth", 0.5, 1) then
			EconomyService.rebirth(session)
		end
	end)

	Sessions.added:Connect(function(session)
		createLeaderstats(session)
		local lastOnline = session.data.lastOnline
		local secondsAway = if lastOnline > 0 then os.time() - lastOnline else 0
		session.data.lastOnline = os.time()
		-- Wait for the gamepass checks so offline earnings include 2x Cash.
		task.delay(3, function()
			if not session.removed and secondsAway > 0 then
				EconomyService.payOfflineEarnings(session, secondsAway)
			end
		end)
	end)
end

function EconomyService.start()
	while true do
		task.wait(LAST_ONLINE_INTERVAL)
		local now = os.time()
		for _, session in Sessions.all() do
			session.data.lastOnline = now
		end
	end
end

EconomyService.updateLeaderstats = updateLeaderstats

return EconomyService
