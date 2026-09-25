--!strict
-- Token-bucket limits for remote requests, per player and key.

local Players = game:GetService("Players")

type Bucket = { tokens: number, updated: number }

local RateLimit = {}

local buckets: { [Player]: { [string]: Bucket } } = {}

-- True if the request may proceed. `perSecond` refills, `burst` is the bucket size.
function RateLimit.allow(player: Player, key: string, perSecond: number, burst: number): boolean
	local playerBuckets = buckets[player]
	if playerBuckets == nil then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[key]
	if bucket == nil then
		bucket = { tokens = burst, updated = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.updated) * perSecond)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

return RateLimit
