--!strict
-- Localized names for the ids the server and the config use (packages, upgrades, machines, passes,
-- products, cosmetics), and the argument resolution for server notices.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)

local Names = {}

local function zone(): string
	local progress = State.progress()
	return if progress then progress.zone else Config.Zones.startingZone
end

function Names.packageType(typeIndex: number): string
	local packageType = Economy.packageTypeAt(zone(), typeIndex)
	return if packageType then Text.get(`package.{packageType.id}`) else "?"
end

function Names.destination(typeId: string): string
	return Text.get(`dest.{typeId}`)
end

function Names.upgrade(trackId: string): string
	return Text.get(`upgrade.{trackId}.name`)
end

function Names.purchase(purchaseId: string): string
	local purchase = Economy.findPurchase(purchaseId)
	if purchase == nil then
		return purchaseId
	end
	if purchase.kind == "sorter" then
		local typeName = Names.packageType(purchase.typeIndex or 1)
		if purchase.belt == 1 then
			return Text.get("purchase.sorter", { type = typeName })
		end
		return Text.get("purchase.sorterBelt", { type = typeName, belt = purchase.belt or 1 })
	elseif purchase.kind == "belt" then
		return Text.get("purchase.belt", { belt = purchase.belt or 1 })
	end
	return Text.get(`purchase.{purchase.id}`)
end

function Names.purchaseDescription(purchaseId: string): string
	local purchase = Economy.findPurchase(purchaseId)
	if purchase == nil then
		return ""
	end
	if purchase.kind == "sorter" then
		return Text.get("purchase.sorter.desc", { type = Names.packageType(purchase.typeIndex or 1) })
	end
	return Text.get(`purchase.{purchase.kind}.desc`)
end

function Names.pass(key: string): string
	local pass = Config.Monetization.gamepasses[key]
	if pass and pass.cosmeticId then
		return Text.get(`cosmetic.{pass.cosmeticId}`)
	end
	return Text.get(`pass.{key}.name`)
end

function Names.cosmetic(cosmeticId: string): string
	return Text.get(`cosmetic.{cosmeticId}`)
end

function Names.product(key: string): string
	return Text.get(`product.{key}.name`)
end

-- Server notices name things by id (Net.Notice); this turns them into the {name}/{destination}/...
-- arguments the texts expect.
function Names.noticeArgs(args: { [string]: any }?): { [string]: any }?
	if args == nil then
		return nil
	end
	local resolved = table.clone(args)
	if type(args.trackId) == "string" then
		resolved.name = Names.upgrade(args.trackId)
	elseif type(args.purchaseId) == "string" then
		resolved.name = Names.purchase(args.purchaseId)
	elseif type(args.cosmeticId) == "string" then
		resolved.name = Names.cosmetic(args.cosmeticId)
	elseif type(args.passKey) == "string" then
		resolved.name = Names.pass(args.passKey)
	elseif type(args.productKey) == "string" then
		resolved.name = Names.product(args.productKey)
	end
	if type(args.typeId) == "string" then
		resolved.destination = Names.destination(args.typeId)
	end
	if type(args.zoneId) == "string" then
		resolved.zone = Text.get(`zone.{args.zoneId}`)
	end
	return resolved
end

return Names
