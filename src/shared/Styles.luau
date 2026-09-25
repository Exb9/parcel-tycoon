--!strict
-- Which styles (Config.Cosmetics) a player can use: styles earned or bought as products (saved in
-- PlayerData.cosmetics.owned), styles of owned gamepasses, and the club style while subscribed.

local Config = require("./Config")

local Styles = {}

local passByCosmetic: { [string]: string } = {}
for key, pass in Config.Monetization.gamepasses do
	if pass.cosmeticId then
		passByCosmetic[pass.cosmeticId] = key
	end
end

local itemsById: { [string]: typeof(Config.Cosmetics.items[1]) } = {}
for _, item in Config.Cosmetics.items do
	itemsById[item.id] = item
end

function Styles.item(cosmeticId: string): typeof(Config.Cosmetics.items[1])?
	return itemsById[cosmeticId]
end

-- The gamepass key that sells a style, if any.
function Styles.passFor(cosmeticId: string): string?
	return passByCosmetic[cosmeticId]
end

function Styles.owns(
	saved: { [string]: boolean },
	passes: { [string]: boolean },
	clubMember: boolean,
	cosmeticId: string
): boolean
	if itemsById[cosmeticId] == nil then
		return false
	end
	if saved[cosmeticId] then
		return true
	end
	local passKey = passByCosmetic[cosmeticId]
	if passKey and passes[passKey] then
		return true
	end
	return clubMember and cosmeticId == Config.Monetization.club.cosmeticId
end

-- Every style the player can use.
function Styles.owned(
	saved: { [string]: boolean },
	passes: { [string]: boolean },
	clubMember: boolean
): { [string]: boolean }
	local owned = {}
	for _, item in Config.Cosmetics.items do
		if Styles.owns(saved, passes, clubMember, item.id) then
			owned[item.id] = true
		end
	end
	return owned
end

return Styles
