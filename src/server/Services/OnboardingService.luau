--!strict
-- First-time tutorial (Config.Onboarding, shared/Onboarding): feeds gameplay events into the step
-- machine and gives a gift at the end ("moment of joy", Roblox onboarding guide). The client shows the
-- hint of the current step in HUD.Tutorial.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local OnboardingService = {
	priority = 75,
}

local function finish(session: Session)
	EconomyService.grantReward(session, Config.Rewards.onboarding, { cashNotice = "toast.tutorialDone" })
end

-- With Auto Collect there is no cash register to walk over, so that step is skipped.
local function skipImpossibleSteps(session: Session)
	local step = Onboarding.current(session.data.onboarding)
	if step and step.event == "collect" and EconomyService.hasAutoCollect(session) then
		local result = Onboarding.skip(session.data.onboarding)
		StateService.mark(session, "tutorial")
		if result.finished then
			finish(session)
		end
	end
end

local function apply(session: Session, event: Onboarding.StepEvent)
	if session.removed or session.data.onboarding.done then
		return
	end
	local result = Onboarding.applyEvent(session.data.onboarding, event)
	if result.changed then
		StateService.mark(session, "tutorial")
	end
	if result.finished then
		finish(session)
	else
		skipImpossibleSteps(session)
	end
end

function OnboardingService.init()
	Events.packageGrabbed:Connect(function(session)
		apply(session, "grab")
	end)
	Events.packageSorted:Connect(function(session, info)
		if info.manual and info.value > 0 then
			apply(session, "sortManual")
		end
	end)
	Events.purchaseBought:Connect(function(session)
		apply(session, "buyPurchase")
	end)
	Events.collected:Connect(function(session)
		apply(session, "collect")
	end)
	Events.passesChanged:Connect(skipImpossibleSteps)
	Sessions.added:Connect(skipImpossibleSteps)
end

return OnboardingService
