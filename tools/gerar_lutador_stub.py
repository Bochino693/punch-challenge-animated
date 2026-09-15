"""STUB TEMPORÁRIO do lutador com esqueleto — só para desenvolvimento.

Gera um assets/personagem/lutador.glb mínimo PORÉM com o contrato real:
Skeleton3D + malha com skin + as 9 animações, para o novo
scripts/arena/lutador.gd e os testes serem escritos contra o formato
final. O personagem definitivo (tools/gerar_personagem_blender.py)
substitui este arquivo — e este script será apagado antes do commit.

Uso: "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/gerar_lutador_stub.py
"""

import bpy
import math
from pathlib import Path

SAIDA = Path(__file__).resolve().parents[1] / "assets" / "personagem" / "lutador.glb"

# (nome, pai, cabeça, cauda) em metros, Z para cima no Blender.
OSSOS = [
    ("root", None, (0, 0, 0.0), (0, 0, 0.10)),
    ("hips", "root", (0, 0, 0.95), (0, 0, 1.05)),
    ("spine", "hips", (0, 0, 1.05), (0, 0, 1.25)),
    ("chest", "spine", (0, 0, 1.25), (0, 0, 1.45)),
    ("neck", "chest", (0, 0, 1.50), (0, 0, 1.62)),
    ("head", "neck", (0, 0, 1.62), (0, 0, 1.85)),
    ("shoulder_l", "chest", (-0.10, 0, 1.48), (-0.22, 0, 1.48)),
    ("upperarm_l", "shoulder_l", (-0.22, 0, 1.48), (-0.30, 0, 1.22)),
    ("forearm_l", "upperarm_l", (-0.30, 0, 1.22), (-0.28, -0.05, 1.00)),
    ("hand_l", "forearm_l", (-0.28, -0.05, 1.00), (-0.26, -0.10, 0.90)),
    ("shoulder_r", "chest", (0.10, 0, 1.48), (0.22, 0, 1.48)),
    ("upperarm_r", "shoulder_r", (0.22, 0, 1.48), (0.30, 0, 1.22)),
    ("forearm_r", "upperarm_r", (0.30, 0, 1.22), (0.28, -0.05, 1.00)),
    ("hand_r", "forearm_r", (0.28, -0.05, 1.00), (0.26, -0.10, 0.90)),
    ("thigh_l", "hips", (-0.11, 0, 0.95), (-0.13, 0, 0.52)),
    ("shin_l", "thigh_l", (-0.13, 0, 0.52), (-0.14, -0.02, 0.10)),
    ("foot_l", "shin_l", (-0.14, -0.02, 0.10), (-0.14, -0.16, 0.03)),
    ("thigh_r", "hips", (0.11, 0, 0.95), (0.13, 0, 0.52)),
    ("shin_r", "thigh_r", (0.13, 0, 0.52), (0.14, -0.02, 0.10)),
    ("foot_r", "shin_r", (0.14, -0.02, 0.10), (0.14, -0.16, 0.03)),
]

# Faixas de altura da malha -> osso que manda nela.
FAIXAS = [
    (0.00, 0.15, "foot_l"),  # o stub não separa os pés; basta ter skin
    (0.15, 0.55, "shin_l"),
    (0.55, 1.00, "thigh_l"),
    (1.00, 1.10, "hips"),
    (1.10, 1.28, "spine"),
    (1.28, 1.50, "chest"),
    (1.50, 1.62, "neck"),
    (1.62, 2.00, "head"),
]

bpy.ops.wm.read_factory_settings(use_empty=True)

armadura = bpy.data.armatures.new("Esqueleto")
obj_arm = bpy.data.objects.new("Armature", armadura)
bpy.context.collection.objects.link(obj_arm)
bpy.context.view_layer.objects.active = obj_arm
bpy.ops.object.mode_set(mode="EDIT")
edit_bones = {}
for nome, pai, cabeca, cauda in OSSOS:
    osso = armadura.edit_bones.new(nome)
    osso.head = cabeca
    osso.tail = cauda
    edit_bones[nome] = osso
for nome, pai, _, _ in OSSOS:
    if pai:
        edit_bones[nome].parent = edit_bones[pai]
bpy.ops.object.mode_set(mode="OBJECT")

# Malha: um corpo de revolução simples (cilindro de 12 lados, 9 anéis).
verts, faces = [], []
lados, aneis = 12, 24
for a in range(aneis + 1):
    z = 1.85 * a / aneis
    raio = 0.34 if 0.9 < z < 1.5 else (0.20 if z >= 1.5 else 0.24)
    for s in range(lados):
        ang = 2.0 * math.pi * s / lados
        verts.append((raio * math.cos(ang), raio * math.sin(ang), z))
for a in range(aneis):
    for s in range(lados):
        s2 = (s + 1) % lados
        faces.append((a * lados + s, a * lados + s2, (a + 1) * lados + s2, (a + 1) * lados + s))
mesh = bpy.data.meshes.new("Corpo")
mesh.from_pydata(verts, [], faces)
mesh.update()
obj_corpo = bpy.data.objects.new("Corpo", mesh)
bpy.context.collection.objects.link(obj_corpo)

for nome, _, _, _ in OSSOS:
    obj_corpo.vertex_groups.new(name=nome)
for i, v in enumerate(mesh.vertices):
    for z0, z1, osso in FAIXAS:
        if z0 <= v.co.z < z1:
            obj_corpo.vertex_groups[osso].add([i], 1.0, "REPLACE")
            break

mod = obj_corpo.modifiers.new("Armature", "ARMATURE")
mod.object = obj_arm
obj_corpo.parent = obj_arm

# Raiz da cena com o nome que o jogo procura.
raiz = bpy.data.objects.new("Lutador", None)
bpy.context.collection.objects.link(raiz)
obj_arm.parent = raiz

# Animações: um movimento simples e distinto por nome, guardadas em
# trilhas NLA para o exportador gerar uma animação por nome.
obj_arm.animation_data_create()

def gravar(nome, duracao, mexer):
    acao = bpy.data.actions.new(nome)
    obj_arm.animation_data.action = acao
    for osso_nome, rot in mexer:
        pbone = obj_arm.pose.bones[osso_nome]
        pbone.rotation_mode = "XYZ"
        pbone.rotation_euler = (0, 0, 0)
        pbone.keyframe_insert("rotation_euler", frame=1)
        pbone.rotation_euler = rot
        pbone.keyframe_insert("rotation_euler", frame=max(2, int(duracao * 24 / 2)))
        pbone.rotation_euler = (0, 0, 0) if nome not in ("knockout",) else rot
        pbone.keyframe_insert("rotation_euler", frame=int(duracao * 24) + 1)
    trilha = obj_arm.animation_data.nla_tracks.new()
    trilha.name = nome
    faixa = trilha.strips.new(nome, 1, acao)
    faixa.name = nome
    obj_arm.animation_data.action = None

gravar("idle", 2.5, [("chest", (0.06, 0, 0))])
gravar("guard", 2.0, [("hips", (0, 0, 0.05)), ("chest", (0.05, 0, 0))])
gravar("taunt_weak", 1.4, [("head", (0, 0.3, 0)), ("forearm_l", (0, -0.6, 0))])
gravar("hit_light", 0.6, [("head", (-0.25, 0, 0)), ("chest", (-0.10, 0, 0))])
gravar("hit_medium", 0.8, [("chest", (-0.35, 0, 0.15)), ("head", (-0.3, 0, 0.2))])
gravar("hit_heavy", 1.0, [("chest", (-0.7, 0, 0.2)), ("hips", (-0.3, 0, 0)), ("head", (-0.5, 0, 0))])
gravar("stagger", 1.4, [("hips", (-0.2, 0, 0.35)), ("chest", (-0.4, 0, -0.3))])
gravar("knockout", 1.8, [("root", (-1.45, 0, 0)), ("chest", (-0.2, 0, 0)), ("shin_l", (0.3, 0, 0)), ("shin_r", (0.3, 0, 0))])
gravar("get_up", 1.6, [("root", (-1.45, 0, 0)), ("chest", (0.2, 0, 0))])

SAIDA.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(SAIDA),
    export_format="GLB",
    export_animation_mode="NLA_TRACKS",
    export_skins=True,
    export_yup=True,
)
print("STUB OK:", SAIDA)
