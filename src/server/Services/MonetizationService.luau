--!strict
-- Gamepasses, developer products, rewarded video ads and the club subscription.
--
-- ProcessReceipt is idempotent: every PurchaseId is stored in the profile, and PurchaseGranted is only
-- returned once the profile was saved with that id (ProfileStore pattern). Offers with id 0 are not
-- created yet: in Studio they are granted directly for testing, live they show as "Soon".
-- Rewarded video ads (AdService) grant a developer product through the same ProcessReceipt; the receipt
-- then has ProductPurchaseChannel = AdReward. Ads are opt-in (button with the reward on it) and limited
-- per day (Config.Monetization.ads).

local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ads = require(ReplicatedStorage.Shared.Ads)
local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticService = require(script.Parent.CosmeticService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EconomyService = require(script.Parent.EconomyService)
local Events = require(script.Parent.Parent.Lib.Events)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Quests)
local RateLimit = require(script.Parent.Parent.Lib.RateLimit)
local Sessions = require(script.Parent.Parent.Lib.Sessions)
local StateService = require(script.Parent.StateService)
local Types = require(script.Parent.Parent.Lib.Types)

type Session = Types.Session

local MonetizationService = {
	priority = 60,
}

-- Studio has no ads: an ad placement is simulated by granting its product after this many seconds.
local AD_SIMULATION_SECONDS = 2

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

local function today(): number
	return Quests.dayIndex(os.time())
end

-- Passes ----------------------------------------------------------------------------------------------

-- Walk speed from the Speedy Shoes pass.
local function applyPassEffects(session: Session)
	local character = session.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if session.passes.speedyShoes
			then monetization.speedyShoesWalkSpeed
			else Config.Gameplay.walkSpeed
	end
end

-- Grants a pass and everything a bundle includes. `justBought`: the player bought it right now, so a style
-- pass is put on at once.
local function setPass(session: Session, key: string, justBought: boolean?)
	local pass = monetization.gamepasses[key]
	if pass == nil then
		return
	end
	local keys = { key }
	local includes: { string } = pass.includes or {}
	for _, included in includes do
		table.insert(keys, included)
	end
	local changed = false
	for _, passKey in keys do
		if not session.passes[passKey] then
			session.passes[passKey] = true
			changed = true
		end
	end
	if not changed then
		return
	end
	StateService.mark(session, "passes", "cash", "cosmetics", "boost")
	Events.passesChanged:Fire(session)
	applyPassEffects(session)
	if justBought and pass.cosmeticId then
		CosmeticService.equip(session, pass.cosmeticId)
	end
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

-- Club subscription -----------------------------------------------------------------------------------

local function setClubMember(session: Session, member: boolean)
	if session.clubMember == member then
		return
	end
	session.clubMember = member
	StateService.mark(session, "club", "cash", "cosmetics")
	Events.bonusChanged:Fire(session)
	if member then
		StateService.notify(session, "toast.clubWelcome", nil, "big", "reward")
	else
		CosmeticService.dropUnowned(session)
	end
end

local function checkClub(session: Session)
	local id = monetization.club.id
	if id == "" then
		return
	end
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(session.player, id)
	end)
	if session.removed then
		return
	end
	if ok and type(status) == "table" then
		setClubMember(session, status.IsSubscribed == true)
	elseif not ok then
		warn(`[Monetization] Could not check the club subscription: {status}`)
	end
end

local function canBuySubscription(player: Player): boolean
	local ok, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	return ok and type(policy) == "table" and policy.IsEligibleToPurchaseSubscription ~= false
end

-- Products --------------------------------------------------------------------------------------------

local function payCashPack(session: Session, incomeMinutes: number, minimumCash: number)
	local amount = Economy.cashPackAmount(EconomyService.income(session), incomeMinutes, minimumCash)
	EconomyService.earn(session, amount, "purchase")
	StateService.notify(session, "toast.cash", { amount = Format.cash(amount) }, "big", "reward")
end

-- Grants a developer product's content. Errors abort the receipt (it will be retried).
local function grantProduct(session: Session, key: string)
	local product = monetization.products[key]
	assert(product, `unknown product {key}`)
	local kind = product.kind
	if kind == "cash" then
		payCashPack(session, product.incomeMinutes or 0, product.minimumCash or 0)
	elseif kind == "boost" then
		EconomyService.addBoost(session, product.minutes or 0)
		StateService.notify(session, "toast.boost", { minutes = product.minutes or 0 }, "big", "reward")
	elseif kind == "autoCollectTrial" then
		EconomyService.addAutoCollect(session, product.minutes or 0)
		StateService.notify(session, "toast.autoCollect", { minutes = product.minutes or 0 }, "big", "reward")
	elseif kind == "doubleOffline" then
		local pending = session.pendingOffline
		if pending > 0 then
			session.pendingOffline = 0
			EconomyService.earn(session, pending, "purchase")
			StateService.notify(session, "toast.cash", { amount = Format.cash(pending) }, "big", "reward")
		else
			payCashPack(session, product.incomeMinutes or 0, product.minimumCash or 0)
		end
	elseif kind == "starterPack" then
		session.data.oneTime[key] = true
		StateService.mark(session, "store")
		payCashPack(session, product.incomeMinutes or 0, product.minimumCash or 0)
		EconomyService.addBoost(session, product.minutes or 0)
		if product.cosmeticId then
			CosmeticService.grant(session, product.cosmeticId)
		end
	elseif kind == "instantMachine" then
		local purchase = Economy.nextSorterPurchase(session.data.progress, session.passes)
		if purchase then
			EconomyService.grantPurchase(session, purchase.id)
			StateService.notify(session, "toast.bought", { purchaseId = purchase.id }, "big", "reward")
		else
			-- Nothing left to build (e.g. bought twice quickly): cash instead.
			local fallback = monetization.instantMachineFallback
			payCashPack(session, fallback.incomeMinutes, fallback.minimumCash)
		end
	end
end

-- Counts an ad reward against the daily limit of its placement.
local function recordAd(session: Session, productKey: string)
	local placement = Ads.placementForProduct(productKey)
	if placement then
		Ads.record(session.data.ads, today(), placement)
		StateService.mark(session, "ads")
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
	local fromAd = receipt.ProductPurchaseChannel == Enum.ProductPurchaseChannel.AdReward
	return purchaseIdCheckAsync(session, tostring(receipt.PurchaseId), function()
		if fromAd then
			recordAd(session, key)
		end
		grantProduct(session, key)
	end)
end

-- Rewarded video ads ------------------------------------------------------------------------------------

local function onWatchAd(player: Player, placement: any)
	if not RateLimit.allow(player, "WatchAd", 0.2, 2) then
		return
	end
	local session = Sessions.get(player)
	local config = if type(placement) == "string" then monetization.ads[placement] else nil
	if session == nil or config == nil or session.adPlaying then
		return
	end
	if Ads.remaining(session.data.ads, today(), placement) <= 0 then
		StateService.notify(session, "toast.adLimit", nil, "toast", "wrong")
		return
	end
	local product = monetization.products[config.productKey]
	if product.id == 0 then
		if simulate() then
			-- Studio: pretend the video played to the end.
			session.adPlaying = true
			task.delay(AD_SIMULATION_SECONDS, function()
				session.adPlaying = false
				if not session.removed then
					recordAd(session, config.productKey)
					StateService.notify(session, "toast.simulated", { productKey = config.productKey }, "toast", nil)
					grantProduct(session, config.productKey)
				end
			end)
		else
			StateService.notify(session, "toast.unavailable", nil, "toast", nil)
		end
		return
	end
	session.adPlaying = true
	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(product.id)
		local placementId = if config.placementId ~= 0 then config.placementId else nil
		return AdService:ShowRewardedVideoAdAsync(player, reward, placementId)
	end)
	session.adPlaying = false
	-- The reward itself arrives through ProcessReceipt.
	if not ok or result ~= Enum.ShowAdResult.ShowCompleted then
		if not ok then
			warn(`[Monetization] Rewarded video failed: {result}`)
		end
		if not ok or result ~= Enum.ShowAdResult.ShowInterrupted then
			StateService.notify(session, "toast.adUnavailable", nil, "toast", nil)
		end
	end
end

-- Purchase prompts ------------------------------------------------------------------------------------

local function onPurchaseRequest(player: Player, kind: any, key: any)
	if not RateLimit.allow(player, "Purchase", 1, 3) then
		return
	end
	local session = Sessions.get(player)
	if session == nil then
		return
	end
	if kind == "club" then
		local id = monetization.club.id
		if session.clubMember then
			return
		elseif id ~= "" then
			if canBuySubscription(player) then
				MarketplaceService:PromptSubscriptionPurchase(player, id)
			end
		elseif simulate() then
			setClubMember(session, true)
		else
			StateService.notify(session, "toast.unavailable", nil, "toast", nil)
		end
		return
	end
	if type(key) ~= "string" then
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
			setPass(session, key, true)
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
		if product.oneTime and session.data.oneTime[key] then
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
	Net.event(Net.WatchAd).OnServerEvent:Connect(onWatchAd)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyById[passId]
		local session = Sessions.get(player)
		if key and session then
			setPass(session, key, true)
			StateService.notify(session, "toast.purchaseThanks", { passKey = key }, "big", "reward")
		end
	end)
	Players.UserSubscriptionStatusChanged:Connect(function(player, subscriptionId)
		local session = Sessions.get(player)
		if session and subscriptionId == monetization.club.id then
			task.spawn(checkClub, session)
		end
	end)

	Sessions.added:Connect(function(session)
		task.spawn(checkPasses, session)
		task.spawn(checkClub, session)
		session.player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			if not session.removed then
				applyPassEffects(session)
			end
		end)
		if session.player.Character then
			applyPassEffects(session)
		end
	end)
end

-- For other services and the Studio debug hook.
MonetizationService.grantProduct = grantProduct
MonetizationService.setPass = setPass
MonetizationService.setClubMember = setClubMember

return MonetizationService
