--!strict
-- Types shared between server services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataSchema = require(ReplicatedStorage.Shared.DataSchema)
local MapContract = require(ReplicatedStorage.Shared.MapContract)

-- The package a player is carrying.
export type Carry = {
	id: number,
	typeIndex: number,
	typeId: string,
	rare: string?,
	part: BasePart,
	grabbedAt: number,
	grabPosition: Vector3,
}

-- Static layout of one belt slot in a plot (from the map built in Studio).
export type BeltSlot = {
	index: number,
	model: Model,
	conveyor: BasePart,
	layout: MapContract.BeltLayout,
	-- Chute and machine instances (Part or Model), shown once bought.
	spawners: { Instance },
	-- By package type index.
	sorters: { Instance },
	-- Where each machine stands (its part / PrimaryPart) and how far along the belt.
	sorterAnchors: { BasePart },
	sorterPositions: { number },
	packages: Folder,
}

export type Plot = {
	slotIndex: number,
	model: Model,
	belts: { BeltSlot },
	-- By package type index.
	exits: { BasePart },
	collector: BasePart,
	ownerSpawn: BasePart,
	sign: BasePart,
	-- Hidden parts (not bought yet) wait here, outside the workspace.
	stash: Folder,
	originalParents: { [Instance]: Instance },
}

export type Session = {
	player: Player,
	userId: number,
	-- ProfileStore profile.
	profile: any,
	data: DataSchema.PlayerData,
	-- Owned gamepasses by Config.Monetization key (includes Studio test grants).
	passes: { [string]: boolean },
	plot: Plot?,
	carrying: Carry?,
	lastGrab: number,
	lastWrongNotice: number,
	joinedAt: number,
	-- Cash bonus inputs (Economy.cashBonus): friends on this server, group member, club subscriber.
	friendsOnServer: number,
	inGroup: boolean,
	clubMember: boolean,
	-- Offline earnings paid at join, which the "double" product pays once more (this session only).
	pendingOffline: number,
	-- Contextual offers shown this session and when the last one was shown (os.clock()).
	offersShown: { [string]: boolean },
	lastOfferAt: number,
	-- A rewarded video ad is playing.
	adPlaying: boolean,
	-- State sections that changed since the last update to the client.
	dirty: { [string]: boolean },
	removed: boolean,
}

return {}
