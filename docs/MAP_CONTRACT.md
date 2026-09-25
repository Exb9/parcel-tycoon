# Map-Vertrag (Studio MCP ↔ Code)

Map, Lagerhalle, Bänder, Maschinenmodelle, Platzhalter-Parts, die Paket-Vorlage und die Welt-UI baut die
lokale Session per **Studio MCP** in Studio. Gespeichert wird alles im Place `place/ParcelTycoon.rbxlx`
(XML, damit Git Diffs zeigt). Rojo verwaltet nur Code und Texte (`ReplicatedStorage.Shared`,
`ServerScriptService.Server`, `StarterPlayerScripts.Client`, `LocalizationService.GameText`,
Wally-Pakete) und fasst Workspace, ServerStorage, StarterGui und Lighting nie an.

Der Code findet Map-Teile nur über die Namen, Attribute und Attachments unten.
`src/shared/MapContract.luau` prüft den Vertrag beim Serverstart und meldet Abweichungen im Output
(`[Map] …`). Die Bildschirm-UI steht in [`UI_CONTRACT.md`](UI_CONTRACT.md).

Allgemein:

- **Keine Scripts in der Map.** Logik liegt ausschließlich in `src/`.
- Alle Teile `Anchored = true`. Aussehen, Materialien und Deko sind frei, solange Namen, Attribute und
  Attachments stimmen. Zusätzliche Teile (Wände, Deko, Lampen) sind jederzeit erlaubt.
- Attribute sind **Zahlen** (Number), außer `SkinSlot` und `TextKey` (String).
- Farben von Ausgängen und Paketen setzt der Code aus der Config (Pakettyp-Farbe), ebenso alle
  dynamischen Texte. Feste Welt-Texte bekommen ein `TextKey`-Attribut (Schlüssel aus
  `src/localization/GameText.csv`).

## Welt (Workspace)

```
Workspace
├─ Lobby (Model oder Folder)
│  ├─ SpawnLocation            Startpunkt; danach teleportiert der Code jeden Spieler in seine Halle
│  ├─ Leaderboards (Folder)
│  │  ├─ TopEarned (Part)      Tafel „Top-Verdiener“
│  │  ├─ TopRebirths (Part)    Tafel „Meiste Rebirths“
│  │  └─ TopSorted (Part)      Tafel „Meiste Pakete sortiert“
│  └─ Vip (Model oder Folder)  VIP-Bereich (Gamepass „VIP“)
│     └─ Door (Part)           CanCollide = true; VIP-Spieler laufen durch, andere bekommen einen Hinweis
└─ PlotSlots (Folder)
   └─ Slot1 … Slot6 (Part)     Attribut SlotIndex = 1 … 6
```

- **Leaderboard-Tafel**: Part mit SurfaceGui `Board` (Face zur Lobby), darin ein TextLabel `Title` mit
  TextKey `board.TopEarned` / `board.TopRebirths` / `board.TopSorted` und ein Frame `Rows` mit
  UIListLayout (`SortOrder = LayoutOrder`). In `Rows` liegt ein Frame `RowTemplate` mit den TextLabels
  `Rank`, `PlayerName` und `Value`. Der Server klont `RowTemplate` für die Top 10 und füllt die Texte.
- **VIP-Bereich**: ein abgeschlossener Raum in der Lobby, einziger Zugang ist `Door`. Was drin steht, ist
  Deko (keine eigenen Mechaniken).
- **PlotSlots**: unsichtbare Teile (`Transparency = 1`, `CanCollide = false`, `CanQuery = false`). Die
  CFrame eines Slots ist die Lage der Halle: Der Code setzt die Vorlage mit `PivotTo` so, dass `Floor`
  genau auf dem Slot liegt. Die Eingangsseite der Vorlage (−Z) soll zur Lobby zeigen. Slots mindestens
  120 Studs auseinander, damit sich die Hallen (96 × 100) nicht überschneiden.
- **Nicht anlegen**: `Workspace.Plots` und `Workspace.CarriedPackages` erzeugt der Code selbst.

## Hallen-Vorlage (ServerStorage.PlotTemplate)

```
PlotTemplate (Model, PrimaryPart = Floor)
├─ Floor (Part)                 Boden der Halle; Pivot der ganzen Vorlage
├─ OwnerSpawn (Part)            hierhin wird der Besitzer beim Spawnen teleportiert (4 Studs darüber)
├─ OwnerSign (Part)             SurfaceGui OwnerGui › TextLabel OwnerName (Name des Besitzers)
├─ Collector (Part)             die Kasse; Drüberlaufen sammelt das Maschinengeld ein
│  └─ CollectorGui (BillboardGui)
│     ├─ Title (TextLabel)      TextKey „world.collector“
│     └─ Amount (TextLabel)     Text leer lassen; der Code zeigt dem Besitzer „$120 / $1.5K“
├─ Exits (Folder)
│  └─ Exit1 … Exit3 (Part)      Attribut TypeIndex = 1 … 3; Drüberlaufen mit passendem Paket = sortiert
│     ├─ ExitGui (BillboardGui) › Destination (TextLabel)   Ziel, z. B. „TOWN“ (setzt der Code)
│     └─ Guide (Highlight)      optional, Enabled = false; leuchtet beim Tragen am richtigen Ausgang
└─ Belts (Folder)
   └─ Belt1 … Belt4 (Model)     Attribut BeltIndex = 1 … 4
      ├─ Conveyor (Part)        Band; Attachments „Start“ und „End“ auf der Oberseite
      ├─ Spawners (Folder)      Spawner1 … Spawner3: Einwurf-Rutschen am Bandanfang
      └─ Sorters (Folder)       Sorter1 … Sorter3: Sortiermaschinen, Attribut TypeIndex = 1 … 3
```

- **Sichtbarkeit**: Die Vorlage enthält alles (4 Bänder, je 3 Rutschen und 3 Maschinen). Der Code zeigt
  nur, was der Spieler gekauft hat: Band 1 und Rutsche 1 von Anfang an, der Rest nach dem Kauf (Band 4
  nur mit dem Pass „Bigger Warehouse“).
- **Rutschen und Maschinen** dürfen ein Part oder ein Model mit PrimaryPart sein. Bei Maschinen zählt die
  Position des Parts/PrimaryParts entlang des Bands.
- **Band**: Pakete laufen von `Start` nach `End` und stauen sich am Ende; dort holt der Spieler sie ab.
  `Start` → `End` mindestens 30 Studs. Die Maschinen müssen zwischen 2 Studs nach `Start` und 12 Studs vor
  `End` stehen, sonst meldet der Server einen Fehler. Eine Maschine nimmt passende Pakete, die bis zu
  4 Studs vor oder hinter ihr liegen.
- **Ausgänge**: gezählt wird die waagerechte Entfernung zur Mitte des Ausgangs (≤ 4,5 Studs, Höhe
  ± 8). Ein Pad von etwa 8 × 8 Studs passt. Die Farbe setzt der Code (Pakettyp-Farbe), also neutral
  bauen oder Deko-Teile drumherum.
- **Kasse**: gezählt wird die waagerechte Entfernung zur Mitte (≤ 5 Studs, Höhe ± 8).
- **Skins** (Kosmetik): Teile mit dem String-Attribut `SkinSlot = "belt"` (Bandoberflächen) bzw.
  `SkinSlot = "warehouse"` (Wände, Boden) bekommen Farbe und Material eines gekauften Skins; ohne Skin
  gilt wieder das Aussehen aus Studio.

### Referenz-Layout

Das Balancing (Pakete pro Minute, Laufwege, Maschinen-Reichweite) ist auf diese Maße abgestimmt
(`tests/BeltSim.luau`). Deko und Form sind frei, die Maße bitte ungefähr einhalten.
Koordinaten relativ zur Oberseiten-Mitte von `Floor`, Eingang bei −Z (zur Lobby):

| Teil | Lage und Größe |
|---|---|
| `Floor` | 96 × 1 × 100 Studs (X × Y × Z) |
| `Conveyor` Band 1–4 | 4 Studs breit, `Start` bei z = +40, `End` bei z = −8 (48 Studs); x = −18, −6, +6, +18 |
| `Sorter1` / `Sorter2` / `Sorter3` | 12 / 20 / 28 Studs nach `Start` (z = +28 / +20 / +12), neben oder über dem Band |
| `Spawner1` – `3` | am Bandanfang (z ≈ +40 bis +46) |
| `Exit1` – `3` | Pads 8 × 8 bei z = −22, x = −20 / 0 / +20 |
| `Collector` | Pad 6 × 6 bei x = +40, z = −30 |
| `OwnerSpawn` | x = 0, z = −40 |
| `OwnerSign` | an der Eingangsseite (z ≈ −50), Text nach außen |

## Paket-Vorlage (ServerStorage.PackageTemplate)

```
PackageTemplate (Part)
├─ Label (SurfaceGui, Face = Top)
│  ├─ Destination (TextLabel)    Ziel („TOWN“), setzt der Code
│  └─ Tag (TextLabel)            optional: „GOLDEN“ / „FRAGILE“ / „?“ bei seltenen Paketen
├─ golden                        optional: Look für goldene Pakete (z. B. ParticleEmitter, Glanz)
├─ fragile                       optional: Look für zerbrechliche Pakete (z. B. Aufkleber-Decal)
└─ mystery                       optional: Look für Überraschungspakete (z. B. „?“-Billboard)
```

- Größe und Farbe setzt der Code pro Pakettyp (Brief, Karton, Kiste), ebenso `Anchored`, `CanCollide`
  und `CanQuery`. Die Label-Texte also nicht zu klein wählen (`SizingMode = PixelsPerStud` oder Scale).
- Die Kinder `golden`, `fragile` und `mystery` (beliebiger Instanz-Typ, z. B. Folder mit Effekten) behält
  der Code nur beim passenden seltenen Paket. Seltene Pakete behalten ihre Typ-Farbe (sie zeigt das Ziel).
- Fehlt die Vorlage, nimmt der Code schlichte Parts (dann ohne Beschriftung).

## Kosmetik-Vorlagen (ServerStorage.CosmeticTemplates)

```
CosmeticTemplates (Folder)
└─ trailRainbow (Trail)          Regenbogen-Spur; Farben, Lifetime, Breite frei gestalten
```

Der Code klont die Trail-Vorlage an den Charakter des Spielers und setzt die beiden Attachments.
Band-, Paket- und Hallen-Skins brauchen keine Vorlage (Farbe/Material aus `Config.Cosmetics`).

## Place-Einstellungen

- **Max. Spieler = 6** (= `Config.Gameplay.maxPlots`), nach dem Veröffentlichen unter
  Game Settings → Places.
- `Workspace.StreamingEnabled = false` empfohlen (kleine Map; der Code kommt aber auch mit Streaming
  zurecht).
- Collision Groups für die VIP-Tür legt der Code an (`VipDoor`, `VipPlayers`).
- Place speichern als `place/ParcelTycoon.rbxlx`. Beim Speichern landen auch die per Rojo gesyncten
  Scripts in der Datei; maßgeblich bleibt immer `src/`.
