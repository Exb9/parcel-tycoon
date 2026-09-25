# Projekt: Parcel Tycoon – Roblox Simulator/Tycoon

## Projektgedächtnis
Dieses Projekt ist im homelab-Connector als `parcel-tycoon` registriert.
Zu Beginn einer Session `project_brief` aufrufen, am Ende `checkpoint_save`.
Nicht-offensichtliche Entscheidungen mit `decision_record` festhalten.

## Ziel
Ein Roblox-Spiel, das Simulator und Tycoon mischt: Spieler sortieren Pakete von
einem Fließband in die richtigen Ausgänge, verdienen damit Geld und kaufen
Maschinen, die das Sortieren nach und nach automatisieren. Zielgruppe: jüngere
Roblox-Spieler. Das Spiel soll sich gut monetarisieren lassen, aber fair bleiben
(kein Pay-to-Win, das Free-Spieler frustriert).

## Tooling
- **Rojo** für den gesamten Luau-Code: Code liegt als Dateien im Repo, wird per
  `rojo serve` live in Studio gesynct. Git-Repo von Anfang an.
- **Roblox Studio MCP** für alles, was in Studio gebaut werden muss: Map,
  Lagerhalle, Fließbänder, Maschinenmodelle, Platzhalter-Parts.
- Klare Trennung: Logik immer in Rojo-Dateien, nie als Script direkt in Studio.
- Luau mit `--!strict`, Wally als Package-Manager, Selene + StyLua für Linting/Formatierung.
- Code, Variablennamen und Commits auf Englisch. Erklärungen an mich auf Deutsch.

## Architektur
- **Server-authoritative**: Geld, Upgrades, Käufe und Sortier-Ergebnisse werden
  ausschließlich auf dem Server berechnet. Client sendet nur Absichten
  (z. B. "Paket X in Ausgang Y"), Server validiert (Distanz, Cooldown, Besitz).
- Datenpersistenz über ProfileStore (oder vergleichbar, Session-Locking Pflicht).
  Schema versioniert, Migration von Anfang an mitdenken.
- Ordnerstruktur: `src/server`, `src/client`, `src/shared`. Konfiguration
  (Preise, Upgrade-Kurven, Pakettypen, Zonen) zentral in `src/shared/Config`,
  damit Balancing ohne Code-Änderungen möglich ist.
- Jeder Spieler bekommt einen eigenen Plot (Lagerhalle) auf dem Server.

## Core-Loop (Manuell → Automatisierung)
1. Pakete spawnen auf dem Fließband, haben Eigenschaften (Farbe/Ziel-Label/Größe).
2. Spieler greift Pakete und legt sie in den passenden Ausgang → Geld.
   Falsch sortiert = kein Geld bzw. kleiner Malus.
3. Mit Geld kauft man: schnellere Bänder, mehr Spawner, größere Pakete (mehr Wert),
   und **Sortiermaschinen**, die bestimmte Pakettypen automatisch sortieren.
4. Später: Maschinen-Upgrades (Tempo, Kapazität, Genauigkeit), zusätzliche Bänder,
   bis die Halle weitgehend automatisch läuft (Offline-/Idle-Einnahmen mit Cap).

## Progression & Retention
- **Rebirth/Prestige**: Reset von Geld und Maschinen gegen permanenten Multiplikator.
- **Seltene Pakete**: golden, zerbrechlich (vorsichtig sortieren), mysteriös
  (Bonus-Belohnung). Werden durch Gameplay gefunden, NICHT gegen Robux gekauft.
- **Zonen**: freischaltbare Bereiche mit neuen Pakettypen und Mechaniken,
  z. B. Postamt → Flughafen-Cargo → Weltraum-Hub.
- **Quests, Daily Rewards, Leaderboards** (Geld, Rebirths, sortierte Pakete).

## Monetarisierung
- **Gamepasses**: 2x Cash, Auto-Collect, VIP-Bereich, schnellere Bänder, extra Plot-Platz.
- **Developer Products**: Cash-Pakete (skalieren mit Progress), zeitlich begrenzte
  Boosts, Sofort-Upgrades.
- ~~**Premium Payouts** mitnehmen (kleiner Premium-Bonus im Spiel)~~ – überholt, siehe
  Entscheidungen. **VIP Server** aktivieren.
- **Kosmetik**: Skins für Fließbänder, Pakete, Lagerhalle, Trails.
- `ProcessReceipt` idempotent implementieren (PurchaseId speichern, erst nach
  erfolgreichem Speichern `PurchaseGranted` zurückgeben).
- **Keine Paid Random Items** (Robux-Lootboxen). Falls später doch: Odds anzeigen
  und `PolicyService` beachten.

## Vorgehen (in Phasen, nach jeder Phase stoppen und berichten)
1. **Setup**: Rojo-Projekt, Wally, Linting, Ordnerstruktur, Git, Config-Module. ✅
2. **MVP**: ein Plot, ein Band, drei Pakettypen, manuelles Sortieren,
   Geld + Speichern. Map mit Platzhalter-Parts über Studio MCP. Code ✅, Studio-Teil offen
3. **Upgrades & erste Maschine**, Shop-UI. Code ✅, UI per Studio MCP offen
4. **Monetarisierung**: Gamepasses + Developer Products (mit Test-IDs in Config). Code ✅
5. **Rebirth, seltene Pakete, Quests, Daily Rewards, Leaderboards**. Code ✅, Studio-Teil offen
6. **Zweite Zone**, danach Balancing-Pass.

Stand 25.09.2026: Der Code für Phase 2–5 ist fertig und getestet. Was in Studio entstehen muss (Map,
Halle, Modelle, Vorlagen, gesamte UI), baut die lokale Session per Studio MCP nach
[`docs/PC_SESSION.md`](docs/PC_SESSION.md), [`docs/MAP_CONTRACT.md`](docs/MAP_CONTRACT.md) und
[`docs/UI_CONTRACT.md`](docs/UI_CONTRACT.md).

## Entscheidungen (Stand 25.09.2026, Details im homelab-Connector)
- **Map per Studio MCP**: Map, Lagerhalle und Plot-Template entstehen in Studio und liegen im
  Place `place/ParcelTycoon.rbxlx`. Rojo verwaltet nur Code-Container, nie Workspace/ServerStorage.
  Code findet Map-Teile nur über [`docs/MAP_CONTRACT.md`](docs/MAP_CONTRACT.md).
  Der Studio MCP läuft lokal per stdio: Map-Arbeit braucht eine lokale Session auf dem PC,
  Cloud-Sessions machen nur Code.
- **UI per Studio MCP**: HUD, Fenster, Buttons, Toasts und Welt-UI baut die lokale Session in Studio.
  Der Client erzeugt keine UI, er bindet sich nur an die Namen aus
  [`docs/UI_CONTRACT.md`](docs/UI_CONTRACT.md) (Quelle: `src/shared/UiContract.luau`).
- **Eigene Features erwünscht** (Nutzer, 25.09.2026), auch solche, die zum Kaufen anregen – fair für
  Free-Spieler, keine Paid Random Items, kein Druck und keine falschen Timer bei Kindern, per Config
  abschaltbar, bestehende Entscheidungen bleiben. Der Kern der früheren Kritik war die per Code gebaute
  Map, nicht eigene Features.
- **Feature-Paket 25.09.2026**: Tycoon-Bundle, Flitzeschuhe, Styles als Gamepässe, Starterpaket,
  Boosts, Auto Collect auf Zeit, Offline-Geld verdoppeln, Rewarded-Video-Werbung (3 Platzierungen mit
  Tageslimit), Paket-Club-Abo, Angebots-Popups im passenden Moment, Tutorial, Spielzeit-Geschenke,
  Codes, Gruppen- und Freunde-Bonus, Rebirth-Meilensteine (Details in `docs/BALANCING.md`).
- **Sortieren = Tragen**: Paket antippen → Avatar trägt es → Ausgang berühren. Server prüft
  Distanz zu Paket und Ausgang, Cooldown und Besitz (`Config.Gameplay`).
- **Offene Brief-Punkte geklärt**: Maschinen-„Kapazität“ = Kassen-Kapazität (Maschinengeld sammelt
  sich in der Kasse, volle Kasse pausiert die Maschinen). „Extra Plot-Platz“ = 4. Band, das mit
  Spielgeld gebaut wird. Band voll = die Rutsche pausiert, nichts geht verloren (Stau bei AFK ist
  gewollt, Offline-Einnahmen rechnet der Code separat).
- **Kein Premium-Bonus**: Premium Payouts wurden am 24.07.2025 durch Creator Rewards ersetzt
  (5 R$/Tag pro Active Spender, der das Spiel als eines der ersten 3 am Tag ≥ 10 Min spielt,
  plus 35 % Umsatzanteil für neue/reaktivierte Nutzer über den Share-Link). Daily Rewards und Quests
  auf Sessions ≥ 10 Min auslegen, Einladungen per Share-Link belohnen.
- **Seltene Pakete: feste Chancen**: Cash ist per Dev Product kaufbar und damit „paid currency“.
  Nichts, was man mit Robux oder Cash kauft, darf Chancen auf seltene Pakete ändern (sonst PRI).
  Boosts wirken nur auf Cash/Tempo.
- **Preise nie hart codieren**: Die UI liest Preise über `MarketplaceService:GetProductInfoAsync`
  (Regional Pricing / Price Optimization). Die Config enthält nur IDs (0 = noch nicht angelegt).
- **Balancing**: exponentielle Kosten, lineare Wirkung, Kauf-Simulation mit Stau-Modell als Test
  ([`docs/BALANCING.md`](docs/BALANCING.md)). Rebirth-Schwelle ×2 statt ×3 (Simulation).
- **Maschinen lassen seltene Pakete liegen**, damit aktives Spielen mehr bringt als AFK.
- **Toolchain**: Rokit statt Aftman.

## Konventionen
- Geteilte, reine Logik (Config, Economy) nutzt String-Requires (`require("./X")`, `@self/…`),
  damit Lune sie ohne Roblox testen kann. Server/Client dürfen Instanz-Requires nutzen.
- Config ist per `table.freeze` eingefroren; Laufzeitcode ändert sie nie.
- Services (`src/server/Services`) und Controller (`src/client/Controllers`) exportieren optional
  `init()` (synchron) und `start()` (eigener Thread).
- Farben in der Config als Hex-Strings, Größen als `{x, y, z}` (bleibt reine Daten).
- Doku für den Nutzer (`docs/*.md`) auf Deutsch; Spiel-UI Englisch mit Localization-Table (DE):
  alle Texte in `src/localization/GameText.csv` (Rojo → `LocalizationService.GameText`), feste
  UI-Texte per `TextKey`-Attribut, der Server schickt nur Schlüssel und IDs.
- Nach Änderungen an `src/shared/UiContract.luau`: `lune run tools/ui-contract-doc`.
- Codes liegen serverseitig in `src/server/Codes.luau` (ReplicatedStorage ist für Clients lesbar).
- Werbe-Buttons nennen immer Werbung und Belohnung (TextKeys `ads.*`); Werbung nur freiwillig, nie als
  Fortschritts-Sperre (Roblox-Richtlinie).
- Aus den Schwesterprojekten übernommen:
  - Studio MCP braucht in Studio „Assistant → … → Manage MCP Servers → Enable Studio as MCP server“.
    `list_roblox_studios` kann direkt nach dem Verbinden kurz leer sein.
  - Für Serverzustand im Playtest einen Debug-Hook in ServerStorage nutzen; `require` in
    `execute_luau` liefert eine frische Modulinstanz ohne laufenden Zustand.
  - `generate_mesh` nie ohne ausdrückliches OK und nie als Batch (Moderation des Hint-Images).
  - Keine eigenen UI-Knöpfe oben links (Chat) oder oben rechts (Spielerliste); kein 🪙-Emoji
    (wird nicht gerendert, 💰 nutzen); wichtige Aktionen mobile-first unten rechts.
  - Keine gedrehten Frames als Deko in Buttons (ClipsDescendants schneidet sie nicht ab).

## Umgebung
- Cloud-Session: `api.wally.run` ist per Netzwerk-Policy gesperrt (kein `wally install`), und Selene
  kann seine Roblox-Std hinter dem Proxy nicht laden. Beides läuft in GitHub Actions und lokal.
- Launch für Kinder (Roblox Select, 9–15): Owner braucht ID-Check + 2FA + Premium seit 2 Monaten
  oder 1.000 R$ rückzahlbare Gebühr; neue Spiele laufen zuerst nur für 16+, bis 250 Unique Plays
  in 60 Tagen erreicht sind (aus anime-roblox-game, Stand 05/2026).
