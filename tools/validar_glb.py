"""Valida o contrato mínimo do lutador sem depender do Blender ou Godot."""

import json
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "assets/personagem/lutador.glb"
raw = path.read_bytes()
if raw[:4] != b"glTF" or len(raw) < 20:
    raise SystemExit("GLB_INVALIDO: cabeçalho glTF ausente")
_, version, total = struct.unpack_from("<4sII", raw, 0)
if version != 2 or total != len(raw):
    raise SystemExit("GLB_INVALIDO: versão/tamanho inconsistente")
chunk_len, chunk_type = struct.unpack_from("<II", raw, 12)
if chunk_type != 0x4E4F534A:
    raise SystemExit("GLB_INVALIDO: JSON principal ausente")
data = json.loads(raw[20:20 + chunk_len].decode("utf-8").rstrip(" \t\r\n\0"))

nodes = data.get("nodes", [])
meshes = data.get("meshes", [])
skins = data.get("skins", [])
animations = data.get("animations", [])
materials = data.get("materials", [])
names = {str(item.get("name", "")).lower() for item in animations}
required = {"idle", "guard", "taunt_weak", "hit_light", "hit_medium", "hit_heavy", "stagger", "knockout", "get_up"}
missing = sorted(name for name in required if not any(name in current for current in names))

print(f"GLB={path}")
print(f"NODES={len(nodes)} MESHES={len(meshes)} SKINS={len(skins)} ANIMATIONS={len(animations)} MATERIALS={len(materials)}")
if not meshes:
    raise SystemExit("GLB_INVALIDO: personagem sem mesh")
if missing:
    raise SystemExit("GLB_INVALIDO: animações ausentes: " + ", ".join(missing))
if not skins:
    print("RIG=articulado por nós (leve, sem skinning)")
print("GLB_HUMANOIDE_ANIMADO_OK")
