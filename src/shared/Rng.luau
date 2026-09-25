--!strict
-- Small deterministic PRNG (xorshift32). Used where results must be reproducible across servers and in
-- tests, e.g. the daily quest draw. Gameplay randomness on the server can use any `() -> number`.

export type Rng = { state: number }

local Rng = {}

local UINT32 = 4294967296

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % UINT32
	if state == 0 then
		state = 0x9E3779B9
	end
	local rng = { state = state }
	-- Warm up so nearby seeds diverge.
	for _ = 1, 4 do
		Rng.nextUint(rng)
	end
	return rng
end

function Rng.nextUint(rng: Rng): number
	local x = rng.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	rng.state = x
	return x
end

-- Uniform float in [0, 1).
function Rng.next(rng: Rng): number
	return Rng.nextUint(rng) / UINT32
end

-- Uniform integer in [min, max].
function Rng.int(rng: Rng, min: number, max: number): number
	return min + math.floor(Rng.next(rng) * (max - min + 1))
end

-- Picks one entry proportionally to its weight. `random` returns floats in [0, 1).
function Rng.pickWeighted<T>(items: { T }, weightOf: (T) -> number, random: () -> number): T
	local total = 0
	for _, item in items do
		total += weightOf(item)
	end
	assert(total > 0, "pickWeighted needs a positive total weight")
	local roll = random() * total
	for _, item in items do
		roll -= weightOf(item)
		if roll < 0 then
			return item
		end
	end
	return items[#items]
end

return Rng
