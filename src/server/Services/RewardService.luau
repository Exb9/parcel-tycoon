--!strict
-- Free rewards: daily calendar, playtime gifts, codes, the group bonus, rebirth milestones, the club gift
-- and invites via share link (Creator Rewards, CLAUDE.md decisions).
-- Invites follow Roblox's friend referral system: Player:GetJoinData().ReferredByPlayerId names the
-- inviter for every kind of invite. Only brand-new players count, and inviters get at most
-- Config.Rewards.referral.maxInviterRewardsPerDay rewards per day.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codes = require(script.Parent.Parent.Codes)
local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local RewardService = {
	priority = 80,
}

-- Wait a moment after joining so the gamepass checks are done and the welcome toast is not lost
-- behind the loading screen.
local JOIN_DELAY = 5
local REFERRAL_MESSAGE = "referral"
local MAX_CODE_LENGTH = 40

local function today(): number
	return Quests.dayIndex(os.time())
end

-- Daily reward calendar ----------------------------------------------------------------------------

local function onClaimDaily(player: Player)
	if not RateLimit.allow(player, "ClaimDaily", 1, 2) then
		return
	end
	local session = Sessions.get(player)
	if session == nil then
		return
	end
	local reward = Rewards.claimDaily(session.data.daily, today())
	if reward then
		StateService.mark(session, "daily")
		EconomyService.grantReward(session, reward)
	end
end

-- Playtime gifts -------------------------------------------------------------------------------------

local function tickPlaytime(session: Session, seconds: number)
	local playtime = session.data.playtime
	if Rewards.ensurePlaytimeDay(playtime, today()) then
		StateService.mark(session, "gift")
	end
	local before = Rewards.secondsToNextGift(playtime)
	playtime.seconds += seconds
	if before and before > 0 and (Rewards.secondsToNextGift(playtime) or 0) <= 0 then
		StateService.mark(session, "gift")
	end
end

local function onClaimGift(player: Player)
	if not RateLimit.allow(player, "ClaimGift", 1, 2) then
		return
	end
	local session = Sessions.get(player)
	if session == nil then
		return
	end
	local reward = Rewards.openGift(session.data.playtime, today())
	if reward then
		StateService.mark(session, "gift")
		EconomyService.grantReward(session, reward)
	end
end

-- Codes --------------------------------------------------------------------------------------------------

local function onRedeemCode(player: Player, text: any)
	if not RateLimit.allow(player, "RedeemCode", 0.5, 3) then
		return
	end
	local session = Sessions.get(player)
	if session == nil or type(text) ~= "string" or #text > MAX_CODE_LENGTH then
		return
	end
	local code = Rewards.normalizeCode(text)
	local entry = Codes[code]
	if entry == nil then
		StateService.notify(session, "codes.invalid", nil, "toast", "wrong")
	elseif session.data.codes[code] then
		StateService.notify(session, "codes.used", nil, "toast", "wrong")
	elseif entry.expires and os.time() > entry.expires then
		StateService.notify(session, "codes.expired", nil, "toast", "wrong")
	else
		session.data.codes[code] = true
		StateService.notify(session, "codes.success", nil, "toast", "reward")
		EconomyService.grantReward(session, entry.reward)
	end
end

-- Group ----------------------------------------------------------------------------------------------------

local function setInGroup(session: Session, inGroup: boolean)
	local data = session.data
	if inGroup and not data.group.rewarded then
		data.group.rewarded = true
		EconomyService.grantReward(session, Config.Rewards.group.joinReward, { cashNotice = "toast.groupThanks" })
	end
	if session.inGroup ~= inGroup then
		session.inGroup = inGroup
		Events.bonusChanged:Fire(session)
	end
	StateService.mark(session, "social")
end

local function checkGroupOnJoin(session: Session)
	local groupId = Config.Rewards.group.groupId
	if groupId == 0 then
		return
	end
	local ok, member = pcall(function()
		return session.player:IsInGroupAsync(groupId)
	end)
	if ok and not session.removed then
		setInGroup(session, member == true)
	end
end

-- After the in-game join prompt. The server's IsInGroupAsync cache would still say "no", so the
-- membership is read fresh from the user's group list.
local function onCheckGroup(player: Player)
	if not RateLimit.allow(player, "CheckGroup", 0.2, 2) then
		return
	end
	local session = Sessions.get(player)
	local groupId = Config.Rewards.group.groupId
	if session == nil or groupId == 0 or session.inGroup then
		return
	end
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if not ok or type(groups) ~= "table" or session.removed then
		return
	end
	for _, group in groups :: { any } do
		if group.Id == groupId then
			setInGroup(session, true)
			return
		end
	end
end

-- Rebirth milestones -------------------------------------------------------------------------------------

local function checkMilestones(session: Session)
	local data = session.data
	for _, milestone in Rewards.pendingMilestones(data.milestones, data.progress.rebirths) do
		data.milestones[tostring(milestone.rebirths)] = true
		EconomyService.grantReward(session, milestone.reward)
		if milestone.cosmeticId then
			CosmeticService.grant(session, milestone.cosmeticId)
		end
		StateService.mark(session, "progress")
	end
end

-- Club gift ------------------------------------------------------------------------------------------------

local function onClaimClubGift(player: Player)
	if not RateLimit.allow(player, "ClaimClubGift", 1, 2) then
		return
	end
	local session = Sessions.get(player)
	if session == nil or not session.clubMember or session.data.club.lastGiftDay >= today() then
		return
	end
	session.data.club.lastGiftDay = today()
	StateService.mark(session, "club")
	EconomyService.grantReward(session, Config.Monetization.club.dailyGift, { cashNotice = "toast.clubGift" })
end

-- Invites ------------------------------------------------------------------------------------------

local function rewardInviter(session: Session)
	local referrals = session.data.referrals
	if referrals.day ~= today() then
		referrals.day = today()
		referrals.rewardedToday = 0
	end
	if referrals.rewardedToday >= Config.Rewards.referral.maxInviterRewardsPerDay then
		return
	end
	referrals.rewardedToday += 1
	EconomyService.grantReward(session, Config.Rewards.referral.inviter, { cashNotice = "toast.referral" })
end

local function handleReferral(session: Session)
	local ok, joinData = pcall(function()
		return session.player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" then
		return
	end
	local inviterId = (joinData :: any).ReferredByPlayerId
	local referrals = session.data.referrals
	if type(inviterId) ~= "number" or inviterId <= 0 or inviterId == session.userId or referrals.welcomed then
		return
	end
	-- Only brand-new players count as invited (one reward per invitee, no rejoin farming).
	if (session.profile.SessionLoadCount or 1) > 1 then
		return
	end
	referrals.welcomed = true
	EconomyService.grantReward(session, Config.Rewards.referral.invitee, { cashNotice = "toast.welcome" })

	local inviter = Players:GetPlayerByUserId(inviterId)
	local inviterSession = inviter and Sessions.get(inviter)
	if inviterSession then
		rewardInviter(inviterSession)
	else
		-- Delivered by the inviter's profile message handler, on this or any other server.
		task.spawn(DataService.message, inviterId, { kind = REFERRAL_MESSAGE, invitee = session.userId })
	end
end

local function listenForMessages(session: Session)
	session.profile:MessageHandler(function(message: any, processed: () -> ())
		if session.removed then
			return
		end
		if type(message) == "table" and message.kind == REFERRAL_MESSAGE then
			rewardInviter(session)
		end
		processed()
	end)
end

function RewardService.init()
	Net.event(Net.ClaimDaily).OnServerEvent:Connect(onClaimDaily)
	Net.event(Net.ClaimGift).OnServerEvent:Connect(onClaimGift)
	Net.event(Net.RedeemCode).OnServerEvent:Connect(onRedeemCode)
	Net.event(Net.CheckGroup).OnServerEvent:Connect(onCheckGroup)
	Net.event(Net.ClaimClubGift).OnServerEvent:Connect(onClaimClubGift)

	Sessions.added:Connect(function(session)
		if Rewards.ensurePlaytimeDay(session.data.playtime, today()) then
			StateService.mark(session, "gift")
		end
		listenForMessages(session)
		task.spawn(checkGroupOnJoin, session)
		task.delay(JOIN_DELAY, function()
			if not session.removed then
				handleReferral(session)
				checkMilestones(session)
			end
		end)
	end)
	Events.rebirthed:Connect(checkMilestones)
end

function RewardService.start()
	while true do
		task.wait(1)
		for _, session in Sessions.all() do
			tickPlaytime(session, 1)
		end
	end
end

-- For the Studio debug hook.
RewardService.tickPlaytime = tickPlaytime
RewardService.setInGroup = setInGroup

return RewardService
