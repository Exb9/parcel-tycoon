# Parcel Tycoon

Roblox-Simulator/Tycoon: Pakete vom Fließband in die richtigen Ausgänge sortieren, Geld verdienen
und Sortiermaschinen kaufen, bis die Lagerhalle von allein läuft. Projekt-Brief und Regeln stehen in
[`CLAUDE.md`](CLAUDE.md), das Balancing in [`docs/BALANCING.md`](docs/BALANCING.md), der Vertrag
zwischen Studio-Map und Code in [`docs/MAP_CONTRACT.md`](docs/MAP_CONTRACT.md).

## Einrichtung

1. [Rokit](https://github.com/rojo-rbx/rokit) installieren, dann im Repo:
   ```sh
   rokit install      # Rojo, Wally, Selene, StyLua, luau-lsp, Lune in den Versionen aus rokit.toml
   wally install      # ProfileStore u. a. nach ServerPackages/
   ```
2. VS Code: empfohlene Erweiterungen installieren (`.vscode/extensions.json`).
3. `place/ParcelTycoon.rbxlx` in Studio öffnen (entsteht in Phase 2 per Studio MCP),
   `rojo serve` starten und im Rojo-Plugin verbinden.

## Befehle

| Zweck | Befehl |
|---|---|
| Live-Sync nach Studio | `rojo serve` |
| Formatieren | `stylua src tests` |
| Linten | `selene src tests` |
| Typprüfung | `rojo sourcemap default.project.json -o sourcemap.json` und `luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --base-luaurc=.luaurc src` (Definitionsdatei siehe CI) |
| Tests + Balancing-Ziele | `lune run tests` |
| Balancing-Verlauf anzeigen | `lune run tests/report` |
| Place bauen (nur Code) | `rojo build default.project.json -o build/ParcelTycoon.rbxlx` |

CI (`.github/workflows/ci.yml`) führt alles davon bei jedem Push aus.

## Struktur

```
src/
  server/    init.server.luau lädt alle Module in Services/ (init, dann start)
  client/    init.client.luau lädt alle Module in Controllers/
  shared/    Config/ (Balancing, Inhalte, Monetarisierung), Economy.luau (reine Formeln)
tests/       Lune-Tests, Balancing-Simulation (BalanceSim.luau), report.luau
docs/        Balancing, Map-Vertrag
place/       Studio-Place mit der Map (ab Phase 2)
```
