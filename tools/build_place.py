"""Baut LagerImperium.rbxlx aus den Skripten in src/ (ohne Rojo).

Aufruf:  python tools/build_place.py
Danach LagerImperium.rbxlx per Doppelklick in Roblox Studio öffnen.
"""
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# (Service, Ordner im Service, Quellordner)
LAYOUT = [
    ("ReplicatedStorage", "Shared", SRC / "shared"),
    ("ServerScriptService", "Server", SRC / "server"),
    ("StarterPlayer/StarterPlayerScripts", "Client", SRC / "client"),
]

ref_counter = 0


def ref():
    global ref_counter
    ref_counter += 1
    return f"RBX{ref_counter:08d}"


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(path):
    name = path.name
    if name.endswith(".server.luau"):
        cls, name = "Script", name[: -len(".server.luau")]
    elif name.endswith(".client.luau"):
        cls, name = "LocalScript", name[: -len(".client.luau")]
    else:
        cls, name = "ModuleScript", path.stem
    source = path.read_text(encoding="utf-8")
    return (
        f'<Item class="{cls}" referent="{ref()}"><Properties>'
        f'<string name="Name">{escape(name)}</string>'
        f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
        f"</Properties></Item>"
    )


def folder(name, inner):
    return (
        f'<Item class="Folder" referent="{ref()}"><Properties>'
        f'<string name="Name">{escape(name)}</string></Properties>{inner}</Item>'
    )


def service(cls, inner):
    return (
        f'<Item class="{cls}" referent="{ref()}"><Properties>'
        f'<string name="Name">{cls}</string></Properties>{inner}</Item>'
    )


def build():
    services = {}
    for svc_path, folder_name, src_dir in LAYOUT:
        scripts = "".join(script_item(p) for p in sorted(src_dir.glob("*.luau")))
        services.setdefault(svc_path, []).append(folder(folder_name, scripts))

    parts = []
    for svc_path, children in services.items():
        inner = "".join(children)
        segments = svc_path.split("/")
        for seg in reversed(segments):
            inner = service(seg, inner)
        parts.append(inner)

    xml = '<roblox version="4">' + "".join(parts) + "</roblox>"
    out = ROOT / "LagerImperium.rbxlx"
    out.write_text(xml, encoding="utf-8")
    print(f"Fertig: {out}")


if __name__ == "__main__":
    build()
