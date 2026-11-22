# Übergabe – Börsenlehre (Stand 22.11.2026)

## Ziel
TikTok/Reels/Shorts-Kanal **„Börsenlehre“**: ein Pinguin-Reporter erklärt täglich Börsen-News und Finanzthemen
in kurzen Hochformat-Videos (~30–45 s), Stil angelehnt an die Eule von „finanzlehre“.

## Feste Entscheidungen (siehe auch CLAUDE.md)
- **Charakter:** Pinguin „Börsenlehre“, Anzug, Mikro, Namensschild „BÖRSEN LEHRE“, 4 Posen (base, q, shock, explain)
  mit Mundbewegung zur Stimme und weichen Posenwechseln.
- **Stimme:** ElevenLabs voice_id `nsFsExJHz4xV1sOX6Kdn` (Christian Plasa – Social Media), Modell `eleven_v4`, 1 Take.
- **ElevenLabs nur für Audio** (Stimme, Wort-Timings, Soundeffekte, Musik) – keine Bilder/Videos.
- **Immer 60 fps**, 1080×1920 (keine 120 fps).
- **Immer ein Cover** (1080×1920, JPG + PNG) mitliefern und als Datei (Anhang) schicken.
- **Stil:** heller Hintergrund (Börsengebäude mit Chartlinie), weiße 3D-„Ton“-Objekte mit Schatten, große schwarze
  Headline, hochzählende Zahlen, Glas-Infokarten, Linienchart-Karten, Kamera-Zooms auf den Pinguin,
  einzelne gelbe Wörter über dem Kopf, Emojis (Twemoji), Soundeffekte, Hintergrundmusik.
  Vorlagen: Screen-Recordings der „finanzlehre“-Videos vom 20.11.
- Immer Caption-Vorschlag + Hashtags + „Keine Anlageberatung.“ + Quellen; Zwischenstände kennzeichnen.
- Bei Anthropic-Themen neutral bleiben.

## Technik
- Pipeline: `video-tools/v3/` → `scene3d.html` (Three.js, 3D-Szenen) → `render3d.js` (Playwright rendert 3D-Video)
  → `compose3.py` (Pinguin, Headlines, Karten, Zahlen, Untertitel) → `mix3.py` (Stimme + Musik + SFX).
- Konfiguration pro Video: `seg.json` (3D-Zeitfenster) und `compose3.json` (2D-Elemente, Timings).
- Verfügbare 3D-Objekte: Börsengebäude, kippender 3D-Text, Treppe mit Kugel, fallende Chips, Punktwolke,
  Pfeil hoch/runter, rote Kerzen, Deutschlandkarte, Klapp-Kalender, Pokal, Münzregen.
- Ältere Versionen: `video-tools/v2/` (dunkler 3D-Stil), Branding in `branding/`, Website-Entwurf in `website/`.

## Aktueller Stand (alles im Repo, Branch `claude/brave-brown-tk6ndu`)
- Videos: Vorstellung, Nvidia-Zahlen, Nvidia & Fed-Zinsen, Anthropic-IPO (3×), Tech-Crash 19.11.,
  Tech-Crash Teil 2 (20.11.), Tagesrückblick 20.11., Wochenausblick KW 48, Erklär-Video „Rekord & Minus“.
- Branding: Profilbild, YouTube-Banner, Bios (`branding/`).
- Website-Entwurf mit 3D-Hero (`website/`, Vorschau-Artifact vorhanden).

## Offene Punkte
- Website: echte Social-Links eintragen, Impressum/Datenschutz ausfüllen, Hosting (z. B. GitHub Pages) einrichten.
- Video-Ideen auf Halde: „Was ist eine Korrektur?“, „Was ist die PCE-Inflation?“ (vor Mi. 25.11.),
  „Lohnt sich ein IPO direkt?“, Wochenrückblick.
- Nächste Woche: PCE + BIP (Mi. 25.11.), Dell/HP-Zahlen, Thanksgiving (Do. zu), Black Friday (Fr. halber Tag).
- Kleinigkeiten in Videos: manchmal überlappen 3D-Objekte kurz bei Szenenwechseln.
