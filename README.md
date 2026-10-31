# 🎈 Pump & Fly

Ein Roblox-Spiel: Pump deinen Ballon auf, flieg so hoch wie möglich und sammel Münzen.
**Aber Vorsicht:** Jeder Pumpstoß ist zufällig stark. Wer zu gierig ist, dem platzt der Ballon. 💥

## Spielablauf

1. **PUMPEN** gedrückt halten (PC: `E`). Der Ballon über deinem Kopf wird größer, und alle anderen Spieler sehen ihn.
2. **STARTEN** (PC: `F`). Du fliegst nach oben, je mehr Luft, desto höher.
3. Höhere Zonen geben mehr Münzen: 🌱 Wiese x1 → ☁️ Wolken x1.5 → ⚡ Gewitter x2 → 🚀 Weltall x3 → 🌙 Mond x5 → 🕳️ Die Leere x10
4. Im **Shop** kaufst du größere Ballons (mehr Luft) und stärkere Pumpen (mehr Luft pro Pumpstoß).
5. **Rebirth**: Du startest von vorn, bekommst aber dauerhaft +50 % Münzen.

## Warum das Spiel Potenzial hat, viral zu gehen

| Mechanik | Effekt |
|---|---|
| „Nur noch EIN Pump…“ + Platz-Risiko | Spannung, Wut und Lachen ergeben perfekte TikTok/Shorts-Clips |
| Ballon wächst sichtbar über dem Kopf | Andere sehen deinen Fortschritt, das macht neidisch und motiviert |
| 👥 Freunde-Boost (+10 % pro Freund, max. +50 %) | Spieler laden ihre Freunde ein |
| 🎟 Codes (`START`, `POP`, `HALLOWEEN`) | Leute holen sich Codes von deinem TikTok/Discord |
| 🎁 Gratis-Geschenk alle 15 Min | Spieler bleiben länger |
| 🏆 Weltweite Bestenliste | Wettbewerb um Platz 1 |
| Kurze Runden (10–20 Sek) | Gut für Handy-Spieler (die meisten auf Roblox) |

## Installation (Windows)

### Variante A: einfach (ohne Programmierkenntnisse)
1. Lade `PumpAndFly.rbxlx` aus diesem Repo herunter.
2. Öffne die Datei per Doppelklick in **Roblox Studio**.
3. Auf **Play** drücken, fertig. Die Map baut sich automatisch.

> Wenn du Skripte änderst: `python tools/build_place.py` baut die `.rbxlx` neu.

### Variante B: mit Rojo (für Entwickler)
```
rojo serve
```
Dann im Rojo-Plugin in Studio auf „Connect“ klicken.

## Vor der Veröffentlichung ⚠

1. **File → Publish to Roblox** (Spiel hochladen).
2. **Game Settings → Security → „Enable Studio Access to API Services“** einschalten, sonst funktionieren Speichern und Bestenliste nicht.
3. **2x-Münzen Game Pass** (bringt dir Robux):
   - Im Creator Hub unter Monetization → Passes einen Pass erstellen
   - Die Pass-ID in `src/shared/Config.luau` bei `Config.GamePasses.DoubleCoins` eintragen
   - Neu bauen. Der 💎-Button erscheint automatisch.
4. **Automatische Übersetzung** im Creator Hub aktivieren. Die Spieltexte sind auf Deutsch, Roblox übersetzt sie dann für Spieler aus anderen Ländern.

## Launch-Checkliste für Reichweite

- **Titel:** `🎈 Pump & Fly [🎃 HALLOWEEN]`. Ein Update-Tag im Namen erhöht die Klickrate.
- **Thumbnail:** Riesiger platzender Ballon, geschocktes Gesicht, Text „DON'T POP IT!“
- **TikTok/Shorts-Ideen:**
  - „Ich hab 1 Stunde gepumpt und dann…“ 💥
  - Zeitraffer vom ersten Flug bis zur Leere
  - „Platzt er oder nicht?“ (Zuschauer kommentieren)
  - Neuen Code am Ende jedes Videos zeigen
- **Jede Woche ein Update:** neuer Ballon, neue Zone oder neuer Code. Das hält den Algorithmus warm.
- Am Anfang ein paar Robux in **Sponsored Ads** stecken. So kommen erste Spieler, und ohne Spieler zeigt Roblox das Spiel niemandem.

## Anpassen

Das komplette Balancing (Preise, Ballons, Pumpen, Zonen, Codes, Boosts) steht in
`src/shared/Config.luau`. Du kannst dort einfach Zahlen ändern oder neue Einträge hinzufügen.

## Dateien

```
src/shared/Config.luau        Einstellungen & Balancing
src/server/Main.server.luau   Spiellogik, Speichern, Bestenliste (server-seitig, schwer zu cheaten)
src/server/World.luau         Baut die Map automatisch
src/client/Client.client.luau UI, Steuerung, Flug-Animation
tools/build_place.py          Baut PumpAndFly.rbxlx
```
