--!strict
-- Free rewards: the daily reward calendar and invites via share link (Creator Rewards, CLAUDE.md decisions).
-- Invites follow Roblox's friend referral system: Player:GetJoinData().ReferredByPlayerId names the
-- inviter for every kind of invite. Only brand-new players count, and inviters get at most
-- Config.Rewards.referral.maxInviterRewardsPerDay rewards per day.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
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
local REFERRAL_DELAY = 5
local REFERRAL_MESSAGE = "referral"

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

	Sessions.added:Connect(function(session)
		listenForMessages(session)
		task.delay(REFERRAL_DELAY, function()
			if not session.removed then
				handleReferral(session)
			end
		end)
	end)
end

return RewardService
