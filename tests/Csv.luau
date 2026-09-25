--!strict
-- Reads the localization CSV (src/localization/GameText.csv) the way Roblox and Rojo do:
-- a header row, comma separated fields, fields with commas or quotes wrapped in quotes ("" = ").

local fs = require("@lune/fs")

export type Row = { [string]: string }

local Csv = {}

local function parseLine(line: string): { string }
	local fields = {}
	local index = 1
	local length = #line
	while index <= length + 1 do
		if string.sub(line, index, index) == '"' then
			local value = {}
			index += 1
			while true do
				local char = string.sub(line, index, index)
				if char == "" then
					error(`unterminated quoted field in: {line}`)
				elseif char == '"' then
					if string.sub(line, index + 1, index + 1) == '"' then
						table.insert(value, '"')
						index += 2
					else
						index += 1
						break
					end
				else
					table.insert(value, char)
					index += 1
				end
			end
			table.insert(fields, table.concat(value))
			-- Skip the comma after the closing quote.
			index += 1
		else
			local comma = string.find(line, ",", index, true)
			local stop = if comma then comma - 1 else length
			table.insert(fields, string.sub(line, index, stop))
			index = stop + 2
		end
	end
	return fields
end

-- Rows as { column name = value }, in file order.
function Csv.read(path: string): { Row }
	local text = fs.readFile(path)
	local lines = string.split((string.gsub(text, "\r", "")), "\n")
	local header = parseLine(lines[1])
	local rows = {}
	for lineIndex = 2, #lines do
		local line = lines[lineIndex]
		if line ~= "" then
			local fields = parseLine(line)
			assert(#fields == #header, `line {lineIndex} has {#fields} fields, expected {#header}: {line}`)
			local row: Row = {}
			for column, name in header do
				row[name] = fields[column]
			end
			table.insert(rows, row)
		end
	end
	return rows
end

return Csv
