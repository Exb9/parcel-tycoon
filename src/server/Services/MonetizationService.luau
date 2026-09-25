--!strict
-- Gamepasses and developer products.
--
-- ProcessReceipt is idempotent: every PurchaseId is stored in the profile, and PurchaseGranted is only
-- returned once the profile was saved with that id (ProfileStore pattern). Offers with id 0 are not
-- created yet: in Studio they are granted directly for testing, live they show as "Soon".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticService = require(script.Parent.CosmeticService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local MonetizationService = {
	priority = 60,
}

local monetization = Config.Monetization
local isStudio = RunService:IsStudio()

local passKeyById: { [number]: string } = {}
for key, pass in monetization.gamepasses do
	if pass.id ~= 0 then
		passKeyById[pass.id] = key
	end
end

local productKeyById: { [number]: string } = {}
for key, product in monetization.products do
	if product.id ~= 0 then
		productKeyById[product.id] = key
	end
end

local function simulate(): boolean
	return isStudio and monetization.simulateInStudio
end

local function setPass(session: Session, key: string)
	if session.passes[key] then
		return
	end
	session.passes[key] = true
	StateService.mark(session, "passes", "cash")
	Events.passesChanged:Fire(session)
end

local function checkPasses(session: Session)
	for key, pass in monetization.gamepasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(session.userId, pass.id)
			end)
			if session.removed then
				return
			end
			if ok and owns then
				setPass(session, key)
			elseif not ok then
				warn(`[Monetization] Could not check pass {key}: {owns}`)
			end
		end
	end
end

-- Grants a developer product's content. Errors abort the receipt (it will be retried).
local function grantProduct(session: Session, key: string)
	local product = monetization.products[key]
	assert(product, `unknown product {key}`)
	if product.kind == "cash" then
		local amount =
			Economy.cashPackAmount(EconomyService.income(session), product.incomeMinutes or 0, product.minimumCash or 0)
		EconomyService.earn(session, amount, "purchase")
		StateService.notify(session, "toast.cash", { amount = Format.cash(amount) }, "big", "reward")
	elseif product.kind == "boost" then
		EconomyService.addBoost(session, product.minutes or 0)
		StateService.notify(session, "toast.boost", { minutes = product.minutes or 0 }, "big", "reward")
	elseif product.kind == "instantMachine" then
		local purchase = Economy.nextSorterPurchase(session.data.progress, session.passes)
		if purchase then
			EconomyService.grantPurchase(session, purchase.id)
			StateService.notify(session, "toast.bought", { purchaseId = purchase.id }, "big", "reward")
		else
			-- Nothing left to build (e.g. bought twice quickly): cash instead.
			local fallback = monetization.instantMachineFallback
			local amount =
				Economy.cashPackAmount(EconomyService.income(session), fallback.incomeMinutes, fallback.minimumCash)
			EconomyService.earn(session, amount, "purchase")
			StateService.notify(session, "toast.cash", { amount = Format.cash(amount) }, "big", "reward")
		end
	elseif product.kind == "cosmetic" then
		if product.cosmeticId then
			CosmeticService.grant(session, product.cosmeticId)
		end
	end
end

local function purchaseIdCheckAsync(session: Session, purchaseId: string, grant: () -> ()): Enum.ProductPurchaseDecision
	local profile = session.profile
	if not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseIds = session.data.purchaseIds
	if table.find(purchaseIds, purchaseId) == nil then
		local ok, err = pcall(grant :: any)
		if not ok then
			warn(`[Monetization] Granting purchase {purchaseId} failed: {err}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		while #purchaseIds >= monetization.purchaseIdCacheSize do
			table.remove(purchaseIds, 1)
		end
		table.insert(purchaseIds, purchaseId)
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData
		local savedIds = saved and saved.purchaseIds
		return savedIds ~= nil and table.find(savedIds, purchaseId) ~= nil
	end
	if isSaved() then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	while profile:IsActive() do
		local lastSaved = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == lastSaved then
			profile.OnAfterSave:Wait()
		end
		if isSaved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local key = productKeyById[receipt.ProductId]
	if key == nil then
		warn(`[Monetization] Receipt for unknown product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local session = player and Sessions.get(player)
	if session == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return purchaseIdCheckAsync(session, tostring(receipt.PurchaseId), function()
		grantProduct(session, key)
	end)
end

local function onPurchaseRequest(player: Player, kind: any, key: any)
	if not RateLimit.allow(player, "Purchase", 1, 3) then
		return
	end
	local session = Sessions.get(player)
	if session == nil or type(key) ~= "string" then
		return
	end
	if kind == "pass" then
		local pass = monetization.gamepasses[key]
		if pass == nil or session.passes[key] then
			return
		end
		if pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		elseif simulate() then
			setPass(session, key)
			StateService.notify(session, "toast.simulated", { passKey = key }, "big", "reward")
		else
			StateService.notify(session, "toast.unavailable", nil, "toast", nil)
		end
	elseif kind == "product" then
		local product = monetization.products[key]
		if product == nil then
			return
		end
		if
			product.kind == "instantMachine"
			and Economy.nextSorterPurchase(session.data.progress, session.passes) == nil
		then
			StateService.notify(session, "store.noMachine", nil, "toast", "wrong")
			return
		end
		if product.kind == "cosmetic" and product.cosmeticId and CosmeticService.owns(session, product.cosmeticId) then
			return
		end
		if product.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.id)
		elseif simulate() then
			StateService.notify(session, "toast.simulated", { productKey = key }, "toast", nil)
			grantProduct(session, key)
		else
			StateService.notify(session, "toast.unavailable", nil, "toast", nil)
		end
	end
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	Net.event(Net.Purchase).OnServerEvent:Connect(onPurchaseRequest)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyById[passId]
		local session = Sessions.get(player)
		if key and session then
			setPass(session, key)
			StateService.notify(session, "toast.purchaseThanks", { passKey = key }, "big", "reward")
		end
	end)

	Sessions.added:Connect(function(session)
		task.spawn(checkPasses, session)
	end)
end

-- For the Studio debug hook.
MonetizationService.grantProduct = grantProduct
MonetizationService.setPass = setPass

return MonetizationService
