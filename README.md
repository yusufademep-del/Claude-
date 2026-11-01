# 📦 Lager-Imperium

Ein Roblox-Tycoon rund um ein Logistik-Lager. Du nimmst Aufträge an, entlädst und belädst LKWs,
baust dein Lager Stück für Stück frei nach deinen Vorstellungen aus und automatisierst es am Ende mit Gabelstaplern.

## So läuft das Spiel

1. **📋 Aufträge** öffnen und einen Auftrag annehmen. Ein LKW fährt auf der Straße heran und setzt rückwärts an deine Laderampe.
2. **Wareneingang ⬇**: Hinten an den LKW gehen und **E** drücken, um Kisten zu entladen. Dann zum Regal laufen und mit **E** einlagern.
3. **Warenausgang ⬆**: Am Regal mit **F** auslagern, zum LKW bringen und mit **E** beladen. Das bringt richtig Geld.
4. Jeder Auftrag hat ein **Zeitlimit**. Wer zu langsam ist, dem fährt der LKW einfach weg.
5. Mit dem Geld **baust und erweiterst** du dein Lager.

## Bauen 🔨

- **Freies Platzieren auf einem Raster.** Die Vorschau ist grün, wenn ein Objekt passt, und rot, wenn nicht.
- **PC:** Maus = Position, Linksklick = platzieren, `R` = drehen, `Q` = fertig
- **Handy:** Tippen = Position wählen, dann ✔ Platzieren
- **🗑 Abreißen** gibt dir 50 % des Preises zurück. Waren aus einem Regal wandern dabei automatisch in die anderen Regale.
- **🧱 Erweitern**: Kauf neue Flächen-Stücke in jede Richtung, die an dein Lager grenzt. So bekommt jedes Lager seine eigene Form. Ein Grundstück hat insgesamt 5 × 4 Flächen.

| Kategorie | Objekte |
|---|---|
| **Lager** | Kleines Regal (10), Großes Regal (30), Hochregal (80), Mega-Hochregal (200) |
| **Technik** | Laderampe (nur vorne an der Straße, 1 Rampe = 1 LKW gleichzeitig), Packstation (+10 % beim Ausgang), Kaffeeautomat (schneller laufen), Gabelstapler (arbeitet automatisch), Förderband (macht Gabelstapler schneller und trägt dich mit), Büro-Container (mehr Aufträge, +5 %) |
| **Bau** | Wand, Fensterwand, Rolltor, Stahlsäule, Betonboden, Epoxid-Boden, Fahrspur |
| **Deko** | Pflanze, Hallenlampe, Palettenstapel, Absperrung, Fässer, Firmenschild mit deinem Namen |

## Fortschritt

- **Level & XP** für jede bewegte Kiste und jeden erledigten Auftrag. Höhere Level schalten neue Objekte, größere Aufträge und wertvollere Waren frei:
  🥫 Lebensmittel → 👕 Kleidung → 📱 Elektronik → 🛋️ Möbel → 🧸 Spielzeug → 💊 Medizin
- **🛠 Ausrüstung**: Hände (1 Kiste) → Sackkarre (3) → Hubwagen (6) → Elektro-Ameise (12) → Mini-Stapler (25)
- **Automatisierung**: Gabelstapler entladen, lagern ein und beladen ganz von allein. Förderbänder machen sie schneller.
- **🎟 Codes**: `START`, `LAGER`, `LKW`. Eigene Codes stellst du in `Config.luau` ein.
- Dein Fortschritt wird gespeichert: das komplette Lager inklusive aller Kisten in den Regalen.

## Installation (Windows)

1. `LagerImperium.rbxlx` aus diesem Repo herunterladen (Datei anklicken → Download-Pfeil oben rechts).
2. Per Doppelklick in **Roblox Studio** öffnen.
3. Auf **▶ Play** drücken. Die Map mit Straße und 6 Grundstücken baut sich automatisch auf.

> Wenn du Skripte änderst: `python tools/build_place.py` baut die `.rbxlx` neu.
> Mit Rojo geht's auch: `rojo serve`.

## Vor der Veröffentlichung ⚠

1. **Datei → In Roblox veröffentlichen**
2. **Spieleinstellungen → Sicherheit → „Studio-Zugriff auf API-Dienste aktivieren“** einschalten (sonst wird nichts gespeichert)
3. **Spieleinstellungen → Allgemein → Max. Spieler auf 6** stellen (6 Grundstücke pro Server)
4. Im Creator Hub die **automatische Übersetzung** aktivieren, damit Spieler aus anderen Ländern das Spiel verstehen

## Anpassen

- `src/shared/Config.luau`: Preise, Waren, Level, Belohnungen, Codes, Ausrüstung
- `src/shared/Items.luau`: alle baubaren Objekte. Ein neues Objekt braucht nur einen Eintrag in `Items.List` und eine Bau-Funktion, dann erscheint es automatisch im Bau-Menü mit 3D-Vorschau.

## Dateien

```
src/shared/Config.luau          Einstellungen & Balancing
src/shared/Items.luau           Baubare Objekte (Daten + 3D-Modelle)
src/server/Main.server.luau     Aufträge, Tragen, Bauen, Speichern, Automatisierung
src/server/Plots.luau           Grundstücke, Raster, Regale
src/server/Trucks.luau          LKW-Modell und Fahrten
src/server/World.luau           Straße & Grundstücke
src/client/Client.client.luau   HUD, Auftrags-Tafel, Bau-Menü, Tutorial
src/client/BuildMode.luau       Platzieren / Drehen / Abreißen / Erweitern
src/client/UI.luau              UI-Baukasten
tools/build_place.py            Baut LagerImperium.rbxlx
```
