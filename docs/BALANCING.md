# Balancing

Stand: Phase 1 (25.09.2026). Alle Werte stehen in `src/shared/Config/`, die Formeln in
`src/shared/Economy.luau`. Balancing geht ohne Code-Änderung: Config anpassen, dann
`lune run tests` (prüft die Ziele) bzw. `lune run tests/report` (zeigt den Verlauf).

## Prinzip

Klassisches Idle-Modell: Kosten wachsen exponentiell, Wirkung pro Stufe nur linear. Dadurch
werden Käufe im Lauf einer Runde langsam seltener, bis sich ein Rebirth lohnt.

- **Wiederholbare Upgrades** (`Config/Upgrades.luau`):
  Preis der nächsten Stufe = `baseCost × growth ^ aktuelleStufe`, Wirkung = `1 + effectPerLevel × Stufe`.
- **Einmalkäufe** (`Config/Purchases.luau`): Sortiermaschinen, zusätzliche Spawner-Schächte und
  Bänder. Jeder Kauf wird erst nach seinem Vorgänger (`requires`) sichtbar, wie Tycoon-Buttons.
  Preis ≈ 3–8 Minuten Einkommen zu dem Zeitpunkt, an dem er dran ist.
- **Einkommen** (`Economy.incomePerMinute`): Pro Band kommen
  `spawnsPerMinute × Spawner × Bandtempo` Pakete an, aufgeteilt nach `spawnWeight`. Eine Maschine
  sortiert ihren Pakettyp bis `sorterBaseRate × Maschinentempo` pro Minute. Der Rest bleibt für
  den Spieler, der die wertvollsten Pakete zuerst nimmt.

| Upgrade | Basis | Wachstum | Wirkung/Stufe | Max |
|---|---|---|---|---|
| Bandtempo | 12 | 1,15 | +10 % Pakete/min | 25 |
| Größere Pakete | 18 | 1,16 | +15 % Wert | 60 |
| Maschinentempo | 250 | 1,18 | +20 % Durchsatz | 30 |
| Nachtschicht (Offline-Cap) | 5.000 | 6 | +2 h | 3 |

| Paket (Zone 1) | Wert | Anteil |
|---|---|---|
| Letter → Town | $3 | 50 % |
| Box → Country | $6 | 35 % |
| Crate → World | $12 | 15 % |

Handsortieren: Annahme ~12 Pakete/min (≈ 5 s pro Paket inkl. Laufen). Das nutzt nur die Simulation.

## Rebirth, Offline, Kasse

- **Rebirth**: erste Schwelle $150k, danach **×2** pro Rebirth; Bonus +50 % additiv (×1,5, ×2, ×2,5 …).
  Im Vorschlag stand ×3. Die Simulation zeigte damit Runde 2/3 bei 77/94 min statt 45–75 min,
  mit ×2 liegen die Runden 1–3 bei 66/59/62 min. Ab Runde 5 werden die Runden in Zone 1 allein
  wieder länger (78, 96 min), weil der Inhalt ausgeht. Das fängt Zone 2 in Phase 6 auf.
- **Offline**: 30 % der Maschinenrate, Deckel 2 h (Upgrade bis 8 h). Handsortieren zählt nicht.
- **Kasse**: Maschinen zahlen in die Kasse am Plot, sie hört bei 15 Minuten Maschineneinkommen auf
  zu füllen. Der Auto-Collect-Pass bucht direkt aufs Konto.

## Seltene Pakete (Phase 5)

Golden (1/150, ×10), Zerbrechlich (1/80, ×4), Mysteriös (1/300, Zufallsbelohnung). Maschinen
lassen sie liegen, nur Spieler sortieren sie. Das macht aktives Spielen um ~10 % lohnender als AFK.
Die Chancen sind feste Config-Werte: Nichts, was man mit Robux oder (kaufbarem) Cash kauft, darf sie
verändern, sonst wären es bezahlte Zufallsitems mit Chancen-Anzeige und PolicyService-Pflicht.
Die Simulation rechnet ohne seltene Pakete (konservativ).

## Monetarisierung und Kurve

- Cash-Pakete geben „X Minuten des aktuellen Einkommens“ (15/60/240 min, mit Mindestbetrag),
  skalieren also mit dem Fortschritt und brechen die Kurve nicht.
- 2x Cash halbiert grob die Zeiten, nichts ist ohne Pass gesperrt.
- Preise stehen nie in der Config (nur IDs): Die UI liest sie über `MarketplaceService:GetProductInfo`,
  sonst funktionieren Roblox' Regional Pricing und Price Optimization nicht.

## Simulation

`tests/BalanceSim.luau` spielt einen kaufoptimierten Free-Spieler (ohne Pässe, ohne seltene
Pakete): Er kauft immer die bezahlbare Option mit dem besten Einkommensgewinn pro Cash, wartet
sonst darauf und spart für den Rebirth, sobald der höchstens 15 Minuten Einkommen entfernt ist oder
der nächste sinnvolle Kauf mehr als 8 Minuten.

Ergebnis mit den aktuellen Werten (`lune run tests/report`):

| | Runde 1 | Runde 2 | Runde 3 |
|---|---|---|---|
| Erster Kauf | 16 s | 11 s | 8 s |
| Erste Sortiermaschine | 3,7 min | 2,5 min | 1,9 min |
| Band 1 voll automatisiert | 22,8 min | 15,2 min | 11,4 min |
| Zweites Band | 42,7 min | 28,5 min | 21,4 min |
| Band 2 voll automatisiert | 48,8 min | 32,6 min | 24,4 min |
| Rebirth | 66,0 min | 59,2 min | 62,1 min |
| Käufe in den ersten 5 min | 19 | 27 | 29 |
| Einnahmen nach 15 min | $1.358/min | $3.236/min | $7.476/min |
| Einnahmen nach 45 min | $6.054/min | $18.735/min | $31.268/min |

`tests/balance.spec.luau` sichert diese Ziele mit Toleranz ab (erster Kauf ≤ 30 s, erste Maschine
2–6 min, ≥ 12 Käufe in 5 min, längste Wartezeit in den ersten 15 min ≤ 3 min, Band 1 automatisiert
nach 15–30 min, Band 2 nach 35–55 min, Rebirth-Runden 1–3 je 45–75 min). Wer ein Ziel bewusst
ändert, passt Test und dieses Dokument zusammen an.
