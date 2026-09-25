--!strict
-- UI texts in English (default) and German. Clients pick the language from the player's Roblox locale.
-- Placeholders use {name} syntax. tests/strings.spec.luau checks both tables have the same keys.

local Strings = {}

local en: { [string]: string } = {
	-- HUD
	["hud.perMinute"] = "{amount}/min",
	["hud.boost"] = "2x Cash {time}",
	["hud.carry"] = "Take it to {destination}!",
	["hud.carryAny"] = "Mystery box! Any chute works.",
	["hud.carryFragile"] = "Fragile! Don't jump.",
	["hud.carryHeavy"] = "Heavy! You walk slower.",
	["hud.express"] = "Express bonus {time}",
	["hud.drop"] = "Drop",
	["hud.collectorFull"] = "Cash register full!",

	-- Menu
	["menu.shop"] = "Shop",
	["menu.store"] = "Store",
	["menu.quests"] = "Quests",
	["menu.daily"] = "Daily",
	["menu.rebirth"] = "Rebirth",
	["menu.style"] = "Style",
	["menu.invite"] = "Invite",
	["menu.help"] = "Help",

	-- Shop
	["shop.title"] = "Shop",
	["shop.tabUpgrades"] = "Upgrades",
	["shop.tabMachines"] = "Machines",
	["shop.level"] = "Level {level}/{max}",
	["shop.max"] = "MAX",
	["shop.buy"] = "Buy",
	["shop.allBuilt"] = "Everything is built! Time for a rebirth?",
	["shop.needsPass"] = "Needs {pass}",

	["upgrade.beltSpeed.name"] = "Belt Speed",
	["upgrade.beltSpeed.desc"] = "+10% parcels on every belt",
	["upgrade.packageValue.name"] = "Bigger Parcels",
	["upgrade.packageValue.desc"] = "+15% cash per parcel",
	["upgrade.sorterSpeed.name"] = "Machine Speed",
	["upgrade.sorterSpeed.desc"] = "Machines sort 20% faster",
	["upgrade.sorterAccuracy.name"] = "Machine Accuracy",
	["upgrade.sorterAccuracy.desc"] = "Machines sort {percent} correctly",
	["upgrade.collectorCapacity.name"] = "Bigger Cash Register",
	["upgrade.collectorCapacity.desc"] = "Holds 10 more minutes of machine cash",
	["upgrade.offlineCap.name"] = "Night Shift",
	["upgrade.offlineCap.desc"] = "Machines earn 2 more hours while you are away",

	["purchase.sorter"] = "{type} Sorter",
	["purchase.sorterBelt"] = "{type} Sorter (Belt {belt})",
	["purchase.spawner2"] = "Second Chute",
	["purchase.spawner3"] = "Third Chute",
	["purchase.belt"] = "Belt {belt}",
	["purchase.sorter.desc"] = "Sorts {type} parcels automatically",
	["purchase.spawner.desc"] = "More parcels on every belt",
	["purchase.belt.desc"] = "A new belt with its own parcels",

	-- Packages
	["package.letter"] = "Letter",
	["package.box"] = "Box",
	["package.crate"] = "Crate",
	["package.suitcase"] = "Suitcase",
	["package.mailSack"] = "Mail Sack",
	["package.pallet"] = "Pallet",
	["dest.letter"] = "TOWN",
	["dest.box"] = "COUNTRY",
	["dest.crate"] = "WORLD",
	["dest.suitcase"] = "GATE A",
	["dest.mailSack"] = "GATE B",
	["dest.pallet"] = "GATE C",
	["rare.golden"] = "Golden",
	["rare.fragile"] = "Fragile",
	["rare.mystery"] = "Mystery",

	-- Zones
	["zone.postOffice"] = "Post Office",
	["zone.airportCargo"] = "Airport Cargo",
	["zone.spaceHub"] = "Space Hub",

	-- Store
	["store.title"] = "Store",
	["store.passes"] = "Passes",
	["store.products"] = "Cash & Boosts",
	["store.styles"] = "Styles",
	["store.owned"] = "Owned",
	["store.soon"] = "Soon",
	["store.test"] = "Test",
	["store.noMachine"] = "No machine to build right now",

	["pass.doubleCash.name"] = "2x Cash",
	["pass.doubleCash.desc"] = "Doubles all cash you earn.",
	["pass.autoCollect.name"] = "Auto Collect",
	["pass.autoCollect.desc"] = "Machine cash goes straight to you. No cash register limit.",
	["pass.vip.name"] = "VIP",
	["pass.vip.desc"] = "VIP lounge, free daily boost, VIP chat tag and +10% cash.",
	["pass.fastBelts.name"] = "Fast Belts",
	["pass.fastBelts.desc"] = "25% more parcels on every belt.",
	["pass.biggerWarehouse.name"] = "Bigger Warehouse",
	["pass.biggerWarehouse.desc"] = "Unlocks a fourth belt you can build with cash.",

	["product.cashSmall.name"] = "Cash Stack",
	["product.cashMedium.name"] = "Cash Bag",
	["product.cashLarge.name"] = "Cash Truck",
	["product.cash.desc"] = "Get {amount} now",
	["product.cashBoost.name"] = "2x Cash Boost",
	["product.cashBoost.desc"] = "Double cash for {minutes} minutes",
	["product.instantMachine.name"] = "Instant Machine",
	["product.instantMachine.desc"] = "Builds your next sorting machine: {name}",
	["product.cosmetic.desc"] = "Unlock forever",

	-- Quests
	["quests.title"] = "Quests",
	["quests.tutorial"] = "Getting started",
	["quests.daily"] = "Daily quests",
	["quests.claim"] = "Claim",
	["quests.claimed"] = "Done",
	["quests.newIn"] = "New quests in {time}",
	["quests.reward"] = "Reward: {amount}",
	["quest.grab"] = "Pick up {target} parcel",
	["quest.sortManual"] = "Sort {target} parcels by hand",
	["quest.sortType"] = "Sort {target} {type} parcels",
	["quest.sortMachine"] = "Machines sort {target} parcels",
	["quest.sortRare"] = "Sort {target} rare parcel",
	["quest.earn"] = "Earn {amount}",
	["quest.buyUpgrades"] = "Buy {target} upgrades",
	["quest.buyPurchase"] = "Build the {name}",
	["quest.collect"] = "Empty your cash register {target}x",
	["tutorial.grab"] = "Walk to the end of the belt and pick up a parcel.",
	["tutorial.sortManual"] = "Carry parcels to the chute with the same color!",
	["tutorial.buyUpgrades"] = "Open the Shop and buy an upgrade.",
	["tutorial.buyPurchase"] = "Build your first sorting machine in the Shop.",
	["tutorial.collect"] = "Machines fill your cash register. Walk over it to collect!",

	-- Daily rewards
	["daily.title"] = "Daily Rewards",
	["daily.day"] = "Day {day}",
	["daily.claim"] = "Claim",
	["daily.comeBack"] = "Come back tomorrow for the next reward!",
	["daily.gifts"] = "Playtime gifts",
	["daily.giftAfter"] = "{minutes} min",
	["daily.giftReady"] = "Open",

	-- Rebirth
	["rebirth.title"] = "Rebirth",
	["rebirth.desc"] = "Start over with a permanent income bonus.",
	["rebirth.cost"] = "Needs {amount}",
	["rebirth.bonus"] = "Income x{from} -> x{to}",
	["rebirth.keep"] = "You keep: Night Shift, Bigger Cash Register, styles and passes.",
	["rebirth.zone"] = "Your warehouse moves to {zone}!",
	["rebirth.nextZone"] = "{zone} unlocks at {rebirths} rebirths.",
	["rebirth.button"] = "Rebirth!",

	-- Style
	["style.title"] = "Style",
	["style.trail"] = "Trails",
	["style.belt"] = "Belts",
	["style.floor"] = "Floors",
	["style.equip"] = "Use",
	["style.equipped"] = "In use",
	["style.default"] = "Default",
	["style.earn"] = "Find it in the game",

	-- Help
	["help.title"] = "How to play",
	["help.text"] = "Pick up parcels at the end of the belt and carry them to the chute with the same color. Buy upgrades and sorting machines in the Shop. Machines put cash into your cash register: walk over it to collect.",
	["help.rare"] = "Rare parcels: Golden (10x cash), Fragile (4x cash, don't jump!), Mystery (a surprise, any chute works).",
	["help.mysteryOdds"] = "Mystery box odds",
	["reward.smallCash"] = "Some cash",
	["reward.bigCash"] = "Lots of cash",
	["reward.boost"] = "2x Cash boost",
	["reward.jackpot"] = "Jackpot",
	["reward.sparkleTrail"] = "Sparkle Trail",

	-- Toasts
	["toast.sorted"] = "+{amount}",
	["toast.wrong"] = "Wrong chute! Find {destination}.",
	["toast.broken"] = "Oops! The fragile parcel broke.",
	["toast.golden"] = "Golden parcel! +{amount}",
	["toast.express"] = "Express bonus! +{amount}",
	["toast.mysteryCash"] = "Mystery box: +{amount}!",
	["toast.mysteryBoost"] = "Mystery box: 2x Cash for {minutes} min!",
	["toast.collected"] = "Collected {amount}",
	["toast.collectorFull"] = "Your cash register is full. Collect it!",
	["toast.bought"] = "Bought: {name}",
	["toast.notEnough"] = "Not enough cash",
	["toast.questDone"] = "Quest complete!",
	["toast.tutorialReward"] = "Well done! +{amount}",
	["toast.offline"] = "Welcome back! Your machines earned {amount}.",
	["toast.boost"] = "2x Cash for {minutes} min!",
	["toast.cash"] = "+{amount}",
	["toast.cosmetic"] = "New style unlocked: {name}",
	["toast.rebirth"] = "Rebirth! Your income is now x{multiplier}",
	["toast.zone"] = "Welcome to {zone}!",
	["toast.simulated"] = "Studio test purchase: {name}",
	["toast.referral"] = "A friend joined through your invite! +{amount}",
	["toast.welcome"] = "Welcome! Here is a gift from your friend: +{amount}",
	["toast.dropped"] = "Parcel dropped",
	["toast.unavailable"] = "Coming soon!",
	["toast.purchaseThanks"] = "Thank you! {name}",

	-- World
	["world.collector"] = "Cash Register",
	["world.collectorFull"] = "FULL - walk over me!",

	-- Common
	["common.close"] = "X",
}

local de: { [string]: string } = {
	["hud.perMinute"] = "{amount}/Min",
	["hud.boost"] = "2x Geld {time}",
	["hud.carry"] = "Bring es zu {destination}!",
	["hud.carryAny"] = "Überraschungspaket! Jede Rutsche passt.",
	["hud.carryFragile"] = "Zerbrechlich! Nicht springen.",
	["hud.carryHeavy"] = "Schwer! Du läufst langsamer.",
	["hud.express"] = "Express-Bonus {time}",
	["hud.drop"] = "Ablegen",
	["hud.collectorFull"] = "Kasse voll!",

	["menu.shop"] = "Shop",
	["menu.store"] = "Store",
	["menu.quests"] = "Quests",
	["menu.daily"] = "Täglich",
	["menu.rebirth"] = "Rebirth",
	["menu.style"] = "Style",
	["menu.invite"] = "Einladen",
	["menu.help"] = "Hilfe",

	["shop.title"] = "Shop",
	["shop.tabUpgrades"] = "Upgrades",
	["shop.tabMachines"] = "Maschinen",
	["shop.level"] = "Stufe {level}/{max}",
	["shop.max"] = "MAX",
	["shop.buy"] = "Kaufen",
	["shop.allBuilt"] = "Alles gebaut! Zeit für einen Rebirth?",
	["shop.needsPass"] = "Braucht {pass}",

	["upgrade.beltSpeed.name"] = "Bandtempo",
	["upgrade.beltSpeed.desc"] = "+10% Pakete auf jedem Band",
	["upgrade.packageValue.name"] = "Größere Pakete",
	["upgrade.packageValue.desc"] = "+15% Geld pro Paket",
	["upgrade.sorterSpeed.name"] = "Maschinentempo",
	["upgrade.sorterSpeed.desc"] = "Maschinen sortieren 20% schneller",
	["upgrade.sorterAccuracy.name"] = "Maschinen-Genauigkeit",
	["upgrade.sorterAccuracy.desc"] = "Maschinen sortieren {percent} richtig",
	["upgrade.collectorCapacity.name"] = "Größere Kasse",
	["upgrade.collectorCapacity.desc"] = "Hält 10 Minuten mehr Maschinengeld",
	["upgrade.offlineCap.name"] = "Nachtschicht",
	["upgrade.offlineCap.desc"] = "Maschinen verdienen 2 Stunden länger, wenn du weg bist",

	["purchase.sorter"] = "{type}-Sortierer",
	["purchase.sorterBelt"] = "{type}-Sortierer (Band {belt})",
	["purchase.spawner2"] = "Zweite Rutsche",
	["purchase.spawner3"] = "Dritte Rutsche",
	["purchase.belt"] = "Band {belt}",
	["purchase.sorter.desc"] = "Sortiert {type}-Pakete automatisch",
	["purchase.spawner.desc"] = "Mehr Pakete auf jedem Band",
	["purchase.belt.desc"] = "Ein neues Band mit eigenen Paketen",

	["package.letter"] = "Brief",
	["package.box"] = "Karton",
	["package.crate"] = "Kiste",
	["package.suitcase"] = "Koffer",
	["package.mailSack"] = "Postsack",
	["package.pallet"] = "Palette",
	["dest.letter"] = "STADT",
	["dest.box"] = "LAND",
	["dest.crate"] = "WELT",
	["dest.suitcase"] = "GATE A",
	["dest.mailSack"] = "GATE B",
	["dest.pallet"] = "GATE C",
	["rare.golden"] = "Golden",
	["rare.fragile"] = "Zerbrechlich",
	["rare.mystery"] = "Überraschung",

	["zone.postOffice"] = "Postamt",
	["zone.airportCargo"] = "Flughafen-Cargo",
	["zone.spaceHub"] = "Weltraum-Hub",

	["store.title"] = "Store",
	["store.passes"] = "Pässe",
	["store.products"] = "Geld & Boosts",
	["store.styles"] = "Styles",
	["store.owned"] = "Gekauft",
	["store.soon"] = "Bald",
	["store.test"] = "Test",
	["store.noMachine"] = "Gerade keine Maschine zum Bauen",

	["pass.doubleCash.name"] = "2x Geld",
	["pass.doubleCash.desc"] = "Verdoppelt all dein Geld.",
	["pass.autoCollect.name"] = "Auto-Einsammeln",
	["pass.autoCollect.desc"] = "Maschinengeld kommt direkt zu dir. Kein Kassen-Limit.",
	["pass.vip.name"] = "VIP",
	["pass.vip.desc"] = "VIP-Lounge, täglicher Gratis-Boost, VIP-Chat-Tag und +10% Geld.",
	["pass.fastBelts.name"] = "Schnelle Bänder",
	["pass.fastBelts.desc"] = "25% mehr Pakete auf jedem Band.",
	["pass.biggerWarehouse.name"] = "Größere Halle",
	["pass.biggerWarehouse.desc"] = "Schaltet ein viertes Band frei, das du mit Geld baust.",

	["product.cashSmall.name"] = "Geldstapel",
	["product.cashMedium.name"] = "Geldsack",
	["product.cashLarge.name"] = "Geldtransporter",
	["product.cash.desc"] = "Sofort {amount}",
	["product.cashBoost.name"] = "2x-Geld-Boost",
	["product.cashBoost.desc"] = "Doppeltes Geld für {minutes} Minuten",
	["product.instantMachine.name"] = "Sofort-Maschine",
	["product.instantMachine.desc"] = "Baut deine nächste Sortiermaschine: {name}",
	["product.cosmetic.desc"] = "Für immer freischalten",

	["quests.title"] = "Quests",
	["quests.tutorial"] = "Erste Schritte",
	["quests.daily"] = "Tägliche Quests",
	["quests.claim"] = "Abholen",
	["quests.claimed"] = "Erledigt",
	["quests.newIn"] = "Neue Quests in {time}",
	["quests.reward"] = "Belohnung: {amount}",
	["quest.grab"] = "Heb {target} Paket auf",
	["quest.sortManual"] = "Sortiere {target} Pakete von Hand",
	["quest.sortType"] = "Sortiere {target} {type}-Pakete",
	["quest.sortMachine"] = "Maschinen sortieren {target} Pakete",
	["quest.sortRare"] = "Sortiere {target} seltenes Paket",
	["quest.earn"] = "Verdiene {amount}",
	["quest.buyUpgrades"] = "Kaufe {target} Upgrades",
	["quest.buyPurchase"] = "Baue den {name}",
	["quest.collect"] = "Leere deine Kasse {target}x",
	["tutorial.grab"] = "Lauf zum Ende des Bands und heb ein Paket auf.",
	["tutorial.sortManual"] = "Bring Pakete zur Rutsche mit der gleichen Farbe!",
	["tutorial.buyUpgrades"] = "Öffne den Shop und kauf ein Upgrade.",
	["tutorial.buyPurchase"] = "Bau im Shop deine erste Sortiermaschine.",
	["tutorial.collect"] = "Maschinen füllen deine Kasse. Lauf drüber zum Einsammeln!",

	["daily.title"] = "Tägliche Belohnungen",
	["daily.day"] = "Tag {day}",
	["daily.claim"] = "Abholen",
	["daily.comeBack"] = "Komm morgen für die nächste Belohnung wieder!",
	["daily.gifts"] = "Spielzeit-Geschenke",
	["daily.giftAfter"] = "{minutes} Min",
	["daily.giftReady"] = "Öffnen",

	["rebirth.title"] = "Rebirth",
	["rebirth.desc"] = "Fang neu an mit einem dauerhaften Einkommensbonus.",
	["rebirth.cost"] = "Braucht {amount}",
	["rebirth.bonus"] = "Einkommen x{from} -> x{to}",
	["rebirth.keep"] = "Du behältst: Nachtschicht, Größere Kasse, Styles und Pässe.",
	["rebirth.zone"] = "Deine Halle zieht um: {zone}!",
	["rebirth.nextZone"] = "{zone} kommt bei {rebirths} Rebirths.",
	["rebirth.button"] = "Rebirth!",

	["style.title"] = "Style",
	["style.trail"] = "Spuren",
	["style.belt"] = "Bänder",
	["style.floor"] = "Böden",
	["style.equip"] = "Nutzen",
	["style.equipped"] = "Aktiv",
	["style.default"] = "Standard",
	["style.earn"] = "Im Spiel zu finden",

	["help.title"] = "So wird gespielt",
	["help.text"] = "Heb Pakete am Ende des Bands auf und bring sie zur Rutsche mit der gleichen Farbe. Im Shop kaufst du Upgrades und Sortiermaschinen. Maschinen legen Geld in deine Kasse: lauf drüber zum Einsammeln.",
	["help.rare"] = "Seltene Pakete: Golden (10x Geld), Zerbrechlich (4x Geld, nicht springen!), Überraschung (jede Rutsche passt).",
	["help.mysteryOdds"] = "Chancen im Überraschungspaket",
	["reward.smallCash"] = "Etwas Geld",
	["reward.bigCash"] = "Viel Geld",
	["reward.boost"] = "2x-Geld-Boost",
	["reward.jackpot"] = "Jackpot",
	["reward.sparkleTrail"] = "Glitzerspur",

	["toast.sorted"] = "+{amount}",
	["toast.wrong"] = "Falsche Rutsche! Such {destination}.",
	["toast.broken"] = "Hoppla! Das zerbrechliche Paket ist kaputt.",
	["toast.golden"] = "Goldenes Paket! +{amount}",
	["toast.express"] = "Express-Bonus! +{amount}",
	["toast.mysteryCash"] = "Überraschung: +{amount}!",
	["toast.mysteryBoost"] = "Überraschung: 2x Geld für {minutes} Min!",
	["toast.collected"] = "{amount} eingesammelt",
	["toast.collectorFull"] = "Deine Kasse ist voll. Sammle sie ein!",
	["toast.bought"] = "Gekauft: {name}",
	["toast.notEnough"] = "Nicht genug Geld",
	["toast.questDone"] = "Quest geschafft!",
	["toast.tutorialReward"] = "Super! +{amount}",
	["toast.offline"] = "Willkommen zurück! Deine Maschinen haben {amount} verdient.",
	["toast.boost"] = "2x Geld für {minutes} Min!",
	["toast.cash"] = "+{amount}",
	["toast.cosmetic"] = "Neuer Style: {name}",
	["toast.rebirth"] = "Rebirth! Dein Einkommen ist jetzt x{multiplier}",
	["toast.zone"] = "Willkommen im {zone}!",
	["toast.simulated"] = "Studio-Testkauf: {name}",
	["toast.referral"] = "Ein Freund ist über deine Einladung gekommen! +{amount}",
	["toast.welcome"] = "Willkommen! Ein Geschenk von deinem Freund: +{amount}",
	["toast.dropped"] = "Paket abgelegt",
	["toast.unavailable"] = "Kommt bald!",
	["toast.purchaseThanks"] = "Danke! {name}",

	["world.collector"] = "Kasse",
	["world.collectorFull"] = "VOLL - lauf über mich!",

	["common.close"] = "X",
}

local tables: { [string]: { [string]: string } } = { en = en, de = de }
local current = en

-- Accepts Roblox locale ids like "de-de" or "en-us".
function Strings.setLocale(localeId: string)
	local language = string.lower(string.sub(localeId, 1, 2))
	current = tables[language] or en
end

function Strings.language(): string
	return if current == de then "de" else "en"
end

function Strings.get(key: string, args: { [string]: any }?): string
	local text = current[key] or en[key] or key
	if args then
		text = string.gsub(text, "{(%w+)}", function(name: string)
			local value = args[name]
			return if value ~= nil then tostring(value) else "{" .. name .. "}"
		end)
	end
	return text
end

-- For tests: both language tables.
Strings.tables = tables

return Strings
