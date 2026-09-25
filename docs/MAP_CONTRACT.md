# Map-Vertrag (Studio MCP ↔ Code)

Map, Lagerhalle und Plot-Template werden in Studio über den Studio MCP gebaut und im Place
`place/ParcelTycoon.rbxlx` gespeichert. Rojo verwaltet nur Code (`ReplicatedStorage.Shared`,
`ServerScriptService.Server`, `StarterPlayerScripts.Client`, Wally-Pakete) und fasst Workspace,
ServerStorage und Lighting nie an.

Damit der Code die gebauten Teile findet, gilt dieser Vertrag. Namen sind exakt (Groß/klein),
Attribute sind Roblox-Attribute auf der Instanz. Farben und Beschriftungen von Paketen und
Ausgängen kommen zur Laufzeit aus `Config.PackageTypes`, damit es nur eine Quelle gibt.

## Plots

```
Workspace
└─ PlotSlots (Folder)
   ├─ Slot1 … Slot6 (Part, Anchored, CanCollide=false, Transparency=1)
   │    Attribut SlotIndex: number (1–6)
   │    Die CFrame des Parts ist der Pivot, an den das Template geklont wird.

ServerStorage
└─ PlotTemplate (Model, PrimaryPart = Floor)
   ├─ Floor (Part)                 Boden der Lagerhalle
   ├─ OwnerSpawn (Part)            hierhin wird der Besitzer beim Beitritt teleportiert
   ├─ OwnerSign (Part)             bekommt per Code eine SurfaceGui mit dem Spielernamen
   ├─ Collector (Part)             Kasse; Berühren = einsammeln
   ├─ Exits (Folder)
   │  ├─ Exit_letter (Part)        Attribut PackageType = "letter"
   │  ├─ Exit_box (Part)           Attribut PackageType = "box"
   │  └─ Exit_crate (Part)         Attribut PackageType = "crate"
   └─ Belts (Folder)
      ├─ Belt1 (Model)             Attribut BeltIndex = 1 (Band 2 und 3 analog, anfangs ausgeblendet)
      │  ├─ Conveyor (Part)        Bandoberfläche; Pakete laufen von Start nach End
      │  ├─ Start (Attachment in Conveyor)   Spawnpunkt der Pakete
      │  ├─ End (Attachment in Conveyor)     Bandende (Pakete laufen dort auf einen Puffer)
      │  ├─ SpawnerSlots (Folder)  SpawnerSlot1–3 (Part), Positionen der Einwurf-Schächte
      │  └─ SorterSlots (Folder)   Sorter_letter / Sorter_box / Sorter_crate (Part),
      │                            Platzhalter, an denen gekaufte Maschinen erscheinen
      ├─ Belt2 (Model)             BeltIndex = 2
      └─ Belt3 (Model)             BeltIndex = 3
```

Regeln:

- Das Template baut ein Plot vollständig (alle 3 Bänder, alle Slots). Der Code blendet ein, was
  der Spieler besitzt, und klont das Template beim Beitritt bzw. nach einem Rebirth neu.
- Alle Teile im Template sind `Anchored = true`. Pakete erzeugt der Code (Platzhalter-Parts in
  Größe und Farbe aus der Config). Hübschere Modelle kommen später optional nach
  `ReplicatedStorage.Assets.Packages.<typeId>`.
- Die 6 Slots liegen weit genug auseinander, dass sich Plots nicht überschneiden
  (Template-Grundfläche + mindestens 20 Studs Abstand).
- Keine Scripts in der Map. Logik liegt ausschließlich in Rojo-Dateien.

## Lobby / Welt

`Workspace.Lobby` (Model) mit `SpawnLocation` für neue Spieler. Deko ist frei, der Code greift
nicht darauf zu.

## Place-Einstellungen

- Max. Spieler = `Config.Gameplay.maxPlots` (6).
- Place-Datei: `place/ParcelTycoon.rbxlx` (XML, damit Git Diffs zeigt). Beim Speichern landen
  auch die per Rojo gesyncten Scripts in der Datei; maßgeblich bleibt immer `src/`.
