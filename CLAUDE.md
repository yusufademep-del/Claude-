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
- **Durchgehende 3D-Stadt** (lavendel-weiße „Ton“-Optik, Nebel, weiche Schatten): Straße mit Börsen- und Bürogebäuden,
  Rotunden, Laternen, Ampeln, Bäumen. Jede Szene ist eine **Station** entlang der Straße (`stations`); die Kamera fährt
  fließend dorthin (Bogen + leichter Schwenk, `cams` in seg.json), dazwischen langsamer Dolly. Objekte stehen fest in der
  Welt und wachsen beim Ankommen heraus (kein Auf-/Zuploppen). Szenen-Bausteine: Münzstapel + %, Angelhaken + ?,
  Zahnräder, GEWINN-Sockel mit Chartlinie gegen roten DECKEL (Buchstaben kippen nacheinander), wachsende
  Vergleichssäulen, Pokal + Pfeil, Münzregen.
- **Filter am Anfang** (`filter` in compose4.json): weicher Rosa-Lila-Verlauf + leichte Unschärfe über dem Hintergrund,
  blendet beim ersten Kamerawechsel aus. Bei Close-ups Tiefenunschärfe im Hintergrund (`dof_blur`).
- **Aus Vorlage 2 („Rechenzentren im All“):** Titel-Banner oben (cremefarbener Kasten, 2 Zeilen Anton, ein Wort gold;
  `banner`), schwebende lila Bokeh-Partikel + kleine Sterne (`particles`), Orbit-Kamera um ein Held-Objekt
  (`cams` mit `orbit`/`a0`/`z`), Pinguin verlässt das Bild nach unten für reine 3D-Passagen (`shots` mit `[t, 560, 2700]`)
  und kommt zur Pointe im Close-up zurück, kleine Pille oben (`toppills`), Maßlinie mit Beschriftung (`dimlines`),
  Glas-Etikett mit Zeigerlinie (`labels`). Weitere 3D-Bausteine: Kalender-Held, rote Kerzen, Fabrik mit Flaggen + Rauch,
  aufgehende Sonne, Server-Rack mit LEDs + 3D-Logotext, Wochen-Kacheln MO–FR. Pro Video nur die nötigen Objekte (`use`).
- Projekt-Konfigurationen liegen in `video-tools/v4/projects/<name>/` (compose4.json, seg.json, words.json).
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
