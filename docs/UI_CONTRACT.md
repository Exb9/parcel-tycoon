# UI-Vertrag (Studio MCP ↔ Code)

Die gesamte UI (HUD, Fenster, Buttons, Toasts) baut die lokale Session per **Studio MCP** in
`StarterGui`. Der Client-Code (`src/client`) erzeugt keine UI, er bindet sich nur an die Namen unten.
Fehlt etwas oder hat die falsche Art, meldet der Client beim Start im Output `[UI] …` und läuft trotzdem
weiter. Die Elementliste am Ende wird aus `src/shared/UiContract.luau` erzeugt
(`lune run tools/ui-contract-doc`), ein Test prüft, dass sie aktuell ist.

Welt-UI (Beschriftungen an Ausgängen, Kasse, Schild, Leaderboards, Paketen) steht in
[`MAP_CONTRACT.md`](MAP_CONTRACT.md).

## Grundregeln

- **Drei ScreenGuis** in `StarterGui`: `HUD`, `Windows`, `Toasts`, jeweils **`ResetOnSpawn = false`**.
- **Namen exakt** wie in der Elementliste (Groß-/Kleinschreibung zählt). Zusätzliche Deko-Elemente
  (UICorner, UIStroke, UIGradient, Icons, Layouts, Paddings) sind jederzeit erlaubt.
- **Arten**
  - `Text`: ein TextLabel oder TextButton, oder ein Rahmen, der ein TextLabel namens `Text` enthält. Den
    Text schreibt der Code.
  - `Button`: TextButton oder ImageButton (der Code hört auf `Activated`).
  - `Frame`: beliebiges GuiObject; der Code schaltet nur `Visible` oder klont es.
  - `Image`: ImageLabel.
  - `TextBox`: Texteingabe (TextBox); ein TextKey dort setzt den Platzhaltertext.
- **Listen**: Ein Container (z. B. ScrollingFrame mit UIListLayout oder UIGridLayout,
  `SortOrder = LayoutOrder`, `AutomaticCanvasSize` passend) enthält ein Kind `Template`. Der Code blendet
  `Template` aus, klont es pro Eintrag, setzt `LayoutOrder` und füllt die Felder. Das Template im
  Editor gern mit Beispieltexten füllen.
- **Feste Texte** (Titel, Tab- und Button-Beschriftungen, Hinweise) bekommen das String-Attribut
  **`TextKey`** mit einem Schlüssel aus `src/localization/GameText.csv` (Tabelle unten). Der Client
  übersetzt sie (Englisch, Deutsch). Als Text in Studio einfach den englischen Text eintragen. Elemente
  der Art `Text` bekommen **kein** TextKey, deren Text setzt der Code.
- **Startzustand**: Fenster (`Windows/*`) und alle optionalen Markierungen (`Badge`, `Selected`, `Locked`,
  `Owned`, `Done`, `Claimed`, `Next`, `Equipped`, `Member`) sowie `HUD/Boost`, `HUD/AutoCollect`,
  `HUD/Bonus`, `HUD/CarryHint`, `HUD/CollectorFull`, `HUD/Tutorial`, `HUD/Gift`, `HUD/AdBoost` stehen auf
  `Visible = false`; der Code blendet sie ein.
- **Werbe-Buttons** (`HUD/AdBoost`, `Windows/Store/AdAutoCollect`, `Windows/WelcomeBack/DoubleAd`) sind
  Rewarded-Video-Angebote. Roblox verlangt, dass auf dem Button steht, dass eine Werbung kommt und was es
  dafür gibt: Das erledigen die TextKeys `ads.*` (z. B. „Watch an ad: 2x Cash for 10 min“). Ein kleines
  Video-Symbol daneben ist erlaubt. Der Code zeigt sie nur Spielern, die Werbung sehen dürfen.
- **Angebote freundlich formulieren** (Roblox-Richtlinie für junge Spieler): keine Countdowns, kein
  „JETZT KAUFEN“/„LETZTE CHANCE“. Buttons heißen „Buy“, „Maybe later“, „Open Shop“.
- **Mobile first**: Das Menü sitzt **unten rechts**, Touch-Flächen mindestens etwa 44 px, Größen in Scale
  plus `UIAspectRatioConstraint`/`UISizeConstraint`, damit es auf Handy und PC passt. Fenster mittig und
  so groß, dass sie auf einem Handy im Querformat ganz sichtbar sind.
- **Nicht erlaubt**: eigene Knöpfe oben links (Chat) oder oben rechts (Spielerliste), das 🪙-Emoji (wird
  nicht gerendert; für Geld „$“ oder 💰), gedrehte Frames als Deko in Buttons (ClipsDescendants schneidet
  sie nicht ab), Scripts oder LocalScripts in der UI (Logik liegt nur in `src/client`).

## Was der Code mit den Elementen macht

### HUD

| Element | Verhalten |
|---|---|
| `Cash` | Kontostand, z. B. `$1.23K` |
| `Income` | geschätztes Einkommen, z. B. `$120/min` (mit Bonus und laufendem Boost) |
| `Boost` | sichtbar, solange ein 2x-Cash-Boost läuft; Text `2x Cash 4:59` |
| `AutoCollect` | optional; sichtbar, solange Auto Collect auf Zeit läuft; Text `Auto Collect 12:34` |
| `Bonus` | optional; sichtbar mit Freunde-/Gruppen-/Club-Bonus; Text `Bonus +20%` |
| `Tutorial` | Hinweis zum aktuellen Tutorial-Schritt für neue Spieler („Tap a parcel on your belt …“, zweizeilig einplanen), danach unsichtbar |
| `Gift` | Spielzeit-Geschenk: zeigt `Gift in 3:20`, dann `Open gift!` und öffnet es beim Antippen; weg, wenn alle Geschenke des Tages geöffnet sind. TextButton oder Button mit TextLabel `Text` |
| `AdBoost` | Werbe-Button (TextKey `ads.boost`): Video ansehen, 10 min 2x Cash; höchstens 5-mal am Tag |
| `CarryHint` | sichtbar beim Tragen: `Take it to TOWN!`, bei zerbrechlichen Paketen zweite Zeile `Fragile! Don't jump.` (zweizeilig einplanen) |
| `CollectorFull` | sichtbar, wenn die Kasse voll ist (enthält ein Label mit TextKey `hud.collectorFull`) |
| `Menu/*` | öffnen/schließen das gleichnamige Fenster (`Codes` öffnet das Codes-Fenster); `Invite` öffnet Roblox' Freunde-Einladen-Dialog und wird ausgeblendet, wo Einladungen nicht gehen |
| `Menu/Quests/Badge` | Quest fertig und abholbar |
| `Menu/Daily/Badge` | Tagesbelohnung abholbar |
| `Menu/Rebirth/Badge` | genug Geld für einen Rebirth |

### Windows

Es ist immer höchstens ein Fenster offen; `Close` schließt es. Tabs: Ein Button `<Name>Tab` zeigt das
gleichnamige Element `<Name>` und versteckt die anderen, `<Name>Tab/Selected` markiert den aktiven Tab.

| Fenster | Verhalten |
|---|---|
| `Shop` | Tab `Upgrades`: je Upgrade `Title`, `Description`, `Level` („Level 3/25“), `Price` (oder „MAX“), `Buy`; `Locked` sichtbar, wenn das Geld nicht reicht. Tab `Machines`: Maschinen, Rutschen und Bänder, die gerade kaufbar sind (billigste zuerst); `Price` zeigt bei Band 4 ohne Pass „Needs Bigger Warehouse“, dann öffnet `Buy` den Store. `Machines/AllBuilt` erscheint, wenn alles gebaut ist. |
| `Store` | Tabs `Passes` (Bundle zuerst), `Products` (Starterpaket zuerst, verschwindet nach dem Kauf), `Styles` und `Club`. `Price` zeigt den Robux-Preis von Roblox (Robux-Symbol + Zahl), in Studio „Test“ für noch nicht angelegte Angebote (ID 0), live „Soon“. `Icon` (optional) bekommt das Bild des Passes/Produkts. Gekaufte Pässe und Styles: `Owned` sichtbar, `Buy` versteckt. `AdAutoCollect` ist der Werbe-Button „Auto Collect 15 min testen“ (nur ohne Auto Collect). Tab `Club` (nur sichtbar, wenn das Abo angelegt ist): `Description` („+20% cash, a daily gift …“), `Price` (Abo-Preis pro Monat), `Join` (für Nicht-Mitglieder), `Member` und `Claim` (Tagesgeschenk) für Mitglieder, `Claimed` wenn heute schon abgeholt. |
| `Quests` | drei Tagesquests: `Title` („Sort 25 parcels by hand“), `Progress` („12/25“), `Bar/Fill` (Breite = Fortschritt, der Code ändert nur die X-Scale), `Reward`, `Claim` (wenn fertig), `Done` (wenn abgeholt). `ResetTimer` zählt bis zu neuen Quests herunter. |
| `Daily` | `Days/Day1` … `Day7` mit `Title` („Day 1“) und `Reward` (Betrag oder „2x Cash 10 min“); `Claimed` für abgeholte Tage, `Next` für den heute abholbaren. `Claim` ist sichtbar, wenn heute noch nichts abgeholt wurde, sonst `Status` („Come back tomorrow …“ mit Countdown). |
| `Rebirth` | `Cost` („Needs $150K“), `Bonus` („Income x1 -> x1.5“), `Bar/Fill` (optional, Geld/Kosten), `Confirm` startet den Rebirth. Liste `Milestones`: Belohnungen für Rebirth 1/3/5/10 (`Title` „Rebirth 3“, `Reward` „Glass Parcels + $10K“, `Done` wenn erreicht). |
| `Style` | gekaufte Styles: `Title`, `Slot` („Trails“), `Equip` (Text setzt der Code: „Use“/„In use“, kein TextKey), `Equipped` (optional). `Empty` erscheint, wenn noch nichts gekauft ist. |
| `Info` | feste Spielanleitung (TextKeys), die Liste `Odds` mit den Chancen des Überraschungs-Bonus (`Title`, `Chance`) und das Feld `Group`: `Status` („Join our group: +10% cash and a gift!“ bzw. „Group bonus active“), `Join` öffnet Roblox' Gruppen-Beitritt. `Group` bleibt unsichtbar, solange keine Gruppen-ID eingetragen ist. |
| `Offer` | Popup mit einem Angebot im passenden Moment (Starterpaket nach der ersten Maschine, Auto Collect bei voller Kasse, Bigger Warehouse vor Band 4); höchstens eins alle 5 Minuten und jedes nur einmal pro Sitzung. `Title`, `Description`, `Price`, `Icon` (optional), `Buy`; `Close` mit TextKey `offer.later` („Maybe later“). |
| `WelcomeBack` | nach dem Einloggen: `Amount` („Your machines earned $1.2K while you were away.“, schon ausgezahlt), `Collect` schließt, `DoubleAd` verdoppelt per Werbung, `DoubleBuy` + `DoublePrice` verdoppeln für Robux. |
| `Codes` | `Input` (TextBox) und `Redeem`; Enter löst auch ein. Ergebnis als Toast. |

### Toasts

| Element | Verhalten |
|---|---|
| `Small` | Container (z. B. oben Mitte unter der Topbar, UIListLayout); pro Meldung ein Klon von `Template`, verschwindet nach 2,5 s, höchstens 4 gleichzeitig. Optionaler Button `Template/Action` für Links wie „Open Shop“ bei „Not enough cash“ (der Code setzt seinen Text) |
| `Big` | Container in der Bildschirmmitte; große Meldungen (Belohnungen, Rebirth) nacheinander, je 3 s |

## TextKeys für feste Texte

| Wo | TextKey |
|---|---|
| Menü-Buttons (`HUD/Menu/*`, auf dem Button oder seinem Label) | `menu.shop`, `menu.store`, `menu.quests`, `menu.daily`, `menu.rebirth`, `menu.style`, `menu.invite`, `menu.codes`, `menu.info` |
| Werbe-Buttons (Pflicht-Hinweis auf Werbung und Belohnung) | `HUD/AdBoost`: `ads.boost`, `Windows/Store/AdAutoCollect`: `ads.autoCollectTrial`, `Windows/WelcomeBack/DoubleAd`: `ads.doubleOffline` |
| Label in `HUD/CollectorFull` | `hud.collectorFull` |
| Shop: Titel, Tabs, `Buy` im Template, Label in `Machines/AllBuilt` | `shop.title`, `shop.tabUpgrades`, `shop.tabMachines`, `shop.buy`, `shop.allBuilt` |
| Store: Titel, Tabs, `Buy`, Label in `Owned` | `store.title`, `store.passes`, `store.products`, `store.styles`, `store.club`, `shop.buy`, `store.owned` |
| Club-Tab: Überschrift, `Join`, Label in `Member`, `Claim`, Label in `Claimed` | `club.title`, `club.join`, `club.member`, `club.claim`, `club.claimed` |
| Quests: Titel, `Claim`, Label in `Done` | `quests.title`, `quests.claim`, `quests.claimed` |
| Daily: Titel, `Claim` | `daily.title`, `daily.claim` |
| Rebirth: Titel, Beschreibung, Hinweis, `Confirm`, Überschrift der Meilensteine | `rebirth.title`, `rebirth.desc`, `rebirth.keep`, `rebirth.button`, `rebirth.milestones` |
| Style: Titel, Label in `Empty` | `style.title`, `style.empty` |
| Info: Titel, Anleitung, seltene Pakete, Überschrift der Chancen, Gruppe (Überschrift, `Join`) | `info.title`, `info.text`, `info.rare`, `info.mysteryOdds`, `group.title`, `group.join` |
| WelcomeBack: Titel, `Collect`, `DoubleBuy` | `welcome.title`, `welcome.collect`, `welcome.double` |
| Offer: `Close` | `offer.later` |
| Codes: Titel, `Input` (Platzhalter), `Redeem` | `codes.title`, `codes.placeholder`, `codes.redeem` |

## Elementliste

Pfade unter `PlayerGui` (= Aufbau in `StarterGui`). Nicht als optional markierte Elemente sind Pflicht.

<!-- ui-elements:start -->
```
HUD                               ScreenGui
  Cash                            Text
  Income                          Text
  Boost                           Text
  CarryHint                       Text
  CollectorFull                   Frame
  AutoCollect                     Text (optional)
  Bonus                           Text (optional)
  Tutorial                        Text
  Gift                            Button
  AdBoost                         Button
  Menu                            Frame
    Shop                          Button
    Store                         Button
    Quests                        Button
      Badge                       Frame (optional)
    Daily                         Button
      Badge                       Frame (optional)
    Rebirth                       Button
      Badge                       Frame (optional)
    Style                         Button
    Invite                        Button
    Codes                         Button
    Info                          Button
Windows                           ScreenGui
  Shop                            Frame
    Close                         Button
    UpgradesTab                   Button
      Selected                    Frame (optional)
    MachinesTab                   Button
      Selected                    Frame (optional)
    Upgrades                      Frame
      Template                    Frame
        Title                     Text
        Description               Text
        Level                     Text
        Price                     Text
        Buy                       Button
        Locked                    Frame (optional)
    Machines                      Frame
      Template                    Frame
        Title                     Text
        Description               Text
        Price                     Text
        Buy                       Button
        Locked                    Frame (optional)
      AllBuilt                    Frame
  Store                           Frame
    Close                         Button
    PassesTab                     Button
      Selected                    Frame (optional)
    ProductsTab                   Button
      Selected                    Frame (optional)
    StylesTab                     Button
      Selected                    Frame (optional)
    ClubTab                       Button
      Selected                    Frame (optional)
    Passes                        Frame
      Template                    Frame
        Title                     Text
        Description               Text
        Price                     Text
        Buy                       Button
        Icon                      Image (optional)
        Owned                     Frame (optional)
    Products                      Frame
      Template                    Frame
        Title                     Text
        Description               Text
        Price                     Text
        Buy                       Button
        Icon                      Image (optional)
        Owned                     Frame (optional)
    Styles                        Frame
      Template                    Frame
        Title                     Text
        Description               Text
        Price                     Text
        Buy                       Button
        Icon                      Image (optional)
        Owned                     Frame (optional)
    AdAutoCollect                 Button
    Club                          Frame
      Description                 Text
      Price                       Text
      Join                        Button
      Member                      Frame
      Claim                       Button
      Claimed                     Frame (optional)
  Quests                          Frame
    Close                         Button
    List                          Frame
      Template                    Frame
        Title                     Text
        Progress                  Text
        Bar                       Frame
          Fill                    Frame
        Reward                    Text
        Claim                     Button
        Done                      Frame (optional)
    ResetTimer                    Text
  Daily                           Frame
    Close                         Button
    Days                          Frame
      Day1                        Frame
        Title                     Text
        Reward                    Text
        Claimed                   Frame (optional)
        Next                      Frame (optional)
      Day2                        Frame
        Title                     Text
        Reward                    Text
        Claimed                   Frame (optional)
        Next                      Frame (optional)
      Day3                        Frame
        Title                     Text
        Reward                    Text
        Claimed                   Frame (optional)
        Next                      Frame (optional)
      Day4                        Frame
        Title                     Text
        Reward                    Text
        Claimed                   Frame (optional)
        Next                      Frame (optional)
      Day5                        Frame
        Title                     Text
        Reward                    Text
        Claimed                   Frame (optional)
        Next                      Frame (optional)
      Day6                        Frame
        Title                     Text
        Reward                    Text
        Claimed                   Frame (optional)
        Next                      Frame (optional)
      Day7                        Frame
        Title                     Text
        Reward                    Text
        Claimed                   Frame (optional)
        Next                      Frame (optional)
    Claim                         Button
    Status                        Text
  Rebirth                         Frame
    Close                         Button
    Cost                          Text
    Bonus                         Text
    Confirm                       Button
    Bar                           Frame (optional)
      Fill                        Frame (optional)
    Milestones                    Frame
      Template                    Frame
        Title                     Text
        Reward                    Text
        Done                      Frame (optional)
  Style                           Frame
    Close                         Button
    List                          Frame
      Template                    Frame
        Title                     Text
        Slot                      Text
        Equip                     Button
        Equipped                  Frame (optional)
    Empty                         Frame
  Info                            Frame
    Close                         Button
    Odds                          Frame
      Template                    Frame
        Title                     Text
        Chance                    Text
    Group                         Frame
      Status                      Text
      Join                        Button
  Offer                           Frame
    Close                         Button
    Title                         Text
    Description                   Text
    Price                         Text
    Buy                           Button
    Icon                          Image (optional)
  WelcomeBack                     Frame
    Close                         Button
    Amount                        Text
    Collect                       Button
    DoubleAd                      Button
    DoubleBuy                     Button
    DoublePrice                   Text
  Codes                           Frame
    Close                         Button
    Input                         TextBox
    Redeem                        Button
Toasts                            ScreenGui
  Small                           Frame
    Template                      Text
      Action                      Button (optional)
  Big                             Frame
    Template                      Text
```
<!-- ui-elements:end -->

## Testen

1. `rojo serve`, in Studio verbinden, Play drücken.
2. Output prüfen: keine Zeilen mit `[UI]` oder `[Map]`.
3. Zustände ohne langes Spielen herstellen: Debug-Hook `ServerStorage.ParcelDebug` (nur in Studio), z. B.
   per Studio MCP `execute_luau` im Play-Modus auf dem Server:
   `game.ServerStorage.ParcelDebug:Invoke("cash", 5000)`, `…:Invoke("pass", "vip")`,
   `…:Invoke("daily")`, `…:Invoke("quests", "done")`, `…:Invoke("offer", "product", "starterPack")`,
   `…:Invoke("offline", 3600)` (Willkommen-zurück-Fenster), `…:Invoke("gift")`, `…:Invoke("tutorial")`;
   `…:Invoke("help")` listet alle Befehle.
4. Deutsch testen: Studio → Test → Player Emulator → Locale `de-de`.
