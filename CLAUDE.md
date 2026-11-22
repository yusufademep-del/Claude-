# Börsenlehre – Regeln für Videos

Diese Regeln gelten für jedes Video, das für den Kanal „Börsenlehre“ erstellt wird.
**Aktueller Stil: v4** – nachgebaut nach dem „finanzlehre“-Screen-Recording vom 22.11.2026 (Frame-für-Frame analysiert).

## Immer mitliefern
- **Video in 60 fps** (nicht 120), Hochformat 1080×1920.
- **Cover** (1080×1920, JPG + PNG) im Stil der Vorlage-Cover (`video-tools/v4/make_cover.py`, Konfig `cover` in compose4.json):
  weißer Hintergrund, oben links Rubrik mit Farbbalken (BÖRSENNEWS = grün, SPEZIALAUSGABE = rot, ERKLÄRT = grau),
  große Anton-Headline in gemischter Schreibweise (eine Zeile in Rubrikfarbe), darunter Pastell-Feld
  (grün/rosa/lavendel) mit Pinguin-Brustbild. Keine Emojis, kein Badge. Wichtiges im 3:4-Ausschnitt (y 240–1680).
  Dem Nutzer als Datei (Anhang) schicken, nicht nur als Vorschau.
- Caption-Vorschlag mit Hashtags und „Keine Anlageberatung.“
- Quellen für alle Zahlen.

## Video-Stil v4 (`video-tools/v4/`: scene3d.html → render3d.js → compose4.py → mix4.py)
- Cremefarbene **Kopfleiste** oben: Pinguin-Avatar · „börsenlehre“ · THEMA (fett) + Datum (grau). Keine Fortschrittsleiste, kein gelbes Badge.
- Sehr heller, lavendel-weißer Hintergrund (Börsengebäude/Straße), weiße 3D-„Ton“-Objekte mit Schatten.
- **Headlines**: große dunkle Anton-Schrift, 1–2 Zeilen (2. Zeile optional rot), Pop-in mit Überschwingen, raus nach oben.
- **Großer Pinguin** mit weichen Kamerafahrten: `full` ↔ `mid` ↔ `close` (Close-up bei Pointen), 4 Posen
  (base/q/shock/explain) mit Mundbewegung, kleiner Hüpfer beim Posenwechsel.
- **Gelbes Einzelwort** über dem Kopf (schwarze Kontur), bei Betonung drei Striche darüber (`marks`).
- **Milchglas-Karten** (Inter): Titel + Tag rechts, graue Unterzeile, Zeilen „Label … Wert“ mit hochzählendem Wert,
  optional durchgestrichener Altwert, graue Fußzeile mit Stand/Quelle. Sticker-Emoji kann kurz in der Karte erscheinen.
- Große grüne/rote Prozentzahl mit grauer Unterzeile („STAND …“) für Kursbewegungen (`counts`).
- Sticker-Emojis (Twemoji) neben dem Pinguin, wackeln leicht. Soundeffekte und Musik leise (music_lufs −33, sfx_gain 0.45).
- Untertitel nicht einbrennen (nur das gelbe Einzelwort).

## Tools
- **ElevenLabs nur für Audio**: Stimme, Wort-Timings, Soundeffekte, Musik. Keine Bilder/Videos damit.
- Stimme: voice_id `nsFsExJHz4xV1sOX6Kdn` (Christian Plasa – Social Media), Modell `eleven_v4`, 1 Take.
- Pinguin-Originale: `pinguin/mundbewegung/` (4 Posen × Mund zu/halb/offen). Frische Session: `bash video-tools/v4/setup.sh`.

## Inhalt
- Fakten vorher recherchieren, Zwischenstände als „Zwischenstand“ kennzeichnen.
- Bei Anthropic-Themen neutral bleiben (Claude ist von Anthropic).
