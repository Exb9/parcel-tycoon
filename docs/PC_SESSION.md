# Lokale Session am PC (Studio MCP)

Der Code für Phase 2–5 ist fertig (Server, Client, Config, Balancing, Tests). Am PC entsteht per
**Studio MCP** alles, was nur in Studio geht: Map, Lagerhalle, Bänder, Maschinenmodelle, Paket- und
Trail-Vorlage und die komplette UI. Die Bauanleitungen dafür sind
[`MAP_CONTRACT.md`](MAP_CONTRACT.md) und [`UI_CONTRACT.md`](UI_CONTRACT.md). Zone 2 (Phase 6) kommt später.

## 1. Einrichten

1. Repo holen: `git pull` auf `main`, dann `rokit install` und `wally install`.
2. Studio: Assistant → … → Manage MCP Servers → **Enable Studio as MCP server**, dann den Studio MCP in
   Claude Code verbinden (`list_roblox_studios` kann direkt nach dem Verbinden kurz leer sein).
3. Neuen Place anlegen (Baseplate) und als **`place/ParcelTycoon.rbxlx`** speichern.
4. `rojo serve` starten und im Rojo-Plugin verbinden. Danach liegen Code und
   `LocalizationService.GameText` im Place.
5. Für echtes Speichern (ProfileStore, Leaderboards): Place veröffentlichen (privat reicht) und unter
   Game Settings → Security **Enable Studio Access to API Services** einschalten. Ohne das speichert
   ProfileStore nur zum Schein (Mock), das Spiel läuft trotzdem.

## 2. Map bauen ([`MAP_CONTRACT.md`](MAP_CONTRACT.md))

Reihenfolge, jeweils per Studio MCP im Edit-Modus:

1. `Workspace.Lobby` mit SpawnLocation, drei Leaderboard-Tafeln und dem VIP-Raum mit `Door`.
2. `Workspace.PlotSlots` mit `Slot1` … `Slot6` rund um die Lobby (Eingang zur Lobby).
3. `ServerStorage.PlotTemplate` nach dem Referenz-Layout (Band 48 Studs, Maschinen bei 12/20/28).
4. `ServerStorage.PackageTemplate` (Beschriftung oben, Looks für golden/fragile/mystery).
5. `ServerStorage.CosmeticTemplates` mit den Trails `trailRainbow`, `trailClub`, `trailStar`.
6. Place-Einstellungen (StreamingEnabled aus).

Prüfen: Play drücken. Im Output darf keine Zeile mit `[Map]` stehen, der Spieler landet in seiner
Halle, auf Band 1 kommen Pakete.

## 3. UI bauen ([`UI_CONTRACT.md`](UI_CONTRACT.md))

`StarterGui.HUD`, `StarterGui.Windows` (zehn Fenster: Shop, Store, Quests, Daily, Rebirth, Style, Info,
Offer, WelcomeBack, Codes) und `StarterGui.Toasts` mit genau den Namen aus der Elementliste, feste Texte
mit `TextKey`. Prüfen: Play drücken, keine Zeile mit `[UI]` im Output.

## 4. Durchspielen

Zustände ohne langes Spielen herstellen: Debug-Hook (nur in Studio), per Studio MCP `execute_luau` im
Play-Modus auf dem Server, z. B. `game.ServerStorage.ParcelDebug:Invoke("cash", 5000)`.
`Invoke("help")` listet alle Befehle, `Invoke("state")` zeigt den Serverzustand des Spielers.

- [ ] Paket antippen/anklicken → Avatar trägt es → richtiger Ausgang: Geld und Toast; falscher Ausgang:
      Hinweis, Paket bleibt in der Hand; Leitlicht am richtigen Ausgang (falls `Guide` gebaut).
- [ ] Stehen bleiben: Band staut sich, die Rutsche pausiert, nichts verschwindet.
- [ ] Shop: erste Maschine kaufen → sie erscheint und sortiert Briefe; Geld landet in der Kasse,
      drüberlaufen sammelt es ein; volle Kasse → Hinweis, Maschinen pausieren.
- [ ] Upgrades kaufen (Level, Preis, „MAX“), zweite Rutsche, Band 2 (`cash 25000`).
- [ ] Seltene Pakete: `rare golden`, `rare fragile` (springen zerbricht es), `rare mystery` (Bonus).
- [ ] Rebirth: `cash 150000`, Fenster Rebirth → alles zurück, Einkommen ×1,5.
- [ ] Daily und Quests: abholen; `daily` macht die Tagesbelohnung wieder abholbar, `quests done`
      erledigt die Quests.
- [ ] Store: in Studio zeigen Angebote „Test“ und werden direkt gewährt (Bundle, Pässe, Starterpaket,
      Cash, Boosts, Auto Collect auf Zeit, Instant Machine, Styles). Style-Fenster: Styles an/aus.
      Flitzeschuhe: schneller laufen.
- [ ] Tutorial für neue Spieler: `tutorial` startet es neu; Hinweise im HUD bis zum Geschenk am Ende.
- [ ] Angebots-Popup: nach der ersten Maschine das Starterpaket (oder `offer product starterPack`), bei
      voller Kasse Auto Collect; „Maybe later“ schließt.
- [ ] Werbung (in Studio simuliert): HUD-Button 2x Cash, Store-Button Auto Collect testen, im
      Willkommen-zurück-Fenster „verdoppeln“; `ad boost` gewährt die Belohnung direkt.
- [ ] Willkommen zurück: `offline 3600` öffnet das Fenster; Verdoppeln per Werbung oder Robux.
- [ ] Spielzeit-Geschenk im HUD: `gift` macht das nächste bereit.
- [ ] Codes: `WELCOME` und `PARCELS` einlösen, zweites Mal → „schon benutzt“.
- [ ] Club-Tab im Store: „Join“ (in Studio simuliert) → +20 % Bonus, Tagesgeschenk, Club-Spur;
      `club off` beendet es.
- [ ] Boni: `friends 2` → HUD zeigt „Bonus +20%“; `group` wirkt erst mit eingetragener Gruppen-ID.
- [ ] Rebirth-Meilensteine: nach dem ersten Rebirth Bonbon-Halle + Geld, Liste im Rebirth-Fenster.
- [ ] VIP: ohne Pass blockt die Tür mit Hinweis, `pass vip` → Tür lässt durch.
- [ ] Deutsch: Test → Player Emulator → Locale `de-de`.
- [ ] Zwei Spieler (Test → Clients and Servers): jeder bekommt eine eigene Halle.
- [ ] Handy-Ansicht im Device Emulator: Menü unten rechts erreichbar, Fenster passen auf den Schirm.

## 5. Speichern

Place speichern und committen (`place/ParcelTycoon.rbxlx`). Code-Änderungen immer in `src/`, nie im Place.

## 6. Vor dem Veröffentlichen

- Gamepässe und Developer Products im Creator Hub anlegen, Preise dort setzen und die IDs in
  `src/shared/Config/Monetization.luau` eintragen (0 = noch nicht angelegt). Das Tycoon-Bundle günstiger
  als 2x Cash + Auto Collect + Fast Belts zusammen bepreisen (echter Rabatt, Roblox-Regel), das
  Starterpaket klar günstiger als seine Einzelteile.
- **Roblox-Shop** (Creator Hub → Monetization → Shop): Pässe stehen dort automatisch; Developer Products
  auf „Show in Shop“ stellen, außer `instantMachine` (hängt vom Spielstand ab). Den globalen
  Shop-Button einschalten.
- **Rewarded-Video-Werbung** (Creator Hub → Monetization → Ads, braucht ID-Check, 2FA und im Schnitt
  2.000 Besucher pro Monat): Serving einschalten; die Belohnungen sind die Produkte `boostSmall`,
  `doubleOffline` und `autoCollectTrial`. Optional je Platzierung eine Placement-ID anlegen und in
  `Config.Monetization.ads` eintragen. „Exclude likely spenders“ passt, weil jede Belohnung auch für
  Robux zu haben ist.
- **Paket-Club** (Creator Hub → Monetization → Subscriptions): Abo anlegen (Typ Durable, Preis ab 49 R$
  oder Landeswährung), die ID („EXP-…“) in `Config.Monetization.club.id` eintragen.
- **Gruppe**: Roblox-Gruppe (Community) anlegen, ihre ID in `Config.Rewards.group.groupId` eintragen.
- **Codes** für Social Media in `src/server/Codes.luau` pflegen (serverseitig, damit sie nicht vorher
  durchsickern).
- VIP-Server (Private Servers) im Creator Hub aktivieren.
- Referral-Banner: Creator Hub → Engagement → Referral Rewards (Belohnungen: Einladender 30 min
  Einkommen, mind. $1.000, höchstens 5 pro Tag; Eingeladener $500).
- Max. Spieler = 6.
- Für die Zielgruppe 9–15 (Roblox Select) die Hinweise unter „Umgebung“ in `CLAUDE.md` beachten.
