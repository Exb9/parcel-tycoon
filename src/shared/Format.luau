--!strict
-- Number and time formatting for the UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 999 -> "999", 1234 -> "1.23K", 45600 -> "45.6K", 1.5e6 -> "1.5M"
function Format.number(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	local abs = math.abs(value)
	if abs < 1000 then
		return sign .. tostring(math.floor(abs))
	end
	local tier = math.min(#SUFFIXES - 1, math.floor(math.log10(abs) / 3))
	local scaled = abs / 10 ^ (tier * 3)
	-- Floor instead of rounding so "999.99K" never shows as "1000K".
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	if string.find(text, ".", 1, true) then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.cash(value: number): string
	return "$" .. Format.number(value)
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- 0.85 -> "85%"
function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

return Format
