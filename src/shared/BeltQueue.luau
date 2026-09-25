--!strict
-- Deterministic 1D model of packages on a belt. Packages move from distance 0 towards the end at the
-- belt speed, queue up at the end, and fall into the recycling bin when the queue is full.
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
	-- Where the item comes to rest, or its drop point when it overflows.
	stop: number,
	overflow: boolean,
	-- Bit mask of sorters (1-based index) the item has already passed.
	sorterMask: number,
	-- Caller data (package type, rare flag, part, ...).
	payload: any,
}

export type Belt = {
	length: number,
	queueLength: number,
	gap: number,
	speed: number,
	maxItems: number,
	-- Front (closest to the end) first.
	items: { Item },
}

local EPSILON = 1e-6

local BeltQueue = {}

function BeltQueue.new(length: number, queueLength: number, gap: number, speed: number, maxItems: number): Belt
	assert(length > queueLength, "belt must be longer than its queue")
	return {
		length = length,
		queueLength = queueLength,
		gap = gap,
		speed = speed,
		maxItems = maxItems,
		items = {},
	}
end

function BeltQueue.distanceAt(item: Item, now: number): number
	return math.min(item.d0 + item.speed * math.max(0, now - item.t0), item.stop)
end

function BeltQueue.queueStart(belt: Belt): number
	return belt.length - belt.queueLength
end

-- Recomputes resting and drop positions after the line-up changed. Items that stop at a new place get a
-- new motion segment starting now. Returns the changed items (the caller replicates them).
function BeltQueue.recompute(belt: Belt, now: number): { Item }
	local changed = {}
	local queueStart = BeltQueue.queueStart(belt)
	-- Front edge available for the next item that still fits into the queue.
	local frontEdge = belt.length
	for _, item in belt.items do
		local stop: number
		local overflow: boolean
		local candidate = frontEdge - item.length / 2
		if candidate - item.length / 2 >= queueStart - EPSILON then
			stop, overflow = candidate, false
			frontEdge = candidate - item.length / 2 - belt.gap
		else
			-- No room left in the queue: run up to the queue and drop into the bin there.
			stop, overflow = queueStart - item.length / 2 - belt.gap, true
		end
		if math.abs(stop - item.stop) > EPSILON or overflow ~= item.overflow then
			local current = BeltQueue.distanceAt(item, now)
			item.d0 = math.min(current, stop)
			item.t0 = now
			item.stop = stop
			item.overflow = overflow
			table.insert(changed, item)
		end
	end
	return changed
end

-- Whether a new item of this length fits at the start of the belt right now.
function BeltQueue.canSpawn(belt: Belt, length: number, now: number): boolean
	if #belt.items >= belt.maxItems then
		return false
	end
	local last = belt.items[#belt.items]
	if not last then
		return true
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
		overflow = false,
		sorterMask = 0,
		payload = payload,
	}
	table.insert(belt.items, item)
	return item, BeltQueue.recompute(belt, now)
end

-- Removes an item (grabbed, sorted or recycled). Returns items whose motion changed.
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

-- Overflowing items that reached their drop point.
function BeltQueue.dueOverflows(belt: Belt, now: number): { Item }
	local due = {}
	for _, item in belt.items do
		if item.overflow and BeltQueue.distanceAt(item, now) >= item.stop - EPSILON then
			table.insert(due, item)
		end
	end
	return due
end

-- Handles overflowing items that reached the queue. An item takes the place of less valuable packages
-- resting in the queue (they are evicted into the bin); if nothing is less valuable, it is recycled
-- itself. This keeps the most valuable leftovers (and every rare package) waiting for the player.
-- Returns the removed items (evicted and recycled) and the remaining items whose motion changed.
function BeltQueue.settleOverflows(belt: Belt, now: number, priorityOf: (Item) -> number): ({ Item }, { Item })
	local removed: { Item } = {}
	local changedSet: { [Item]: boolean } = {}
	local queueStart = BeltQueue.queueStart(belt)

	local function removeItem(item: Item)
		local index = table.find(belt.items, item)
		if index then
			table.remove(belt.items, index)
			table.insert(removed, item)
		end
		for _, changed in BeltQueue.recompute(belt, now) do
			changedSet[changed] = true
		end
	end

	for _, item in BeltQueue.dueOverflows(belt, now) do
		if table.find(belt.items, item) == nil then
			continue
		end
		local priority = priorityOf(item)
		while item.overflow do
			local victim: Item? = nil
			local victimPriority = priority
			for _, other in belt.items do
				if
					other ~= item
					and not other.overflow
					and BeltQueue.distanceAt(other, now) >= queueStart - EPSILON
				then
					local otherPriority = priorityOf(other)
					if otherPriority < victimPriority then
						victim, victimPriority = other, otherPriority
					end
				end
			end
			if victim == nil then
				break
			end
			removeItem(victim)
		end
		if item.overflow then
			removeItem(item)
		end
	end

	local changed = {}
	for item in changedSet do
		if table.find(belt.items, item) then
			table.insert(changed, item)
		end
	end
	return removed, changed
end

-- Items that passed the sorter at `position` since the last call for this sorter index (1-24).
-- Every item is reported once per sorter.
function BeltQueue.crossings(belt: Belt, now: number, sorterIndex: number, position: number): { Item }
	local bit = bit32.lshift(1, sorterIndex - 1)
	local crossed = {}
	for _, item in belt.items do
		if bit32.band(item.sorterMask, bit) == 0 and BeltQueue.distanceAt(item, now) >= position then
			item.sorterMask = bit32.bor(item.sorterMask, bit)
			table.insert(crossed, item)
		end
	end
	return crossed
end

-- Items resting inside the queue zone (grabbable "end of the belt" packages), front first.
function BeltQueue.queued(belt: Belt, now: number): { Item }
	local queueStart = BeltQueue.queueStart(belt)
	local result = {}
	for _, item in belt.items do
		if not item.overflow and BeltQueue.distanceAt(item, now) >= queueStart - EPSILON then
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
