#!/usr/bin/env bash
# Stellt alle Assets für die v3-Pipeline wieder her (frische Session).
# Nutzung: bash video-tools/v3/setup.sh
set -e
V3="$(cd "$(dirname "$0")" && pwd)"; VT="$(dirname "$V3")"
mkdir -p "$VT/pkgs" "$VT/icons" "$VT/nv"
cd "$VT/pkgs"
for p in @expo-google-fonts/montserrat@0.2.3 @expo-google-fonts/anton@0.2.3 three@0.128.0 @twemoji/svg@15.0.0; do npm pack -q "$p" >/dev/null; done
for f in expo-google-fonts-montserrat-0.2.3 expo-google-fonts-anton-0.2.3 three-0.128.0 twemoji-svg-15.0.0; do mkdir -p "$f" && tar -xzf "$f.tgz" -C "$f"; done
cp three-0.128.0/package/build/three.min.js "$V3/"
(printf 'window.FONTJSON='; cat three-0.128.0/package/examples/fonts/helvetiker_bold.typeface.json; printf ';') > "$V3/font.js"
pip install -q scipy numpy pillow 2>/dev/null || true
python3 "$V3/make_sprites.py"      # Pinguin-Sprites aus pinguin/mundbewegung/ (4 Posen × 3 Münder)
python3 "$V3/make_bg.py"           # bgimg.js (heller Hintergrund)
# Musik (ElevenLabs, im Repo als mp3) auf Länge bringen
[ -f "$V3/music.mp3" ] && ffmpeg -v error -y -stream_loop 2 -i "$V3/music.mp3" -t 120 -ar 48000 "$VT/nv/music_long.wav"
# Emojis: node video-tools/v3/emoji.js <codes...>  (Twemoji SVG -> PNG 256px)
echo "setup ok"
