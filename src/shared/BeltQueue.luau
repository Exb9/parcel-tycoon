--!strict
-- Deterministic 1D model of packages on a belt. Packages move from distance 0 towards the end at the
-- belt speed and line up at the end. When the line reaches back to the start, the chute pauses
-- (canSpawn is false) until something is taken off the belt; nothing is ever thrown away.
--
-- Every item moves by the formula distance = min(d0 + speed * (now - t0), stop). The server keeps the
-- authoritative model and replicates d0/t0/speed/stop per package; clients evaluate the same formula to
-- animate parts locally. That keeps the network quiet and avoids physics on the belt entirely.

export type Item = {
	id: number,
	-- Size along the belt.
	length: number,
	d0: number,
	t0: number,
	speed: number,
	-- Where the item comes to rest.
	stop: number,
	-- Caller data (package type, rare flag, part, ...).
	payload: any,
}

export type Belt = {
	length: number,
	gap: number,
	speed: number,
	maxItems: number,
	-- Front (closest to the end) first.
	items: { Item },
}

local EPSILON = 1e-6

local BeltQueue = {}

function BeltQueue.new(length: number, gap: number, speed: number, maxItems: number): Belt
	assert(length > 0, "belt needs a positive length")
	return {
		length = length,
		gap = gap,
		speed = speed,
		maxItems = maxItems,
		items = {},
	}
end

function BeltQueue.distanceAt(item: Item, now: number): number
	return math.min(item.d0 + item.speed * math.max(0, now - item.t0), item.stop)
end

-- Recomputes where every item comes to rest (lined up from the end). Items that rest at a new place get a
-- new motion segment starting now. Returns the changed items (the caller replicates them).
function BeltQueue.recompute(belt: Belt, now: number): { Item }
	local changed = {}
	-- Front edge available for the next item in line.
	local frontEdge = belt.length
	for _, item in belt.items do
		local stop = frontEdge - item.length / 2
		frontEdge = stop - item.length / 2 - belt.gap
		if math.abs(stop - item.stop) > EPSILON then
			local current = BeltQueue.distanceAt(item, now)
			item.d0 = math.min(current, stop)
			item.t0 = now
			item.stop = stop
			table.insert(changed, item)
		end
	end
	return changed
end

-- Whether a new item of this length fits at the start of the belt right now (false = chute pauses).
function BeltQueue.canSpawn(belt: Belt, length: number, now: number): boolean
	if #belt.items >= belt.maxItems then
		return false
	end
	local last = belt.items[#belt.items]
	if not last then
		return length <= belt.length
	end
	local lastBackEdge = BeltQueue.distanceAt(last, now) - last.length / 2
	return lastBackEdge >= length + belt.gap
end

-- Adds an item at the start. Returns the item and every item whose motion changed (including it).
function BeltQueue.spawn(belt: Belt, id: number, length: number, payload: any, now: number): (Item, { Item })
	local item: Item = {
		id = id,
		length = length,
		d0 = length / 2,
		t0 = now,
		speed = belt.speed,
		-- Resting at the start until recompute assigns the real stop.
		stop = length / 2,
		payload = payload,
	}
	table.insert(belt.items, item)
	return item, BeltQueue.recompute(belt, now)
end

-- Removes an item (grabbed or sorted by a machine). Returns items whose motion changed.
function BeltQueue.remove(belt: Belt, item: Item, now: number): { Item }
	local index = table.find(belt.items, item)
	if index then
		table.remove(belt.items, index)
	end
	return BeltQueue.recompute(belt, now)
end

-- Changes the belt speed; every item continues from where it is. Returns all items.
function BeltQueue.setSpeed(belt: Belt, speed: number, now: number): { Item }
	if math.abs(speed - belt.speed) < EPSILON then
		return {}
	end
	for _, item in belt.items do
		item.d0 = BeltQueue.distanceAt(item, now)
		item.t0 = now
		item.speed = speed
	end
	belt.speed = speed
	return table.clone(belt.items)
end

-- Items whose center is between `from` and `to` (e.g. in front of a sorting machine), front first.
-- A machine takes a matching package that passes it or that waits in front of it in a jam.
function BeltQueue.inRange(belt: Belt, now: number, from: number, to: number): { Item }
	local result = {}
	for _, item in belt.items do
		local distance = BeltQueue.distanceAt(item, now)
		if distance >= from - EPSILON and distance <= to + EPSILON then
			table.insert(result, item)
		end
	end
	return result
end

-- Items at or beyond `fromDistance`, front first (e.g. the end of the belt a player picks from).
function BeltQueue.itemsFrom(belt: Belt, now: number, fromDistance: number): { Item }
	local result = {}
	for _, item in belt.items do
		if BeltQueue.distanceAt(item, now) >= fromDistance - EPSILON then
			table.insert(result, item)
		end
	end
	return result
end

function BeltQueue.find(belt: Belt, id: number): Item?
	for _, item in belt.items do
		if item.id == id then
			return item
		end
	end
	return nil
end

return BeltQueue
