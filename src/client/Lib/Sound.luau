--!strict
-- Plays the sound effects from Config.Sounds for the local player only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local SoundLib = {}

local sounds: { [string]: Sound } = {}

function SoundLib.play(key: string?)
	if key == nil or key == "" then
		return
	end
	local definition = (Config.Sounds :: any)[key]
	if definition == nil then
		return
	end
	local sound: Sound? = sounds[key]
	if sound == nil then
		local created = Instance.new("Sound")
		created.Name = `Sfx_{key}`
		created.SoundId = definition.id
		created.Volume = definition.volume
		created.Parent = SoundService
		sounds[key] = created
		sound = created
	end
	SoundService:PlayLocalSound(sound :: Sound)
end

return SoundLib
