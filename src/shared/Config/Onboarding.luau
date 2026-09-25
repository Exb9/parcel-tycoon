--!strict
-- First-time tutorial: short steps that teach the core loop (grab, sort, buy a machine, collect).
-- Each step waits for a gameplay event; the hint text is "tutorial.<id>" in GameText.csv. The gift at the
-- end is Config.Rewards.onboarding.

export type StepEvent = "grab" | "sortManual" | "buyPurchase" | "collect"

export type Step = {
	id: string,
	event: StepEvent,
	-- How many events finish the step.
	target: number,
}

local steps: { Step } = {
	{ id = "grab", event = "grab", target = 1 },
	{ id = "sort", event = "sortManual", target = 1 },
	{ id = "sortMore", event = "sortManual", target = 5 },
	{ id = "buyMachine", event = "buyPurchase", target = 1 },
	{ id = "collect", event = "collect", target = 1 },
}

return {
	steps = steps,
}
