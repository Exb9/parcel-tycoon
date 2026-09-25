--!strict
-- First-time tutorial (pure logic): which step a player is on and how gameplay events advance it.
-- OnboardingService feeds the events and pays the gift at the end.

local Config = require("./Config")
local OnboardingConfig = require("./Config/Onboarding")

export type Step = OnboardingConfig.Step
export type StepEvent = OnboardingConfig.StepEvent
-- PlayerData.onboarding (DataSchema).
export type State = { step: number, count: number, done: boolean }

export type EventResult = {
	-- Progress changed (count or step).
	changed: boolean,
	-- The tutorial just finished with this event.
	finished: boolean,
}

local Onboarding = {}

-- The current step, or nil when the tutorial is done.
function Onboarding.current(state: State): Step?
	if state.done then
		return nil
	end
	return Config.Onboarding.steps[state.step]
end

function Onboarding.applyEvent(state: State, event: StepEvent, amount: number?): EventResult
	local result: EventResult = { changed = false, finished = false }
	local step = Onboarding.current(state)
	if step == nil or step.event ~= event then
		return result
	end
	result.changed = true
	state.count += amount or 1
	if state.count >= step.target then
		state.step += 1
		state.count = 0
		if Config.Onboarding.steps[state.step] == nil then
			state.done = true
			result.finished = true
		end
	end
	return result
end

-- Skips the current step (used when a pass makes it impossible, e.g. collecting with Auto Collect).
function Onboarding.skip(state: State): EventResult
	local step = Onboarding.current(state)
	if step == nil then
		return { changed = false, finished = false }
	end
	return Onboarding.applyEvent(state, step.event, step.target)
end

return Onboarding
