# Balancing

Stand: 25.09.2026. Alle Werte stehen in `src/shared/Config/`, die Formeln in
`src/shared/Economy.luau`. Balancing geht ohne Code-Änderung: Config anpassen, dann
`lune run tests` (prüft die Ziele) bzw. `lune run tests/report` (zeigt den Verlauf).

## Prinzip

Klassisches Idle-Modell: Kosten wachsen exponentiell, Wirkung pro Stufe nur linear. Dadurch
werden Käufe im Lauf einer Runde langsam seltener, bis sich ein Rebirth lohnt.

- **Wiederholbare Upgrades** (`Config/Upgrades.luau`):
  Preis der nächsten Stufe = `baseCost × growth ^ aktuelleStufe`, Wirkung = `1 + effectPerLevel × Stufe`.
- **Einmalkäufe** (`Config/Purchases.luau`): Sortiermaschinen, zusätzliche Rutschen und Bänder. Jeder
  Kauf wird erst nach seinem Vorgänger (`requires`) sichtbar, wie Tycoon-Buttons. Preis ≈ 3–8 Minuten
  Einkommen zu dem Zeitpunkt, an dem er dran ist.

| Upgrade | Basis | Wachstum | Wirkung/Stufe | Max |
|---|---|---|---|---|
| Bandtempo | 12 | 1,15 | +10 % Pakete/min | 25 |
| Größere Pakete | 18 | 1,16 | +15 % Wert | 60 |
| Maschinentempo | 250 | 1,18 | +20 % Durchsatz | 30 |
| Maschinen-Genauigkeit | 400 | 2,2 | +3 % (Basis 85 %, max 100 %) | 5 |
| Größere Kasse | 1.000 | 3 | +10 min Maschinengeld | 5 |
| Nachtschicht (Offline-Deckel) | 5.000 | 6 | +2 h | 3 |

| Kauf | Preis | Voraussetzung |
|---|---|---|
| Brief-Sortierer Band 1 | 200 | – |
| Zweite Rutsche | 450 | – |
| Karton-Sortierer Band 1 | 900 | Brief-Sortierer |
| Kisten-Sortierer Band 1 | 2.500 | Karton-Sortierer |
| Dritte Rutsche | 9.000 | Zweite Rutsche |
| Band 2 | 17.000 | Band 1 voll automatisiert |
| Sortierer Band 2 | 3.000 / 4.000 / 6.000 | Band 2 |
| Band 3 | 60.000 | Band 2 voll automatisiert |
| Sortierer Band 3 | 15.000 / 20.000 / 30.000 | Band 3 |
| Band 4 (Pass „Bigger Warehouse“) | 40.000 | Band 2 voll automatisiert |
| Sortierer Band 4 | 10.000 / 14.000 / 20.000 | Band 4 |

| Paket (Zone 1) | Wert | Anteil |
|---|---|---|
| Letter → Town | $3 | 50 % |
| Box → Country | $6 | 35 % |
| Crate → World | $12 | 15 % |

## Band-Modell: Rutsche pausiert (Entscheidung vom 25.09.2026)

Pakete laufen über das Band und stauen sich am Ende. Ist das Band bis zum Anfang voll, **pausiert die
Rutsche**, es geht nichts verloren (`src/shared/BeltQueue.luau`). Ein Band nimmt also nur so viele Pakete
auf, wie Maschinen und Spieler abräumen:

- Pro Band kommen höchstens `spawnsPerMinute (14) × Rutschen × Bandtempo` Pakete pro Minute.
- Eine Maschine nimmt ihren Pakettyp, wenn er bis zu 4 Studs vor oder hinter ihr vorbeikommt oder
  wartet, mit `sorterBaseRate (9) × Maschinentempo` pro Minute. Seltene Pakete lässt sie liegen.
- Alles andere (fremde Typen, Überlauf der Maschinen, seltene Pakete) muss der Spieler von Hand
  sortieren. Steht er herum, staut sich das Band und auch die Maschinen stehen still. Das ist bewusst so
  (aktives Spielen lohnt sich), Offline-Einnahmen rechnet der Code separat.
- `Economy.incomePerMinute` bildet das ab: Pro Band ergibt sich eine stückweise lineare Kurve „wie viel
  Handarbeit braucht welche Aufnahme“. Die Handrate (Annahme 12 Pakete/min ≈ 5 s pro Paket inkl.
  Laufen) geht immer dorthin, wo sie am meisten bringt.
- `tests/BeltSim.luau` spielt die Bänder Paket für Paket mit der echten Geometrie nach (48-Stud-Band,
  Maschinen bei 12/20/28 Studs, Spieler holt in den letzten 14 Studs ab). Das Modell trifft die Simulation
  auf 0,9–1,03 (`tests/belt.spec.luau`). Deshalb bitte das Referenz-Layout aus
  [`MAP_CONTRACT.md`](MAP_CONTRACT.md) ungefähr einhalten.

## Kasse, Genauigkeit, Offline, Rebirth

- **Kasse**: Maschinen zahlen in die Kasse am Plot. Sie fasst 15 Minuten Maschineneinkommen (mindestens
  $100, Upgrade +10 min je Stufe). Ist sie voll, pausieren die Maschinen, bis der Spieler drüberläuft.
  Der Pass „Auto Collect“ bucht Maschinengeld direkt aufs Konto.
- **Genauigkeit**: Maschinen sortieren 85 % richtig (Upgrade bis 100 %), Fehlsortierungen bringen nichts.
- **Offline**: 30 % der Maschinenrate bei normalem Spiel, Deckel 2 h (Nachtschicht bis 8 h). Handarbeit
  und Boosts zählen nicht.
- **Rebirth**: erste Schwelle $150k, danach **×2** pro Rebirth; Bonus +50 % additiv (×1,5, ×2, ×2,5 …).
  Setzt Geld, Upgrades und Käufe zurück, Pässe und Styles bleiben.

## Seltene Pakete

Golden (1/200, ×10), Zerbrechlich (1/120, ×4, zerbricht bei Sprüngen oder Stürzen), Mysteriös (1/400,
normaler Wert plus Überraschungs-Bonus: 60 % etwas Geld, 25 % viel Geld, 11 % 3 min 2x-Boost, 4 % Jackpot;
die Chancen stehen im Info-Fenster). Maschinen lassen sie liegen, nur Spieler sortieren sie. Die Chancen
sind feste Config-Werte: Nichts, was man mit Robux oder (kaufbarem) Cash kauft, darf sie verändern, sonst
wären es bezahlte Zufallsitems mit Chancen-Anzeige und PolicyService-Pflicht.

## Monetarisierung und Kurve

- Cash-Pakete geben „X Minuten des aktuellen Einkommens“ (15/60/240 min, mit Mindestbetrag), skalieren
  also mit dem Fortschritt und brechen die Kurve nicht. Tagesbelohnungen, Quests und Einladungen
  funktionieren genauso.
- 2x Cash verdoppelt Sortier-, Maschinen- und Offline-Geld, Fast Belts bringt +25 % Pakete. Nichts ist
  ohne Pass gesperrt außer Band 4 („extra Plot-Platz“), das trotzdem mit Spielgeld gebaut wird.
- Preise stehen nie in der Config (nur IDs): Die UI liest sie über
  `MarketplaceService:GetProductInfoAsync`, sonst funktionieren Regional Pricing und Price Optimization
  nicht.

## Boni, Werbung, Angebote und Gratis-Belohnungen

Alles in `Config.Monetization` und `Config.Rewards`, jedes Feature per Config abschaltbar.

- **Boni** addieren sich: Freunde auf dem Server +10 % je Freund (höchstens +30 %), Gruppe +10 %,
  Paket-Club +20 %, zusammen höchstens +60 %. Darauf wirken 2x Cash und der Boost (je ×2). Die
  Simulation rechnet ohne Boni (Einzelspieler ohne Gruppe).
- **Rewarded Video** (freiwillig, mit Hinweis auf dem Button): 2x Cash für 10 min (5-mal am Tag), Auto
  Collect für 15 min (3-mal), Offline-Geld verdoppeln (3-mal). Jede Belohnung gibt es auch für Robux
  (Roblox-Regel für Werbebelohnungen).
- **Starterpaket** (einmal pro Spieler): 30 min Einkommen (mind. $2.500), 30 min 2x Cash und die
  Goldenen Bänder. Wird nach der ersten Maschine einmal pro Sitzung angeboten und steht im Store.
- **Tycoon-Bundle**: 2x Cash + Auto Collect + Fast Belts in einem Pass (im Creator Hub günstiger bepreisen
  als die drei einzeln).
- **Flitzeschuhe**: Laufgeschwindigkeit 16 → 24, also kürzere Wege zwischen Band und Rutschen (bleibt
  unter der Anti-Teleport-Grenze von 40 Studs/s).
- **Spielzeit-Geschenke** pro Tag nach 3/8/15/25/40 Minuten: kleine Geld- und Boost-Belohnungen, passend
  zu Sitzungen ab 10 Minuten (Creator Rewards).
- **Rebirth-Meilensteine**: Rebirth 1 (Bonbon-Halle + Geld), 3 (Glas-Pakete + Geld), 5 (Sternen-Spur +
  30 min Boost), 10 (60 min Einkommen).
- **Tutorial**: $250 am Ende. **Codes** und **Gruppe**: kleine Geld-/Boost-Belohnungen.

## Simulation

`tests/BalanceSim.luau` spielt einen kaufoptimierten Free-Spieler (ohne Pässe und Boosts; seltene Pakete
zählen nur mit dem Durchschnittswert eines normalen Pakets, ihr Bonus kommt obendrauf): Er plant zwei
Käufe voraus, bewertet auch Ketten (z. B. neues Band plus seine Maschinen), wartet sonst auf den besten
und spart für den Rebirth, sobald der höchstens 15 Minuten Einkommen entfernt ist oder der nächste
sinnvolle Kauf mehr als 8 Minuten.

Ergebnis mit den aktuellen Werten (`lune run tests/report`):

| | Runde 1 | Runde 2 | Runde 3 |
|---|---|---|---|
| Erster Kauf | 18 s | 12 s | 6 s |
| Erste Sortiermaschine | 4,8 min | 3,2 min | 2,4 min |
| Band 1 voll automatisiert | 25,1 min | 16,7 min | 12,6 min |
| Zweites Band | 35,4 min | 23,6 min | 17,7 min |
| Band 2 voll automatisiert | 41,3 min | 27,6 min | 20,7 min |
| Rebirth | 72,9 min | 65,5 min | 63,5 min |
| Käufe in den ersten 5 min | 15 | 22 | 25 |
| Einkommen nach 15 min | $847/min | $2.181/min | $4.448/min |
| Einkommen nach 45 min | $5.356/min | $13.160/min | $35.046/min |

`tests/balance.spec.luau` sichert die Ziele ab (erster Kauf ≤ 30 s, erste Maschine 2–6 min, ≥ 12 Käufe
in 5 min, längste Wartezeit in den ersten 15 min ≤ 3 min, Band 1 automatisiert nach 15–30 min, Band 2 nach
35–55 min, Rebirth-Runden 1–3 je 45–75 min). Wer ein Ziel bewusst ändert, passt Test und dieses Dokument
zusammen an.
