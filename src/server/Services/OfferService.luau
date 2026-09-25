--!strict
-- Contextual offers ("right item, right time", Roblox monetization guidelines): a small popup with one
-- pass or product at the moment it helps. Rules (Config.Monetization.offers): at most one popup per
-- cooldown, each offer once per session, never for something the player owns or can't buy, no timers,
-- no pressure. The client shows it in Windows.Offer (docs/UI_CONTRACT.md).
--   * Starter pack: after the first machine (or any later purchase), until it is bought.
--   * Auto Collect: when the cash register is full.
--   * Bigger Warehouse: once the fourth belt could be built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session
type OfferKind = "pass" | "product"

local OfferService = {
	priority = 65,
}

local monetization = Config.Monetization
local rules = monetization.offers

local function purchasable(kind: OfferKind, key: string): boolean
	local entry: { id: number }? = if kind == "pass" then monetization.gamepasses[key] else monetization.products[key]
	if entry == nil then
		return false
	end
	return entry.id ~= 0 or (RunService:IsStudio() and monetization.simulateInStudio)
end

-- Shows an offer if the rules allow it. Returns true if it was shown.
function OfferService.show(session: Session, kind: OfferKind, key: string): boolean
	local offerId = `{kind}:{key}`
	if session.removed or session.offersShown[offerId] or not purchasable(kind, key) then
		return false
	end
	if os.clock() - session.lastOfferAt < rules.cooldownSeconds then
		return false
	end
	session.offersShown[offerId] = true
	session.lastOfferAt = os.clock()
	StateService.notify(session, "", { offerKind = kind, offerKey = key }, "offer", nil)
	return true
end

local function onPurchaseBought(session: Session, _purchaseId: string)
	local progress = session.data.progress
	if Economy.owns(progress, rules.starterPackAfter) and not session.data.oneTime.starterPack then
		if OfferService.show(session, "product", "starterPack") then
			return
		end
	end
	if Economy.owns(progress, rules.biggerWarehouseAfter) and not session.passes.biggerWarehouse then
		OfferService.show(session, "pass", "biggerWarehouse")
	end
end

local function onCollectorFull(session: Session)
	if rules.autoCollectWhenFull and not EconomyService.hasAutoCollect(session) then
		OfferService.show(session, "pass", "autoCollect")
	end
end

function OfferService.init()
	Events.purchaseBought:Connect(onPurchaseBought)
	Events.collectorFull:Connect(onCollectorFull)
end

return OfferService
