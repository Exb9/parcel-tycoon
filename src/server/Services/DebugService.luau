--!strict
-- Studio-only debug hook for playtests driven through the Studio MCP (execute_luau).
-- `require` inside execute_luau returns a fresh module without the running state, so the live services
-- are reached through a BindableFunction instead:
--
--   local debug = game:GetService("ServerStorage"):WaitForChild("ParcelDebug")
--   print(debug:Invoke("help"))
--   print(debug:Invoke("state"))
--   debug:Invoke("cash", 5000)
--
-- Commands act on the first loaded player; pass { userId = ... } as the last argument to pick another.
-- The hook only exists in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BeltService = require(script.Parent.BeltService)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local FriendsService = require(script.Parent.FriendsService)
local MonetizationService = require(script.Parent.MonetizationService)
local OfferService = require(script.Parent.OfferService)
local PlotService = require(script.Parent.PlotService)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local RewardService = require(script.Parent.RewardService)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session
type Command = {
	usage: string,
	run: (session: Session, ...any) -> any,
}

local DebugService = {
	priority = 200,
}

local HOOK_NAME = "ParcelDebug"

local function summary(session: Session): { [string]: any }
	local data = session.data
	local progress = data.progress
	local owned = {}
	for purchaseId in progress.purchases do
		table.insert(owned, purchaseId)
	end
	table.sort(owned)
	local passes = {}
	for key, owns in session.passes do
		if owns then
			table.insert(passes, key)
		end
	end
	table.sort(passes)
	local carry = session.carrying
	return {
		player = session.player.Name,
		cash = data.cash,
		collector = data.collector,
		collectorCapacity = EconomyService.collectorCapacity(session),
		incomePerMinute = EconomyService.income(session),
		zone = progress.zone,
		rebirths = progress.rebirths,
		upgrades = table.clone(progress.upgrades),
		purchases = owned,
		passes = passes,
		boostSeconds = math.max(0, data.boostUntil - os.time()),
		carrying = if carry then `{carry.typeId}{if carry.rare then " (" .. carry.rare .. ")" else ""}` else nil,
		packagesOnBelts = BeltService.debugPackageCount(session),
		plotSlot = if session.plot then session.plot.slotIndex else nil,
		stats = table.clone(data.stats),
		quests = data.quests.daily,
		daily = table.clone(data.daily),
		bonus = EconomyService.bonus(session),
		friendsOnServer = session.friendsOnServer,
		inGroup = session.inGroup,
		clubMember = session.clubMember,
		autoCollect = EconomyService.hasAutoCollect(session),
		tutorial = table.clone(data.onboarding),
		playtime = table.clone(data.playtime),
		ads = data.ads.counts,
	}
end

local commands: { [string]: Command } = {
	state = {
		usage = "state - summary of the player's server state",
		run = summary,
	},
	cash = {
		usage = "cash <amount> - add cash (negative removes)",
		run = function(session, amount: any)
			assert(type(amount) == "number", "amount must be a number")
			if amount >= 0 then
				EconomyService.earn(session, amount, "reward")
			else
				EconomyService.spend(session, math.min(-amount, session.data.cash))
			end
			return session.data.cash
		end,
	},
	upgrade = {
		usage = "upgrade <trackId> - buy one level with cash",
		run = function(session, trackId: any)
			return EconomyService.buyUpgrade(session, tostring(trackId))
		end,
	},
	buy = {
		usage = "buy <purchaseId> - buy a machine, chute or belt with cash",
		run = function(session, purchaseId: any)
			return EconomyService.buyPurchase(session, tostring(purchaseId))
		end,
	},
	grant = {
		usage = "grant <purchaseId> - own a machine, chute or belt for free",
		run = function(session, purchaseId: any)
			assert(Economy.findPurchase(tostring(purchaseId)), "unknown purchase")
			EconomyService.grantPurchase(session, tostring(purchaseId))
			return true
		end,
	},
	rebirth = {
		usage = "rebirth - rebirth (needs the cash)",
		run = function(session)
			return EconomyService.rebirth(session)
		end,
	},
	pass = {
		usage = "pass <key> - give a gamepass for this session",
		run = function(session, key: any)
			assert(Config.Monetization.gamepasses[tostring(key)], "unknown gamepass")
			MonetizationService.setPass(session, tostring(key))
			return true
		end,
	},
	product = {
		usage = "product <key> - grant a developer product's content (no receipt)",
		run = function(session, key: any)
			assert(Config.Monetization.products[tostring(key)], "unknown product")
			MonetizationService.grantProduct(session, tostring(key))
			return true
		end,
	},
	boost = {
		usage = "boost <minutes> - add boost time",
		run = function(session, minutes: any)
			EconomyService.addBoost(session, tonumber(minutes) or 0)
			return math.max(0, session.data.boostUntil - os.time())
		end,
	},
	grab = {
		usage = "grab - pick up a package from the player's belts, ignoring distance",
		run = function(session)
			return BeltService.debugGrabAny(session)
		end,
	},
	rare = {
		usage = "rare <golden|fragile|mystery> - the next package on belt 1 is that rare package",
		run = function(session, rareId: any)
			return BeltService.debugNextRare(session, tostring(rareId))
		end,
	},
	sort = {
		usage = "sort - put the carried package into its correct exit",
		run = function(session)
			return BeltService.debugSortCarried(session)
		end,
	},
	collect = {
		usage = "collect - empty the cash register",
		run = function(session)
			return EconomyService.collect(session)
		end,
	},
	offline = {
		usage = "offline <seconds> - pay offline earnings as after that long away (opens the welcome-back window)",
		run = function(session, seconds: any)
			return EconomyService.payOfflineEarnings(session, tonumber(seconds) or 0)
		end,
	},
	daily = {
		usage = "daily - make today's daily reward claimable again",
		run = function(session)
			session.data.daily.lastClaimDay = -1
			StateService.mark(session, "daily")
			return true
		end,
	},
	quests = {
		usage = "quests [done] - redraw today's quests, or finish them with 'done'",
		run = function(session, mode: any)
			local data = session.data.quests
			if mode == "done" then
				for _, quest in data.daily do
					quest.progress = quest.target
				end
			else
				data.day = -1
				Quests.ensureDay(data, Quests.dayIndex(os.time()), session.userId, EconomyService.income(session))
			end
			StateService.mark(session, "quests")
			return data.daily
		end,
	},
	ad = {
		usage = "ad <boost|doubleOffline|autoCollectTrial> - grant what the video ad of that placement gives",
		run = function(session, placement: any)
			local config = Config.Monetization.ads[tostring(placement)]
			assert(config, "unknown ad placement")
			MonetizationService.grantProduct(session, config.productKey)
			return true
		end,
	},
	club = {
		usage = "club [off] - make the player a club member (or end it)",
		run = function(session, mode: any)
			MonetizationService.setClubMember(session, mode ~= "off")
			return session.clubMember
		end,
	},
	friends = {
		usage = "friends <count> - pretend this many friends are on the server",
		run = function(session, count: any)
			FriendsService.setFriends(session, tonumber(count) or 0)
			return EconomyService.bonus(session)
		end,
	},
	group = {
		usage = "group [off] - pretend the player is in the group (gives the join gift once)",
		run = function(session, mode: any)
			RewardService.setInGroup(session, mode ~= "off")
			return EconomyService.bonus(session)
		end,
	},
	gift = {
		usage = "gift - make the next playtime gift ready",
		run = function(session)
			local seconds = Rewards.secondsToNextGift(session.data.playtime)
			if seconds and seconds > 0 then
				RewardService.tickPlaytime(session, seconds)
			end
			return session.data.playtime
		end,
	},
	tutorial = {
		usage = "tutorial [done] - restart the first-time tutorial (or finish it)",
		run = function(session, mode: any)
			local onboarding = session.data.onboarding
			onboarding.step = if mode == "done" then #Config.Onboarding.steps + 1 else 1
			onboarding.count = 0
			onboarding.done = mode == "done"
			StateService.mark(session, "tutorial")
			return onboarding
		end,
	},
	offer = {
		usage = "offer <pass|product> <key> - show an offer popup now (ignores the cooldown)",
		run = function(session, kind: any, key: any)
			session.lastOfferAt = -math.huge
			session.offersShown[`{kind}:{key}`] = nil
			return OfferService.show(session, kind, tostring(key))
		end,
	},
	home = {
		usage = "home - teleport the player to their plot",
		run = function(session)
			PlotService.teleportHome(session)
			return true
		end,
	},
	reset = {
		usage = "reset - wipe progress, cash and stats of this session (keeps passes)",
		run = function(session)
			local data = session.data
			data.cash = Config.Economy.startingCash
			data.collector = 0
			data.progress = Economy.newProgress()
			for stat in data.stats do
				(data.stats :: any)[stat] = 0
			end
			StateService.markAll(session)
			EconomyService.updateLeaderstats(session)
			Events.rebirthed:Fire(session)
			Events.progressChanged:Fire(session)
			return true
		end,
	},
}

local function help(): string
	local lines = {}
	for _, command in commands do
		table.insert(lines, command.usage)
	end
	table.sort(lines)
	return "ParcelDebug commands (last argument { userId = ... } picks a player):\n" .. table.concat(lines, "\n")
end

local function pickSession(args: { any }): Session?
	local last = args[#args]
	if type(last) == "table" and type(last.userId) == "number" then
		table.remove(args)
		for _, session in Sessions.all() do
			if session.userId == last.userId then
				return session
			end
		end
		return nil
	end
	return Sessions.all()[1]
end

local function invoke(name: any, ...: any): any
	if name == nil or name == "help" then
		return help()
	end
	local command = commands[tostring(name)]
	if command == nil then
		return `unknown command '{name}'\n{help()}`
	end
	local args = table.pack(...)
	local list = {}
	for index = 1, args.n do
		list[index] = args[index]
	end
	local session = pickSession(list)
	if session == nil then
		return "no loaded player"
	end
	local ok, result = pcall(command.run, session, table.unpack(list))
	if not ok then
		return `error: {result}`
	end
	return result
end

function DebugService.init()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = HOOK_NAME
	hook.OnInvoke = invoke
	hook.Parent = ServerStorage
end

return DebugService
