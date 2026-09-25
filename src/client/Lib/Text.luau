--!strict
-- Game texts from the localization table src/localization/GameText.csv (Rojo syncs it to
-- LocalizationService.GameText). English is the source language, German is the "de" column; other
-- languages fall back to English. Texts are looked up by key with {name} placeholders.
--
-- UI built in Studio via the Studio MCP marks static texts with a "TextKey" attribute
-- (docs/UI_CONTRACT.md); Text.watch keeps those translated, also after a language switch.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Text = {}

Text.ATTRIBUTE = "TextKey"
Text.TABLE_NAME = "GameText"

local SOURCE_LANGUAGE = "en"

-- Fires after the player's language changed (re-render dynamic texts).
Text.changed = Signal.new() :: Signal.Signal<>

type Entry = { source: string, values: { [string]: string } }

local entries: { [string]: Entry } = {}
local language = SOURCE_LANGUAGE
local translator: Translator? = nil
local roots: { Instance } = {}

local function languageOf(localeId: string): string
	return string.lower(string.sub(localeId, 1, 2))
end

local function loadEntries()
	local localizationTable = LocalizationService:FindFirstChild(Text.TABLE_NAME)
	if localizationTable == nil or not localizationTable:IsA("LocalizationTable") then
		warn(`[Text] LocalizationService.{Text.TABLE_NAME} is missing (Rojo syncs src/localization/GameText.csv)`)
		return
	end
	for _, entry in localizationTable:GetEntries() do
		local row = entry :: any
		if type(row.Key) == "string" and row.Key ~= "" then
			local values: { [string]: string } = {}
			for locale, value in row.Values or {} do
				values[languageOf(locale)] = value
			end
			entries[row.Key] = { source = row.Source, values = values }
		end
	end
end

local function interpolate(text: string, args: { [string]: string }?): string
	if args == nil then
		return text
	end
	return (string.gsub(text, "{(%w+)}", function(name: string): string
		return args[name] or "{" .. name .. "}"
	end))
end

-- The text for `key` in the player's language, with {placeholders} filled from `args`.
-- Unknown keys return the key itself, so missing texts are easy to spot.
function Text.get(key: string, args: { [string]: any }?): string
	local stringArgs: { [string]: string }? = nil
	if args then
		local converted = {}
		for name, value in args do
			converted[name] = tostring(value)
		end
		stringArgs = converted
	end
	local entry = entries[key]
	if entry == nil then
		return key
	end
	local localized = entry.values[language]
	if localized == nil and language ~= SOURCE_LANGUAGE and translator then
		-- Languages without a column: Roblox translations from the cloud table, if there are any.
		local ok, result = pcall(function()
			return (translator :: Translator):FormatByKey(key, stringArgs)
		end)
		if ok and type(result) == "string" then
			return result
		end
	end
	return interpolate(localized or entry.source, stringArgs)
end

function Text.language(): string
	return language
end

local function apply(instance: Instance)
	local key = instance:GetAttribute(Text.ATTRIBUTE)
	if type(key) ~= "string" or key == "" then
		return
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		(instance :: any).Text = Text.get(key)
	elseif instance:IsA("TextBox") then
		instance.PlaceholderText = Text.get(key)
	end
end

-- Translates every element under `root` with a TextKey attribute, now and when elements are added.
function Text.watch(root: Instance)
	table.insert(roots, root)
	for _, descendant in root:GetDescendants() do
		apply(descendant)
	end
	root.DescendantAdded:Connect(apply)
end

local function refreshAll()
	for _, root in roots do
		if root.Parent ~= nil then
			for _, descendant in root:GetDescendants() do
				apply(descendant)
			end
		end
	end
	Text.changed:Fire()
end

local function setLanguage(localeId: string)
	local newLanguage = languageOf(localeId)
	if newLanguage ~= language then
		language = newLanguage
		refreshAll()
	end
end

function Text.init()
	loadEntries()
	language = languageOf(Players.LocalPlayer.LocaleId)
end

-- Loads the player's translator (yields) and follows language changes from the in-game settings.
function Text.start()
	local ok, result = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(Players.LocalPlayer)
	end)
	if not ok then
		return
	end
	local loaded = result :: Translator
	translator = loaded
	setLanguage(loaded.LocaleId)
	loaded:GetPropertyChangedSignal("LocaleId"):Connect(function()
		setLanguage(loaded.LocaleId)
	end)
end

return Text
