r"""Gera o boxeador humanoide rigado e animado do Punch Challenge.

Uso no Windows (Blender 4.2+):
  & "C:\Program Files\Blender Foundation\Blender 4.5\blender.exe" `
    --background --python tools\gerar_personagem_blender.py

O resultado e autocontido em assets/personagem/lutador.glb. O gerador usa
formas arredondadas, uma unica malha skinned, 24 ossos, materiais PBR leves e
nove acoes. Nao depende de addons.
"""

import bpy
import math
import warnings
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "personagem" / "lutador.glb"
FPS = 30

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS

# O Blender 5.2 ainda exige `use_nodes` para ativar o material por nós,
# mas já avisa que a propriedade sairá no 6.0. O aviso não representa
# falha e só confundia o diagnóstico real do gerador.
warnings.filterwarnings("ignore", message=".*Material.use_nodes.*", category=DeprecationWarning)


def material(name, color, roughness=0.55, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


SKIN = material("Pele", (0.66, 0.27, 0.12), 0.48)
SKIN_LIGHT = material("Pele_Luz", (0.82, 0.39, 0.18), 0.44)
RED = material("Luvas_Vermelho", (0.82, 0.012, 0.02), 0.26, 0.05)
RED_DARK = material("Vermelho_Escuro", (0.24, 0.005, 0.008), 0.38)
BLACK = material("Shorts_Preto", (0.012, 0.016, 0.025), 0.24, 0.08)
WHITE = material("Faixa_Branca", (0.92, 0.94, 0.96), 0.34)
HAIR = material("Cabelo", (0.006, 0.009, 0.018), 0.32)
BLUE = material("Detalhe_Azul", (0.0, 0.18, 0.78), 0.30, 0.08)
EYE_WHITE = material("Branco_dos_Olhos", (0.96, 0.91, 0.82), 0.28)
EYE = material("Pupilas", (0.035, 0.018, 0.012), 0.22)
MOUTH = material("Boca", (0.16, 0.012, 0.018), 0.38)
LIP = material("Labios", (0.42, 0.045, 0.035), 0.40)
TOOTH = material("Protetor_Bucal", (0.88, 0.92, 0.96), 0.30)


BONES = [
    ("root", None, (0, 0, 0.03), (0, 0, 0.18)),
    ("hips", "root", (0, 0, 0.78), (0, 0, 0.94)),
    ("spine", "hips", (0, 0, 0.94), (0, 0, 1.18)),
    ("chest", "spine", (0, 0, 1.18), (0, 0, 1.48)),
    ("neck", "chest", (0, 0, 1.48), (0, 0, 1.59)),
    ("head", "neck", (0, 0, 1.59), (0, 0, 1.82)),
    # A pose de repouso JÁ É A GUARDA: cotovelos junto ao tronco e luvas
    # na frente do rosto. Assim até um visualizador que não toque a action
    # `guard` mostra um boxeador, não um boneco de braços abertos.
    ("shoulder_l", "chest", (-0.08, 0, 1.43), (-0.29, -0.02, 1.42)),
    ("upperarm_l", "shoulder_l", (-0.29, -0.02, 1.42), (-0.46, -0.10, 1.18)),
    ("forearm_l", "upperarm_l", (-0.46, -0.10, 1.18), (-0.29, -0.25, 1.40)),
    ("hand_l", "forearm_l", (-0.29, -0.25, 1.40), (-0.22, -0.29, 1.50)),
    ("shoulder_r", "chest", (0.08, 0, 1.43), (0.29, -0.02, 1.42)),
    ("upperarm_r", "shoulder_r", (0.29, -0.02, 1.42), (0.46, -0.10, 1.18)),
    ("forearm_r", "upperarm_r", (0.46, -0.10, 1.18), (0.29, -0.25, 1.40)),
    ("hand_r", "forearm_r", (0.29, -0.25, 1.40), (0.22, -0.29, 1.50)),
    ("thigh_l", "hips", (-0.14, 0, 0.80), (-0.15, 0, 0.43)),
    ("shin_l", "thigh_l", (-0.15, 0, 0.43), (-0.16, 0, 0.10)),
    ("foot_l", "shin_l", (-0.16, 0, 0.10), (-0.16, -0.18, 0.04)),
    ("toe_l", "foot_l", (-0.16, -0.18, 0.04), (-0.16, -0.30, 0.04)),
    ("thigh_r", "hips", (0.14, 0, 0.80), (0.15, 0, 0.43)),
    ("shin_r", "thigh_r", (0.15, 0, 0.43), (0.16, 0, 0.10)),
    ("foot_r", "shin_r", (0.16, 0, 0.10), (0.16, -0.18, 0.04)),
    ("toe_r", "foot_r", (0.16, -0.18, 0.04), (0.16, -0.30, 0.04)),
    ("glove_l", "hand_l", (-0.22, -0.29, 1.50), (-0.20, -0.31, 1.59)),
    ("glove_r", "hand_r", (0.22, -0.29, 1.50), (0.20, -0.31, 1.59)),
]

arm_data = bpy.data.armatures.new("Esqueleto_Humanoide")
arm = bpy.data.objects.new("Armature", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
edit = {}
for name, parent, head, tail in BONES:
    bone = arm_data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    bone.roll = 0.0
    edit[name] = bone
for name, parent, _, _ in BONES:
    if parent:
        edit[name].parent = edit[parent]
bpy.ops.object.mode_set(mode="OBJECT")

parts = []


def finish_part(obj, name, mat, bone):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    parts.append(obj)
    return obj


def ellipsoid(name, loc, scale, mat, bone, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish_part(obj, name, mat, bone)


def segment(name, a, b, radius, mat, bone, vertices=20):
    a, b = Vector(a), Vector(b)
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=delta.length, location=(a + b) * 0.5)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.rotation_mode = "XYZ"
    return finish_part(obj, name, mat, bone)


def muscle(name, a, b, radius, mat, bone):
    """Volume orgânico acompanhando o osso, sem parecer um cano."""
    a, b = Vector(a), Vector(b)
    delta = b - a
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=(a + b) * 0.5)
    obj = bpy.context.object
    obj.scale = (radius * 1.10, radius * 0.92, delta.length * 0.55)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    obj.rotation_mode = "XYZ"
    return finish_part(obj, name, mat, bone)


def torus(name, loc, major, minor, mat, bone):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8, location=loc)
    return finish_part(bpy.context.object, name, mat, bone)


# Cabeça e rosto
ellipsoid("Cabeca", (0, -0.005, 1.70), (0.155, 0.13, 0.20), SKIN_LIGHT, "head", 28, 18)
ellipsoid("Mandibula", (0, -0.105, 1.64), (0.125, 0.065, 0.10), SKIN, "head", 20, 12)
ellipsoid("Nariz", (0, -0.137, 1.71), (0.035, 0.035, 0.055), SKIN_LIGHT, "head", 16, 10)
for x in (-0.056, 0.056):
    ellipsoid("Olho", (x, -0.130, 1.745), (0.041, 0.014, 0.030), EYE_WHITE, "head", 16, 10)
    ellipsoid("Pupila", (x, -0.144, 1.744), (0.014, 0.008, 0.017), EYE, "head", 12, 8)
    # Sobrancelha inclinada: expressão determinada, legível de longe.
    segment("Sobrancelha", (x - 0.035, -0.148, 1.790 + 0.010 * (-1 if x < 0 else 1)),
            (x + 0.035, -0.148, 1.790 - 0.010 * (-1 if x < 0 else 1)),
            0.009, HAIR, "head", 10)
for x in (-0.12, 0.12):
    ellipsoid("Orelha", (x, -0.002, 1.70), (0.027, 0.018, 0.048), SKIN, "head", 12, 8)
# Boca completa em três planos: abertura, lábio e protetor branco. A leve
# assimetria evita o rosto de manequim e reforça o estilo cartoon.
segment("Boca", (-0.060, -0.139, 1.635), (0.060, -0.139, 1.629), 0.011, MOUTH, "head", 12)
ellipsoid("Labio_Inferior", (0.004, -0.143, 1.614), (0.070, 0.012, 0.018), LIP, "head", 16, 8)
ellipsoid("Protetor_Bucal", (0.008, -0.151, 1.636), (0.047, 0.008, 0.010), TOOTH, "head", 14, 8)

# Cabelo em mechas cônicas, claramente não cúbico.
for i in range(15):
    ang = math.tau * i / 15.0
    x = math.cos(ang) * 0.105
    y = math.sin(ang) * 0.075 + 0.015
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.045, radius2=0.006, depth=0.18,
                                    location=(x, y, 1.875 + 0.025 * math.sin(ang * 2)))
    spike = bpy.context.object
    spike.rotation_euler = (0.18 * math.sin(ang), 0.24 * math.cos(ang), -ang * 0.08)
    finish_part(spike, "Cabelo", HAIR if i % 4 else BLUE, "head")

# Tronco musculoso, pescoço e abdômen.
segment("Pescoco", (0, 0, 1.45), (0, 0, 1.58), 0.105, SKIN, "neck")
ellipsoid("Peitoral", (0, 0, 1.30), (0.38, 0.22, 0.31), SKIN_LIGHT, "chest", 28, 18)
ellipsoid("Dorsal", (0, 0.075, 1.25), (0.34, 0.16, 0.30), SKIN, "chest", 24, 16)
ellipsoid("Abdomen", (0, -0.01, 1.01), (0.255, 0.17, 0.30), SKIN, "spine", 24, 16)
for x in (-0.075, 0.075):
    for z in (0.94, 1.06, 1.18):
        ellipsoid("Abdominal", (x, -0.155, z), (0.065, 0.035, 0.07), SKIN_LIGHT, "spine", 14, 10)

# Shorts em volumes contínuos com cós e faixas laterais.
ellipsoid("Shorts", (0, 0.005, 0.77), (0.32, 0.21, 0.22), BLACK, "hips", 24, 14)
torus("Cos", (0, 0, 0.88), 0.265, 0.035, RED_DARK, "hips")
for x in (-0.285, 0.285):
    segment("Faixa_Vermelha", (x, -0.20, 0.68), (x, -0.20, 0.86), 0.032, RED, "hips", 12)
    segment("Faixa_Branca", (x * 0.91, -0.205, 0.68), (x * 0.91, -0.205, 0.86), 0.018, WHITE, "hips", 10)

# Braços, deltoides, antebraços e luvas.
for side, sign in (("l", -1), ("r", 1)):
    shoulder = (0.30 * sign, -0.02, 1.41)
    elbow = (0.46 * sign, -0.10, 1.18)
    wrist = (0.29 * sign, -0.25, 1.40)
    ellipsoid("Deltoide", shoulder, (0.18, 0.17, 0.20), SKIN_LIGHT, f"upperarm_{side}", 22, 14)
    segment("Braco_Base", shoulder, elbow, 0.120, SKIN, f"upperarm_{side}")
    muscle("Biceps", shoulder, elbow, 0.160, SKIN_LIGHT, f"upperarm_{side}")
    ellipsoid("Cotovelo", elbow, (0.105, 0.10, 0.105), SKIN, f"forearm_{side}", 16, 10)
    segment("Antebraco_Base", elbow, wrist, 0.108, SKIN, f"forearm_{side}")
    muscle("Antebraco", elbow, wrist, 0.140, SKIN_LIGHT, f"forearm_{side}")
    ellipsoid("Luva", (0.21 * sign, -0.31, 1.54), (0.18, 0.17, 0.20), RED, f"glove_{side}", 26, 18)
    ellipsoid("Punho_Luva", (0.28 * sign, -0.26, 1.43), (0.115, 0.11, 0.11), RED_DARK, f"hand_{side}", 18, 12)
    ellipsoid("Polegar", (0.10 * sign, -0.37, 1.50), (0.072, 0.075, 0.105), RED_DARK, f"glove_{side}", 16, 10)

# Pernas atléticas e botas.
for side, sign in (("l", -1), ("r", 1)):
    hip = (0.14 * sign, 0, 0.77)
    knee = (0.15 * sign, 0, 0.43)
    ankle = (0.16 * sign, 0, 0.12)
    segment("Coxa", hip, knee, 0.145, SKIN, f"thigh_{side}", 22)
    ellipsoid("Joelho", knee, (0.125, 0.12, 0.13), SKIN_LIGHT, f"shin_{side}", 18, 12)
    segment("Canela", knee, ankle, 0.105, SKIN, f"shin_{side}", 20)
    ellipsoid("Bota", (0.16 * sign, -0.09, 0.12), (0.125, 0.19, 0.14), BLACK, f"foot_{side}", 20, 12)
    ellipsoid("Biqueira", (0.16 * sign, -0.22, 0.08), (0.13, 0.15, 0.085), RED_DARK, f"toe_{side}", 18, 10)
    torus("Cano_Bota", (0.16 * sign, 0, 0.22), 0.10, 0.025, RED, f"shin_{side}")

# Junta todas as partes em UMA malha skinned, mantendo materiais e grupos.
bpy.ops.object.select_all(action="DESELECT")
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "Boxeador_Humanoide"
body.parent = arm
modifier = body.modifiers.new("Armature", "ARMATURE")
modifier.object = arm

root = bpy.data.objects.new("Lutador", None)
bpy.context.collection.objects.link(root)
arm.parent = root


def reset_pose():
    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)


def pose(frame, rotations=None, locations=None):
    rotations = rotations or {}
    locations = locations or {}
    for name, value in rotations.items():
        arm.pose.bones[name].rotation_euler = value
    for name, value in locations.items():
        arm.pose.bones[name].location = value
    # Gravar a pose inteira impede que uma ação herde a última rotação da
    # ação anterior e garante que os últimos quadros realmente voltem à guarda.
    for bone in arm.pose.bones:
        bone.keyframe_insert("rotation_euler", frame=frame)
        bone.keyframe_insert("location", frame=frame)


def action(name, length, keys, loop=False):
    reset_pose()
    act = bpy.data.actions.new(name=name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for frame, rotations, locations in keys:
        reset_pose()
        pose(frame, rotations, locations)
    # Não percorremos `Action.fcurves`: esse acesso legado foi depreciado
    # pelo sistema de Actions em camadas do Blender 5.x. Os keyframes já
    # nascem em Bezier, e idle/guard são repetidos pelo AnimationPlayer do
    # jogo, então o modificador CYCLES não é necessário no GLB exportado.
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    strip.name = name
    strip.action_frame_end = length
    arm.animation_data.action = None


action("idle", 90, [
    (1, {"chest": (0.01, 0, 0), "hips": (0, 0, -0.025)}, {}),
    (45, {"chest": (-0.025, 0, 0), "hips": (0, 0, 0.025)}, {}),
    (90, {"chest": (0.01, 0, 0), "hips": (0, 0, -0.025)}, {}),
], True)
action("guard", 60, [
    (1, {"chest": (0.01, 0, 0), "head": (0.02, 0, 0)}, {}),
    (30, {"chest": (-0.030, 0, 0.018), "hips": (0.018, 0, 0),
          "upperarm_l": (-0.035, 0, -0.025), "forearm_l": (-0.025, 0, 0),
          "upperarm_r": (-0.035, 0, 0.025), "forearm_r": (-0.025, 0, 0)}, {}),
    (60, {"chest": (0.01, 0, 0), "head": (0.02, 0, 0)}, {}),
], True)
action("taunt_weak", 42, [
    (1, {"head": (0, 0, 0)}, {}),
    # Baixa uma luva, inclina o tronco e nega duas vezes com a cabeça.
    # A silhueta muda bastante mesmo vista de longe no gabinete.
    (10, {"head": (0.06, -0.34, -0.10), "chest": (0.05, 0, 0.10),
          "upperarm_l": (0.30, 0, 0.20), "forearm_l": (-0.80, 0, 0.10)}, {}),
    (20, {"head": (0.08, 0.31, 0.09), "chest": (0.03, 0, -0.07),
          "upperarm_l": (0.36, 0, 0.24), "forearm_l": (-0.92, 0, 0.12)}, {}),
    (30, {"head": (0.06, -0.24, -0.07), "chest": (0.04, 0, 0.08),
          "upperarm_l": (0.28, 0, 0.18), "forearm_l": (-0.72, 0, 0.08)}, {}),
    (42, {"head": (0, 0, 0)}, {}),
])
action("hit_light", 20, [(1, {}, {}), (7, {"head": (-0.22, 0.18, 0.16), "chest": (-0.08, 0, 0)}, {}), (20, {}, {})])
action("hit_medium", 27, [(1, {}, {}), (9, {"head": (-0.38, 0.28, 0.22), "chest": (-0.24, 0.12, 0)}, {}), (27, {}, {})])
action("hit_heavy", 34, [(1, {}, {}), (10, {"head": (-0.52, -0.30, -0.28), "chest": (-0.48, -0.18, 0.08), "hips": (-0.16, 0, 0)}, {"root": (0, 0.10, 0)}), (34, {}, {})])
action("stagger", 46, [(1, {}, {}), (12, {"chest": (-0.58, 0.22, -0.16), "hips": (-0.26, 0, 0.22)}, {"root": (0.10, 0.18, 0)}), (28, {"chest": (-0.20, -0.18, 0.15)}, {"root": (-0.06, 0.10, 0)}), (46, {}, {})])
action("knockout", 58, [(1, {}, {}), (12, {"head": (-0.62, 0.30, 0.26), "chest": (-0.58, 0, 0.15)}, {"root": (0, 0.16, 0)}), (38, {"root": (-1.38, 0, 0.10), "thigh_l": (0.25, 0, 0), "thigh_r": (-0.18, 0, 0)}, {"root": (0, 0.28, 0)}), (58, {"root": (-1.48, 0, 0.10), "thigh_l": (0.30, 0, 0), "thigh_r": (-0.22, 0, 0)}, {"root": (0, 0.30, 0)})])
action("get_up", 50, [(1, {"root": (-1.48, 0, 0.10)}, {"root": (0, 0.30, 0)}), (22, {"root": (-0.75, 0, 0), "chest": (0.35, 0, 0)}, {"root": (0, 0.12, 0)}), (50, {}, {})])

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.context.view_layer.objects.active = root
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
arm.select_set(True)
body.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    use_selection=True,
    export_skins=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_yup=True,
    export_apply=True,
)
print("PERSONAGEM_GERADO", OUTPUT)
print("OSSOS", len(BONES), "ANIMACOES", 9, "MALHAS", 1)
