--!strict
-- Daily quests: feeds gameplay events into the quest logic (shared/Quests) and pays claimed rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local QuestService = {
	priority = 70,
}

local apply: (Session, Quests.QuestEvent) -> ()

-- With Auto Collect there is no cash register to empty, so "collect" quests count as done.
local function completeCollectForAutoCollect(session: Session)
	if session.passes.autoCollect then
		apply(session, { kind = "collect", amount = math.huge })
	end
end

local function ensureDay(session: Session)
	local day = Quests.dayIndex(os.time())
	if Quests.ensureDay(session.data.quests, day, session.userId, EconomyService.income(session)) then
		StateService.mark(session, "quests")
		completeCollectForAutoCollect(session)
	end
end

function apply(session: Session, event: Quests.QuestEvent)
	if session.removed then
		return
	end
	ensureDay(session)
	local result = Quests.applyEvent(session.data.quests, event)
	if #result.completed > 0 then
		StateService.notify(session, "toast.questDone", nil, "big", "reward")
	end
	if result.changed then
		StateService.mark(session, "quests")
	end
end

local function onClaim(player: Player, questId: any)
	if not RateLimit.allow(player, "ClaimQuest", 4, 4) then
		return
	end
	local session = Sessions.get(player)
	if session == nil or type(questId) ~= "string" then
		return
	end
	ensureDay(session)
	local reward = Quests.claim(session.data.quests, questId, EconomyService.income(session))
	if reward then
		EconomyService.earn(session, reward, "reward")
		StateService.notify(session, "toast.cash", { amount = Format.cash(reward) }, "big", "reward")
		StateService.mark(session, "quests")
	end
end

function QuestService.init()
	Net.event(Net.ClaimQuest).OnServerEvent:Connect(onClaim)

	Sessions.added:Connect(ensureDay)
	Events.passesChanged:Connect(completeCollectForAutoCollect)
	Events.packageSorted:Connect(function(session, info)
		if info.manual then
			if info.value <= 0 then
				return
			end
			apply(session, { kind = "sortManual", amount = 1 })
			apply(session, { kind = "sortType", amount = 1, typeIndex = info.typeIndex })
			if info.rare then
				apply(session, { kind = "sortRare", amount = 1 })
			end
		elseif info.value > 0 then
			apply(session, { kind = "sortMachine", amount = 1 })
		end
	end)
	Events.cashEarned:Connect(function(session, amount, source)
		if source == "sort" or source == "machine" then
			apply(session, { kind = "earn", amount = amount })
		end
	end)
	Events.upgradeBought:Connect(function(session)
		apply(session, { kind = "buyUpgrades", amount = 1 })
	end)
	Events.collected:Connect(function(session)
		apply(session, { kind = "collect", amount = 1 })
	end)
end

function QuestService.start()
	-- New quests at the UTC day change, also for players who are idle.
	while true do
		task.wait(60)
		for _, session in Sessions.all() do
			ensureDay(session)
		end
	end
end

return QuestService
