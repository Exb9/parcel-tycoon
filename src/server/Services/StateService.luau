--!strict
-- Sends each player the parts of their state the UI needs. Services mark sections dirty; changes are
-- batched and sent at most ten times per second, and only the changed sections travel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ads = require(ReplicatedStorage.Shared.Ads)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local Quests = require(ReplicatedStorage.Shared.Quests)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local Styles = require(ReplicatedStorage.Shared.Styles)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local StateService = {
	priority = 20,
}

local SECTIONS = {
	"cash",
	"progress",
	"passes",
	"boost",
	"quests",
	"daily",
	"cosmetics",
	"stats",
	"carrying",
	"plot",
	"gift",
	"tutorial",
	"club",
	"ads",
	"store",
	"social",
}

local FLUSH_INTERVAL = 0.1

local stateRemote: RemoteEvent
local notifyRemote: RemoteEvent

local function secondsToNextDay(): number
	return 86400 - os.time() % 86400
end

local function build(session: Session, section: string): any
	local data = session.data
	local passes = session.passes
	local today = Quests.dayIndex(os.time())
	if section == "cash" then
		local bonus = Economy.cashBonus(session.friendsOnServer, session.inGroup, session.clubMember)
		return {
			cash = data.cash,
			collector = data.collector,
			collectorCapacity = Economy.collectorCapacity(data.progress, passes),
			income = Economy.estimatedIncome(data.progress, passes),
			bonus = bonus,
			multiplier = Economy.cashMultiplier(passes, data.boostUntil > os.time(), bonus),
			autoCollect = passes.autoCollect == true or data.autoCollectUntil > os.time(),
		}
	elseif section == "progress" then
		local progress = data.progress
		return {
			zone = progress.zone,
			rebirths = progress.rebirths,
			upgrades = progress.upgrades,
			purchases = progress.purchases,
			rebirthCost = Economy.rebirthCost(progress.rebirths),
			milestones = data.milestones,
		}
	elseif section == "passes" then
		return table.clone(passes)
	elseif section == "boost" then
		return {
			remaining = math.max(0, data.boostUntil - os.time()),
			autoCollectRemaining = if passes.autoCollect then 0 else math.max(0, data.autoCollectUntil - os.time()),
		}
	elseif section == "quests" then
		return {
			day = data.quests.day,
			daily = data.quests.daily,
			secondsToReset = secondsToNextDay(),
		}
	elseif section == "daily" then
		local step = Rewards.nextDaily(data.daily)
		return {
			canClaim = Rewards.canClaimDaily(data.daily, today),
			step = data.daily.step,
			nextStep = step,
			secondsToReset = secondsToNextDay(),
		}
	elseif section == "cosmetics" then
		return {
			owned = Styles.owned(data.cosmetics.owned, passes, session.clubMember),
			equipped = data.cosmetics.equipped,
		}
	elseif section == "stats" then
		return data.stats
	elseif section == "carrying" then
		local carry = session.carrying
		if carry == nil then
			return false
		end
		return {
			typeIndex = carry.typeIndex,
			typeId = carry.typeId,
			rare = carry.rare or "",
		}
	elseif section == "plot" then
		local plot = session.plot
		return { slot = if plot then plot.slotIndex else 0 }
	elseif section == "gift" then
		local seconds = Rewards.secondsToNextGift(data.playtime)
		-- -1 = all gifts of today opened.
		return { secondsToNext = seconds or -1, claimed = data.playtime.claimed }
	elseif section == "tutorial" then
		local step = Onboarding.current(data.onboarding)
		return {
			step = if step then step.id else "",
			count = data.onboarding.count,
			target = if step then step.target else 0,
			done = data.onboarding.done,
		}
	elseif section == "club" then
		local club = Config.Monetization.club
		return {
			available = club.id ~= "" or (RunService:IsStudio() and Config.Monetization.simulateInStudio),
			member = session.clubMember,
			canClaim = session.clubMember and data.club.lastGiftDay < today,
		}
	elseif section == "ads" then
		local remaining = {}
		for placement in Config.Monetization.ads do
			remaining[placement] = Ads.remaining(data.ads, today, placement)
		end
		return remaining
	elseif section == "store" then
		return { oneTime = data.oneTime }
	elseif section == "social" then
		return {
			friends = session.friendsOnServer,
			inGroup = session.inGroup,
			groupEnabled = Config.Rewards.group.groupId ~= 0,
			groupRewarded = data.group.rewarded,
		}
	end
	error(`unknown state section '{section}'`)
end

-- Marks sections as changed; they are sent with the next batch.
function StateService.mark(session: Session, ...: string)
	for _, section in { ... } do
		session.dirty[section] = true
	end
end

function StateService.markAll(session: Session)
	for _, section in SECTIONS do
		session.dirty[section] = true
	end
end

function StateService.sendFull(session: Session)
	local patch = {}
	for _, section in SECTIONS do
		patch[section] = build(session, section)
	end
	table.clear(session.dirty)
	stateRemote:FireClient(session.player, patch, true)
end

-- Shows a localized message on the player's screen (text key + arguments, see Net.Notice).
function StateService.notify(session: Session, key: string, args: { [string]: any }?, style: string?, sound: string?)
	local notice: Net.Notice = { key = key, args = args, style = style, sound = sound }
	notifyRemote:FireClient(session.player, notice)
end

local function flush()
	for _, session in Sessions.all() do
		if next(session.dirty) ~= nil then
			local patch = {}
			for section in session.dirty do
				patch[section] = build(session, section)
			end
			table.clear(session.dirty)
			stateRemote:FireClient(session.player, patch, false)
		end
	end
end

function StateService.init()
	stateRemote = Net.event(Net.State)
	notifyRemote = Net.event(Net.Notify)

	Net.event(Net.RequestState).OnServerEvent:Connect(function(player: Player)
		if not RateLimit.allow(player, "RequestState", 1, 3) then
			return
		end
		local session = Sessions.get(player)
		if session then
			StateService.sendFull(session)
		end
	end)

	Sessions.added:Connect(function(session)
		StateService.sendFull(session)
	end)
end

function StateService.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= FLUSH_INTERVAL then
			elapsed = 0
			flush()
		end
	end)
	-- Timers are counted down on the client; refresh them now and then (and pick up day changes).
	while true do
		task.wait(30)
		for _, session in Sessions.all() do
			StateService.mark(session, "boost", "quests", "daily", "cash", "gift", "club", "ads")
		end
	end
end

return StateService
