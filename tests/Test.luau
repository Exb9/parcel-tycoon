--!strict
-- Minimal test harness for Lune: specs register cases with `test`, the runner reports and sets the exit code.

export type Case = { name: string, fn: () -> () }

local Test = {}

local cases: { Case } = {}

function Test.test(name: string, fn: () -> ())
	table.insert(cases, { name = name, fn = fn })
end

function Test.equal<T>(actual: T, expected: T, message: string?)
	if actual ~= expected then
		error(`{message or "values differ"}: expected {expected}, got {actual}`, 2)
	end
end

function Test.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{message or "values differ"}: expected {expected} +/- {tolerance}, got {actual}`, 2)
	end
end

function Test.between(actual: number, low: number, high: number, message: string?)
	if actual < low or actual > high then
		error(`{message or "value out of range"}: expected {low}..{high}, got {actual}`, 2)
	end
end

function Test.truthy(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

-- Runs every registered case and returns the number of failures.
function Test.run(): number
	local failures = 0
	for _, case in cases do
		local ok, err = pcall(case.fn)
		if ok then
			print(`  PASS  {case.name}`)
		else
			failures += 1
			print(`  FAIL  {case.name}\n        {err}`)
		end
	end
	print(`{#cases - failures}/{#cases} passed`)
	table.clear(cases)
	return failures
end

return Test
