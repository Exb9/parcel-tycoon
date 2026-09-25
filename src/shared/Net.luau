--!strict
-- Remote names in one place. The server creates them at startup; clients wait for them.
-- Clients only send intents; the server validates every argument (see the handling service).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.FOLDER = "Remotes"

-- Client -> server
Net.Grab = "Grab" -- (packageId: number)
Net.BuyUpgrade = "BuyUpgrade" -- (trackId: string)
Net.BuyPurchase = "BuyPurchase" -- (purchaseId: string)
Net.Rebirth = "Rebirth" -- ()
Net.ClaimQuest = "ClaimQuest" -- (questId: string)
Net.ClaimDaily = "ClaimDaily" -- ()
Net.Purchase = "Purchase" -- (kind: "pass" | "product" | "club", key: string)
Net.Equip = "Equip" -- (slot: string, cosmeticId: string) ; "" = default look
Net.RequestState = "RequestState" -- ()
Net.WatchAd = "WatchAd" -- (placement: string) ; Config.Monetization.ads key
Net.ClaimGift = "ClaimGift" -- () ; next playtime gift
Net.RedeemCode = "RedeemCode" -- (code: string)
Net.CheckGroup = "CheckGroup" -- () ; after the group join prompt
Net.ClaimClubGift = "ClaimClubGift" -- ()

-- Server -> client
Net.State = "State" -- (patch: { [section]: any }, full: boolean)
Net.Notify = "Notify" -- (notice: Notice)

export type Notice = {
	-- Text key (src/localization/GameText.csv) and arguments; the client localizes. Things are named by id
	-- (trackId, purchaseId, passKey, productKey, cosmeticId, typeId), the client turns them into names.
	key: string,
	args: { [string]: any }?,
	-- "toast" (small), "big" (center), "silent" (sound only), "welcome" (welcome-back window, args.amount),
	-- "offer" (offer window, args.offerKind = "pass" | "product", args.offerKey)
	style: string?,
	-- Config.Sounds key.
	sound: string?,
}

local NAMES = {
	Net.Grab,
	Net.BuyUpgrade,
	Net.BuyPurchase,
	Net.Rebirth,
	Net.ClaimQuest,
	Net.ClaimDaily,
	Net.Purchase,
	Net.Equip,
	Net.RequestState,
	Net.WatchAd,
	Net.ClaimGift,
	Net.RedeemCode,
	Net.CheckGroup,
	Net.ClaimClubGift,
	Net.State,
	Net.Notify,
}

-- Server only: creates the remotes.
function Net.setupServer()
	assert(RunService:IsServer(), "Net.setupServer runs on the server")
	local folder = ReplicatedStorage:FindFirstChild(Net.FOLDER)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = Net.FOLDER
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Net.event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER)
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} is not a RemoteEvent`)
	return remote
end

return Net
