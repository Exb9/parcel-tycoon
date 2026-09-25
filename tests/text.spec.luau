--!strict
-- The localization table (src/localization/GameText.csv, synced into LocalizationService by Rojo):
-- every text has English and German, placeholders match, and everything the game names has a text.

local fs = require("@lune/fs")

local Config = require("../src/shared/Config")
local Csv = require("./Csv")
local Test = require("./Test")

local rows = Csv.read("src/localization/GameText.csv")
local byKey: { [string]: Csv.Row } = {}
for _, row in rows do
	byKey[row.Key] = row
end

local function placeholders(text: string): { [string]: boolean }
	local found = {}
	for name in string.gmatch(text, "{(%w+)}") do
		found[name] = true
	end
	return found
end

local function sameSet(a: { [string]: boolean }, b: { [string]: boolean }): boolean
	for key in a do
		if not b[key] then
			return false
		end
	end
	for key in b do
		if not a[key] then
			return false
		end
	end
	return true
end

Test.test("every row has a unique key, English source and German text", function()
	local seen = {}
	for _, row in rows do
		Test.truthy(row.Key ~= "", "row without key")
		Test.truthy(not seen[row.Key], `duplicate key {row.Key}`)
		seen[row.Key] = true
		Test.truthy(row.Source ~= "", `missing English text for {row.Key}`)
		Test.truthy(row.de ~= nil and row.de ~= "", `missing German text for {row.Key}`)
	end
end)

Test.test("German texts use the same placeholders as the English ones", function()
	for _, row in rows do
		Test.truthy(sameSet(placeholders(row.Source), placeholders(row.de)), `placeholders differ for {row.Key}`)
	end
end)

Test.test("every package type, upgrade, pass, product, cosmetic, quest and board has texts", function()
	local function has(key: string)
		Test.truthy(byKey[key] ~= nil, `missing text {key}`)
	end
	for _, packageType in Config.PackageTypes.types do
		has("package." .. packageType.id)
		has("dest." .. packageType.id)
	end
	for _, rare in Config.PackageTypes.rareVariants do
		has("rare." .. rare.id)
	end
	for _, track in Config.Upgrades.tracks do
		has("upgrade." .. track.id .. ".name")
		has("upgrade." .. track.id .. ".desc")
	end
	for _, purchase in Config.Purchases.purchases do
		if purchase.kind == "spawner" then
			has("purchase." .. purchase.id)
		end
	end
	for key, pass in Config.Monetization.gamepasses do
		if pass.cosmeticId then
			has("cosmetic." .. pass.cosmeticId)
		else
			has("pass." .. key .. ".name")
			has("pass." .. key .. ".desc")
		end
	end
	for key in Config.Monetization.products do
		has("product." .. key .. ".name")
	end
	for placement in Config.Monetization.ads do
		has("ads." .. placement)
	end
	for _, step in Config.Onboarding.steps do
		has("tutorial." .. step.id)
	end
	for _, item in Config.Cosmetics.items do
		has("cosmetic." .. item.id)
	end
	for _, slot in Config.Cosmetics.slots do
		has("style." .. slot)
	end
	for _, zone in Config.Zones.zones do
		has("zone." .. zone.id)
	end
	for _, entry in Config.Rewards.mystery do
		has("reward." .. entry.id)
	end
	for _, def in Config.Quests.dailyPool do
		has("quest." .. def.kind)
	end
	for _, board in Config.Leaderboards.boards do
		has("board." .. board.id)
	end
end)

Test.test("every notice the server sends has a text", function()
	local function scan(folder: string)
		for _, name in fs.readDir(folder) do
			local path = `{folder}/{name}`
			if fs.isDir(path) then
				scan(path)
			elseif string.match(name, "%.luau$") then
				local source = fs.readFile(path)
				for key in string.gmatch(source, 'notify%(%s*[%w_]+,%s*"([%w%.]*)"') do
					if key ~= "" then
						Test.truthy(byKey[key] ~= nil, `{path} sends notice {key} without a text`)
					end
				end
				for key in string.gmatch(source, 'cashNotice%s*=%s*"([%w%.]+)"') do
					Test.truthy(byKey[key] ~= nil, `{path} uses cash notice {key} without a text`)
				end
			end
		end
	end
	scan("src/server")
	scan("src/client")
end)
