# Map-Vertrag (Studio ↔ Code)

Die Map liegt im Place `place/ParcelTycoon.rbxlx`. Rojo verwaltet nur Code (`ReplicatedStorage.Shared`,
`ServerScriptService.Server`, `StarterPlayerScripts.Client`, Wally-Pakete) und fasst Workspace,
ServerStorage und Lighting nie an.

- **Platzhalter-Map**: `tools/map/MapBuilder.luau` baut sie. Das Skript läuft in Lune
  (`lune run tools/map/generate-place` erzeugt die Place-Datei) und direkt in Studio (ganzen Dateiinhalt
  in der Befehlsleiste oder per Studio MCP im Edit-Modus ausführen).
- **Verschönern**: danach in Studio, z. B. per Studio MCP. Teile dürfen ersetzt, umgebaut und dekoriert
  werden, solange die Namen, Attribute und Attachments unten erhalten bleiben.
- **Prüfung**: `src/shared/MapContract.luau` prüft den Vertrag. Der Server meldet Verstöße beim Start im
  Output („[Map] …“), die Tests prüfen die generierte Map.

Farben und Beschriftungen von Paketen, Ausgängen, Böden und Wänden kommen zur Laufzeit aus der Config
(Pakettyp-Farben, Zonen-Themes, Kosmetik), damit es nur eine Quelle gibt.

## Welt

```
Workspace
├─ Lobby (Model)
│  ├─ SpawnLocation            Startpunkt neuer Spieler (danach Teleport in die eigene Halle)
│  ├─ Leaderboards (Folder)
│  │  ├─ TopEarned (Part)      Tafel; der Server legt eine SurfaceGui auf die Front-Seite
│  │  ├─ TopRebirths (Part)
│  │  └─ TopSorted (Part)
│  └─ Vip (Model)
│     ├─ Door (Part)           nur VIP-Spieler laufen durch (Collision Group)
│     └─ GiftPad (Part)        täglicher VIP-Boost beim Drüberlaufen
└─ PlotSlots (Folder)
   └─ Slot1 … Slot6 (Part)     Attribut SlotIndex; unsichtbar. Die CFrame ist der Pivot der Halle,
                               -Z der Vorlage (Eingang) zeigt Richtung Lobby.
```

## Hallen-Vorlage

```
ServerStorage
└─ PlotTemplate (Model, PrimaryPart = Floor)
   ├─ Floor (Part)             ThemeRole = "floor"
   ├─ Walls (Folder)           Teile mit ThemeRole = "wall" / "trim"
   ├─ OwnerSpawn (Part)        hierhin wird der Besitzer beim Spawnen teleportiert
   ├─ OwnerSign (Part)         Front-Seite zeigt nach außen; Server schreibt den Namen darauf
   ├─ Collector (Part)         Kasse; Drüberlaufen = einsammeln
   ├─ Exits (Folder)
   │  └─ Exit1 … Exit3 (Part)  Attribut TypeIndex = 1…3; Drüberlaufen mit Paket = einsortieren
   └─ Belts (Folder)
      └─ Belt1 … Belt4 (Model) Attribut BeltIndex = 1…4 (Band 2–4 erst nach dem Kauf sichtbar)
         ├─ Conveyor (Part)    ThemeRole = "belt"; Attachments "Start" und "End" auf der Oberseite,
         │                     Pakete laufen von Start nach End
         ├─ Bin (Part)         Recycling-Behälter am Anfang der Warteschlange (Ziel der Animation)
         ├─ Spawners (Folder)  Spawner1 … Spawner3 (Part), Einwurf-Schächte (je nach Kauf sichtbar)
         └─ Sorters (Folder)   Sorter1 … Sorter3 (Part), Attribut TypeIndex (sichtbar nach Kauf)
```

Regeln:

- **Band**: `Start` → `End` muss mindestens 26 Studs lang sein (Warteschlange 14 + Platz für Maschinen).
  Die Platzhalter-Bänder sind 48 Studs lang.
- **Maschinen**: Sortierer müssen entlang des Bands vor der Warteschlange stehen (2 bis
  Länge − 14 − 4 Studs ab `Start`), damit jedes Paket an ihnen vorbeikommt. Platzhalter: 12/20/28.
- **Pakete**: Pakete erzeugt der Code (Platzhalter-Parts in Größe und Farbe aus der Config) und bewegt
  sie per Formel auf den Clients. Hübschere Modelle kommen später optional nach
  `ReplicatedStorage.Assets.Packages.<typeId>`.
- **Keine Scripts in der Map.** Logik liegt ausschließlich in Rojo-Dateien.
- **Abstände**: Die 6 Slots liegen so weit auseinander, dass sich die Hallen (96 × 100 Studs) nicht
  überschneiden.

## Place-Einstellungen

- Max. Spieler = `Config.Gameplay.maxPlots` (6), einstellbar nach dem Veröffentlichen unter
  Game Settings → Places.
- `Workspace.StreamingEnabled = false` (setzt der Builder).
- Place-Datei: `place/ParcelTycoon.rbxlx` (XML, damit Git Diffs zeigt). Beim Speichern landen auch die
  per Rojo gesyncten Scripts in der Datei; maßgeblich bleibt immer `src/`.
