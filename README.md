# Parcel Tycoon

Roblox-Simulator/Tycoon: Pakete vom Fließband in die richtigen Ausgänge sortieren, Geld verdienen
und Sortiermaschinen kaufen, bis die Lagerhalle von allein läuft. Projekt-Brief und Regeln stehen in
[`CLAUDE.md`](CLAUDE.md).

| Dokument | Inhalt |
|---|---|
| [`docs/PC_SESSION.md`](docs/PC_SESSION.md) | was die lokale Session per Studio MCP baut und testet |
| [`docs/MAP_CONTRACT.md`](docs/MAP_CONTRACT.md) | Bauanleitung Map, Halle, Paket- und Trail-Vorlage, Welt-UI |
| [`docs/UI_CONTRACT.md`](docs/UI_CONTRACT.md) | Bauanleitung HUD, Fenster, Toasts |
| [`docs/BALANCING.md`](docs/BALANCING.md) | Zahlen, Band-Modell, Simulation und Ziele |

## Einrichtung

1. [Rokit](https://github.com/rojo-rbx/rokit) installieren, dann im Repo:
   ```sh
   rokit install      # Rojo, Wally, Selene, StyLua, luau-lsp, Lune in den Versionen aus rokit.toml
   wally install      # ProfileStore nach ServerPackages/
   ```
2. VS Code: empfohlene Erweiterungen installieren (`.vscode/extensions.json`).
3. `place/ParcelTycoon.rbxlx` in Studio öffnen (entsteht per Studio MCP, siehe
   [`docs/PC_SESSION.md`](docs/PC_SESSION.md)), `rojo serve` starten und im Rojo-Plugin verbinden.

## Befehle

| Zweck | Befehl |
|---|---|
| Live-Sync nach Studio | `rojo serve` |
| Formatieren | `stylua src tests tools` |
| Linten | `selene src tests` |
| Typprüfung | `rojo sourcemap default.project.json -o sourcemap.json` und `luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --base-luaurc=.luaurc --ignore "**/ServerPackages/**" src` (Definitionsdatei siehe CI) |
| Tests, Balancing-Ziele, Verträge | `lune run tests` |
| Balancing-Verlauf anzeigen | `lune run tests/report` |
| Elementliste in `docs/UI_CONTRACT.md` erneuern | `lune run tools/ui-contract-doc` |
| Place bauen (nur Code) | `mkdir -p build` und `rojo build default.project.json -o build/ParcelTycoon.rbxlx` |

CI (`.github/workflows/ci.yml`) führt alles davon bei jedem Push aus.

## Struktur

```
src/
  server/          init.server.luau lädt alle Module in Services/ (init, dann start)
    Services/      Data, State, Plot, Cosmetic, Economy, Belt, Monetization, Quest, Reward,
                   Leaderboard, Debug (nur Studio)
    Lib/           Sessions, Events, RateLimit, Types
  client/          init.client.luau lädt alle Module in Controllers/
    Controllers/   HUD, Fenster, Toasts, Paket-Animation, Greifen, Welt-Beschriftungen
    Lib/           State, Text (Übersetzung), Ui (Bindung an die Studio-UI), Names, Sound
  shared/          Config/ (Balancing, Inhalte, Monetarisierung), reine Logik (Economy, BeltQueue,
                   Quests, Rewards, DataSchema), Map- und UI-Vertrag, Net
  localization/    GameText.csv (Englisch + Deutsch) → LocalizationService.GameText
tests/             Lune-Tests, Balancing- und Band-Simulation, report.luau
tools/             ui-contract-doc (Elementliste der UI-Doku)
docs/              Bauanleitungen, Balancing
place/             Studio-Place mit Map und UI (entsteht per Studio MCP)
```
