"""Mix voice + ducked music + timed SFX, then mux with the composed video."""
import json, os, subprocess, sys
D = os.path.dirname(os.path.abspath(__file__))
SP = os.path.dirname(D)
CFG = json.load(open(f"{D}/compose3.json"))
DUR = CFG["dur"]
video, out = sys.argv[1], sys.argv[2]

events = []  # (file, time, volume, trim, fade)
for t in CFG["segments"]:
    events.append(("whoosh", max(0, t - 0.3), 1.0, 0.7))
for c in CFG["cards"]:
    for r in c["rows"]: events.append(("pop", r["t"], 0.55, 0.5))
for e in CFG["emojis"] + CFG["counts"] + CFG.get("pills", []):
    events.append(("pop", e["t0"], 0.5, 0.5))
for t in CFG.get("boom", []):
    events.append(("boom", t, 0.9, 1.0))
for t in CFG.get("cash", []):
    events.append(("cash", t, 0.6, 1.2))
for t in CFG.get("bell", []):
    events.append(("bell", t, 0.45, 1.8))

inputs = ["-i", video, "-i", f"{D}/voice.wav", "-i", f"{SP}/nv/music_long.wav"]
fc = [f"[2:a]loudnorm=I={CFG.get("music_lufs", -26)}:TP=-6,afade=t=in:d=0.4,afade=t=out:st={DUR - 1.2}:d=1.2,atrim=0:{DUR}[m]",
      f"[1:a]apad,atrim=0:{DUR},asplit=2[v][sc]",
      "[m][sc]sidechaincompress=threshold=0.04:ratio=6:attack=20:release=350[md]"]
labels = ["[v]", "[md]"]
for i, (name, t, vol, trim) in enumerate(events):
    inputs += ["-i", f"{D}/sfx/{name}.mp3"]
    idx = 3 + i
    ms = int(t * 1000)
    fc.append(f"[{idx}:a]atrim=0:{trim},afade=t=out:st={trim * 0.6}:d={trim * 0.4},volume={vol * CFG.get("sfx_gain", 1.0):.3f},adelay={ms}|{ms},apad,atrim=0:{DUR}[s{i}]")
    labels.append(f"[s{i}]")
fc.append("".join(labels) + f"amix=inputs={len(labels)}:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5[a]")
cmd = ["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", ";".join(fc), "-map", "0:v", "-map", "[a]",
       "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", str(DUR), "-movflags", "+faststart", out]
subprocess.run(cmd, check=True)
print("mixed", len(events), "sfx")
