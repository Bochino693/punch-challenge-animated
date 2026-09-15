"""O LUTADOR DA ARENA, GERADO COMO UM .GLB DE VERDADE.

POR QUE UM ARQUIVO E NÃO CAIXAS MONTADAS NO GDSCRIPT. O personagem
precisava ser um GLB: é o formato que abre no Blender, no visualizador do
Windows e em qualquer ferramenta 3D, e é o que permite a quem opera o
jogo TROCAR o boneco sem tocar em uma linha de código — basta substituir
`assets/personagem/lutador.glb` por outro arquivo com os mesmos nomes de
peça. Um boneco montado em GDScript seria invisível fora do jogo e
impossível de editar sem programar.

POR QUE GERADO POR SCRIPT E NÃO MODELADO À MÃO. O mesmo motivo do banco
de áudio (`gerar_audio_arcade.py`): um modelo baixado é um problema de
licença multiplicado por cada gabinete vendido, e um modelo modelado à
mão não é reproduzível — se o arquivo se perder, ninguém refaz igual.
Este script é a fonte: apagar o .glb e rodar de novo devolve o mesmo
boneco, byte a byte.

POR QUE ARTICULADO EM CAIXAS E NÃO UMA MALHA COM ESQUELETO. Duas razões,
e as duas são de máquina:

  • O jogo vai para uma TV Box. Malha com esqueleto quer dizer skinning
    por vértice a cada quadro; caixas articuladas são vinte matrizes e
    240 triângulos, que qualquer GPU integrada desenha sem suar.
  • Uma boneca articulada — peças rígidas com juntas visíveis — é
    EXATAMENTE a linguagem dos jogos de luta de console antigo. Não é
    uma limitação disfarçada de estilo: é o estilo.

O jogo anima as peças pelo NOME (ver `scripts/arena/lutador.gd`). Se um
dia entrar aqui um GLB com esqueleto e AnimationPlayer, o jogo usa as
animações dele; se entrar um GLB qualquer sem nome nenhum reconhecido,
ele ainda balança o boneco inteiro. Nenhum dos três casos quebra a tela.

Uso: python3 tools/gerar_personagem_glb.py
"""

from pathlib import Path
import json
import struct

SAIDA = Path(__file__).resolve().parents[1] / "assets" / "personagem" / "lutador.glb"

# ----------------------------------------------------------------- tinta
#
# A PALETA VEM DA REFERÊNCIA QUE O OPERADOR MANDOU: lutador de anime,
# cabelo preto espetado, luva vermelha brilhante, calção preto com faixa
# vermelha e branca na lateral e cós preto grosso. As cores estão aqui em
# um lugar só porque é aqui que se troca o lutador de casa — um segundo
# personagem é esta tabela mais uma linha.
MATERIAIS = {
    "pele":     (0.91, 0.64, 0.44),
    "pele_esc": (0.74, 0.47, 0.30),
    "calcao":   (0.07, 0.07, 0.09),
    "faixa":    (0.86, 0.08, 0.14),
    "branco":   (0.96, 0.95, 0.94),
    "luva":     (0.88, 0.07, 0.13),
    "luva_esc": (0.52, 0.04, 0.08),
    "bota":     (0.07, 0.07, 0.09),
    "sola":     (0.92, 0.90, 0.86),
    "cabelo":   (0.07, 0.06, 0.08),
    "olho":     (0.97, 0.97, 0.97),
    "pupila":   (0.62, 0.06, 0.09),
    "boca":     (0.97, 0.95, 0.90),
    "cinto":    (0.10, 0.10, 0.12),
}

# --------------------------------------------------------------- o boneco
#
# CADA PEÇA É UMA CAIXA, e o que a torna um corpo e não um monte de
# caixas é a HIERARQUIA: girar o tronco leva a cabeça e os dois braços
# junto, girar o ombro leva antebraço e luva. É o que faz o recuo do
# golpe parecer um corpo levando o impacto em vez de peças voando.
#
#   nome      o jogo procura por este nome; mudar aqui é mudar lá
#   pai       de quem a peça pendura
#   t         posição LOCAL, a partir do pai
#   caixa     (largura, altura, profundidade) em metros
#   centro    deslocamento da caixa dentro da própria peça: é o que põe a
#             junta na PONTA do osso e não no meio dele
#   topo      afinamento do topo (1.0 = caixa reta, 0.8 = tronco de
#             pirâmide). É o que tira o ar de "Lego" sem custar um
#             triângulo a mais.
PECAS = [
    # tronco -------------------------------------------------------------
    ("Quadril",     None,        (0.0, 0.98, 0.0),    (0.38, 0.26, 0.27), (0, 0, 0),          1.00, "calcao"),
    ("Cos",         "Quadril",   (0.0, 0.15, 0.0),    (0.40, 0.11, 0.29), (0, 0, 0),          1.00, "cinto"),
    ("Listra_R_E",  "Quadril",   (-0.196, -0.02, 0.07),  (0.012, 0.24, 0.07), (0, 0, 0),      1.00, "faixa"),
    ("Listra_B_E",  "Quadril",   (-0.196, -0.02, -0.02), (0.012, 0.24, 0.045), (0, 0, 0),     1.00, "branco"),
    ("Listra_R_D",  "Quadril",   (0.196, -0.02, 0.07),   (0.012, 0.24, 0.07), (0, 0, 0),      1.00, "faixa"),
    ("Listra_B_D",  "Quadril",   (0.196, -0.02, -0.02),  (0.012, 0.24, 0.045), (0, 0, 0),     1.00, "branco"),
    ("Tronco",      "Quadril",   (0.0, 0.16, 0.0),    (0.36, 0.38, 0.25), (0, 0.18, 0),       1.28, "pele"),
    ("Abdomen",     "Tronco",    (0.0, 0.11, 0.105),  (0.21, 0.20, 0.05), (0, 0, 0),          1.00, "pele_esc"),
    ("Peito_E",     "Tronco",    (-0.10, 0.30, 0.10), (0.17, 0.13, 0.08), (0, 0, 0),          0.90, "pele_esc"),
    ("Peito_D",     "Tronco",    (0.10, 0.30, 0.10),  (0.17, 0.13, 0.08), (0, 0, 0),          0.90, "pele_esc"),
    ("Pescoco",     "Tronco",    (0.0, 0.36, 0.0),    (0.15, 0.10, 0.15), (0, 0.04, 0),       1.00, "pele_esc"),
    # cabeça -------------------------------------------------------------
    ("Cabeca",      "Pescoco",   (0.0, 0.08, 0.0),    (0.25, 0.28, 0.24), (0, 0.13, 0),       0.96, "pele"),
    ("Cabelo",      "Cabeca",    (0.0, 0.22, -0.01),  (0.27, 0.15, 0.26), (0, 0, 0),          0.88, "cabelo"),
    ("Franja",      "Cabeca",    (0.0, 0.205, 0.105), (0.25, 0.13, 0.06), (0, 0, 0),          1.00, "cabelo"),
    ("Costeleta_E", "Cabeca",    (-0.125, 0.13, -0.01), (0.03, 0.18, 0.23), (0, 0, 0),        1.00, "cabelo"),
    ("Costeleta_D", "Cabeca",    (0.125, 0.13, -0.01),  (0.03, 0.18, 0.23), (0, 0, 0),        1.00, "cabelo"),
    ("Espeto_1",    "Cabelo",    (-0.10, 0.06, 0.05),  (0.07, 0.20, 0.07), (0, 0.10, 0),      0.12, "cabelo"),
    ("Espeto_2",    "Cabelo",    (-0.04, 0.07, 0.09),  (0.06, 0.17, 0.06), (0, 0.09, 0),      0.12, "cabelo"),
    ("Espeto_3",    "Cabelo",    (0.03, 0.07, 0.08),   (0.07, 0.22, 0.07), (0, 0.11, 0),      0.12, "cabelo"),
    ("Espeto_4",    "Cabelo",    (0.10, 0.06, 0.03),   (0.06, 0.18, 0.06), (0, 0.09, 0),      0.12, "cabelo"),
    ("Espeto_5",    "Cabelo",    (-0.07, 0.06, -0.06), (0.06, 0.16, 0.06), (0, 0.08, 0),      0.12, "cabelo"),
    ("Espeto_6",    "Cabelo",    (0.06, 0.06, -0.07),  (0.06, 0.19, 0.06), (0, 0.10, 0),      0.12, "cabelo"),
    ("Espeto_7",    "Cabelo",    (0.0, 0.07, -0.01),   (0.06, 0.23, 0.06), (0, 0.12, 0),      0.12, "cabelo"),
    ("Olho_E",      "Cabeca",    (-0.065, 0.14, 0.115), (0.07, 0.06, 0.02), (0, 0, 0),        1.00, "olho"),
    ("Olho_D",      "Cabeca",    (0.065, 0.14, 0.115),  (0.07, 0.06, 0.02), (0, 0, 0),        1.00, "olho"),
    ("Pupila_E",    "Olho_E",    (0.008, 0.0, 0.014), (0.032, 0.042, 0.01), (0, 0, 0),        1.00, "pupila"),
    ("Pupila_D",    "Olho_D",    (-0.008, 0.0, 0.014), (0.032, 0.042, 0.01), (0, 0, 0),       1.00, "pupila"),
    ("Sobrancelha_E", "Cabeca",  (-0.068, 0.185, 0.118), (0.10, 0.028, 0.02), (0, 0, 0),      1.00, "cabelo"),
    ("Sobrancelha_D", "Cabeca",  (0.068, 0.185, 0.118),  (0.10, 0.028, 0.02), (0, 0, 0),      1.00, "cabelo"),
    ("Protetor",    "Cabeca",    (0.0, 0.035, 0.108), (0.11, 0.035, 0.03), (0, 0, 0),         1.00, "boca"),
    # braços -------------------------------------------------------------
    ("Ombro_E",     "Tronco",    (-0.25, 0.32, 0.0),  (0.18, 0.18, 0.19), (0, 0, 0),          1.00, "pele"),
    ("Braco_E",     "Ombro_E",   (0.0, -0.07, 0.0),   (0.14, 0.24, 0.15), (0, -0.12, 0),      1.00, "pele"),
    ("Antebraco_E", "Braco_E",   (0.0, -0.24, 0.0),   (0.12, 0.22, 0.14), (0, -0.11, 0),      1.00, "pele"),
    ("Punho_E",     "Antebraco_E", (0.0, -0.21, 0.0), (0.15, 0.05, 0.16), (0, 0, 0),          1.00, "branco"),
    ("Luva_E",      "Antebraco_E", (0.0, -0.24, 0.0), (0.21, 0.23, 0.23), (0, -0.10, 0.01),   0.86, "luva"),
    ("Costura_E",   "Luva_E",    (0.0, -0.10, 0.115), (0.19, 0.02, 0.02), (0, 0, 0),          1.00, "luva_esc"),
    ("Ombro_D",     "Tronco",    (0.25, 0.32, 0.0),   (0.18, 0.18, 0.19), (0, 0, 0),          1.00, "pele"),
    ("Braco_D",     "Ombro_D",   (0.0, -0.07, 0.0),   (0.14, 0.24, 0.15), (0, -0.12, 0),      1.00, "pele"),
    ("Antebraco_D", "Braco_D",   (0.0, -0.24, 0.0),   (0.12, 0.22, 0.14), (0, -0.11, 0),      1.00, "pele"),
    ("Punho_D",     "Antebraco_D", (0.0, -0.21, 0.0), (0.15, 0.05, 0.16), (0, 0, 0),          1.00, "branco"),
    ("Luva_D",      "Antebraco_D", (0.0, -0.24, 0.0), (0.21, 0.23, 0.23), (0, -0.10, 0.01),   0.86, "luva"),
    ("Costura_D",   "Luva_D",    (0.0, -0.10, 0.115), (0.19, 0.02, 0.02), (0, 0, 0),          1.00, "luva_esc"),
    # pernas -------------------------------------------------------------
    ("Coxa_E",      "Quadril",   (-0.125, -0.11, 0.0), (0.18, 0.34, 0.21), (0, -0.17, 0),     1.00, "pele"),
    ("Calcao_E",    "Coxa_E",    (0.0, -0.09, 0.0),   (0.21, 0.21, 0.24), (0, 0, 0),          1.00, "calcao"),
    ("Perna_R_E",   "Calcao_E",  (-0.108, 0.0, 0.06), (0.010, 0.20, 0.06), (0, 0, 0),         1.00, "faixa"),
    ("Perna_B_E",   "Calcao_E",  (-0.108, 0.0, -0.02), (0.010, 0.20, 0.04), (0, 0, 0),        1.00, "branco"),
    ("Canela_E",    "Coxa_E",    (0.0, -0.34, 0.0),   (0.15, 0.32, 0.17), (0, -0.16, 0),      1.00, "pele"),
    ("Bota_E",      "Canela_E",  (0.0, -0.32, 0.02),  (0.18, 0.15, 0.27), (0, -0.07, 0.03),   1.00, "bota"),
    ("Sola_E",      "Bota_E",    (0.0, -0.14, 0.03),  (0.19, 0.03, 0.28), (0, 0, 0),          1.00, "sola"),
    ("Coxa_D",      "Quadril",   (0.125, -0.11, 0.0), (0.18, 0.34, 0.21), (0, -0.17, 0),      1.00, "pele"),
    ("Calcao_D",    "Coxa_D",    (0.0, -0.09, 0.0),   (0.21, 0.21, 0.24), (0, 0, 0),          1.00, "calcao"),
    ("Perna_R_D",   "Calcao_D",  (0.108, 0.0, 0.06),  (0.010, 0.20, 0.06), (0, 0, 0),         1.00, "faixa"),
    ("Perna_B_D",   "Calcao_D",  (0.108, 0.0, -0.02), (0.010, 0.20, 0.04), (0, 0, 0),         1.00, "branco"),
    ("Canela_D",    "Coxa_D",    (0.0, -0.34, 0.0),   (0.15, 0.32, 0.17), (0, -0.16, 0),      1.00, "pele"),
    ("Bota_D",      "Canela_D",  (0.0, -0.32, 0.02),  (0.18, 0.15, 0.27), (0, -0.07, 0.03),   1.00, "bota"),
    ("Sola_D",      "Bota_D",    (0.0, -0.14, 0.03),  (0.19, 0.03, 0.28), (0, 0, 0),          1.00, "sola"),
]

# O BONECO NASCE DE GUARDA, e não de braços caídos.
#
# Um lutador de braços caídos é um boneco de vitrine: não promete soco
# nenhum. A guarda alta — cotovelos dobrados, luvas na altura do queixo,
# ombro esquerdo à frente — é o que faz a tela dizer "ele está esperando
# o seu soco" antes de qualquer texto aparecer. É também a pose da
# referência que veio do operador.
#
# Os espetos do cabelo estão aqui pelo mesmo motivo de economia: em vez
# de sete malhas diferentes, é a MESMA caixa afinada, virada para sete
# lados.
POSE = {
    # O COTOVELO DOBRA NO EIXO X, NÃO NO Z.
    #
    # Dobrando em Z o antebraço abre para o LADO e a luva vai parar na
    # altura do quadril, de braços abertos — foi o que a primeira versão
    # fez, e o boneco ficou com cara de espantalho. A dobra de um cotovelo
    # de boxe acontece no plano de frente: o antebraço sobe e vem para
    # frente, e é isso que põe a luva na altura do queixo.
    "Ombro_E":     (-0.35,  0.0,  0.30),
    "Ombro_D":     (-0.35,  0.0, -0.30),
    "Antebraco_E": (-2.70,  0.0, -0.22),
    "Antebraco_D": (-2.70,  0.0,  0.22),
    # A BASE ABRE, E UM PÉ VAI À FRENTE.
    #
    # Com as pernas quase juntas e o corpo torcido 0,26 rad, as duas
    # coxas se sobrepunham na silhueta e o lutador parecia ter uma perna
    # só. Base aberta e pé adiantado é a posição de quem aguenta um soco
    # — e, o que importa mais aqui, é a que se LÊ como duas pernas a três
    # metros de distância da máquina.
    # O SINAL DO Z ABRE OU FECHA A BASE, e estava fechando.
    #
    # A coxa esquerda fica em x negativo; girá-la em +Z empurra o joelho
    # para +X, ou seja, PARA DENTRO — as duas pernas se cruzavam e, de
    # frente, o lutador aparecia com uma perna só. Negativo na esquerda e
    # positivo na direita é o que abre a base.
    "Coxa_E":      ( 0.22,  0.0, -0.24),
    "Coxa_D":      (-0.20,  0.0,  0.22),
    "Canela_E":    (-0.22,  0.0,  0.0),
    "Canela_D":    ( 0.26,  0.0,  0.0),
    "Quadril":     ( 0.0,   0.17, 0.0),
    "Cabeca":      ( 0.06, -0.10, 0.0),
    "Sobrancelha_E": (0.0,  0.0, -0.42),
    "Sobrancelha_D": (0.0,  0.0,  0.42),
    "Espeto_1":    ( 0.20,  0.0,  0.75),
    "Espeto_2":    (-0.30,  0.0,  0.38),
    "Espeto_3":    (-0.42,  0.0, -0.20),
    "Espeto_4":    ( 0.15,  0.0, -0.70),
    "Espeto_5":    ( 0.55,  0.0,  0.45),
    "Espeto_6":    ( 0.60,  0.0, -0.35),
    "Espeto_7":    (-0.10,  0.0,  0.05),
}


def euler_para_quaternio(x: float, y: float, z: float):
    """Godot lê o quaternio do glTF; a pose é escrita em ângulos porque
    ângulo se lê e quaternio não. Ordem YXZ, a mesma do Godot."""
    import math
    cx, sx = math.cos(x * 0.5), math.sin(x * 0.5)
    cy, sy = math.cos(y * 0.5), math.sin(y * 0.5)
    cz, sz = math.cos(z * 0.5), math.sin(z * 0.5)
    # q = qy * qx * qz
    qx = sx * cy * cz + cx * sy * sz
    qy = cx * sy * cz - sx * cy * sz
    qz = cx * cy * sz - sx * sy * cz
    qw = cx * cy * cz + sx * sy * sz
    return [qx, qy, qz, qw]


def caixa(largura, altura, profundidade, centro, topo):
    """Vértices e índices de uma caixa (opcionalmente afinada no topo).

    24 vértices e não 8: cada face precisa da sua própria normal, senão
    a iluminação suaviza as quinas e a caixa vira um travesseiro."""
    hx, hy, hz = largura * 0.5, altura * 0.5, profundidade * 0.5
    cx, cy, cz = centro
    tx, tz = hx * topo, hz * topo
    # 8 cantos: 0-3 embaixo (y-), 4-7 em cima (y+)
    c = [
        (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy - hy, cz - hz), (cx - hx, cy - hy, cz - hz),
        (cx - tx, cy + hy, cz + tz), (cx + tx, cy + hy, cz + tz),
        (cx + tx, cy + hy, cz - tz), (cx - tx, cy + hy, cz - tz),
    ]
    faces = [
        (0, 1, 5, 4),  # frente  (+Z)
        (1, 2, 6, 5),  # direita (+X)
        (2, 3, 7, 6),  # costas  (-Z)
        (3, 0, 4, 7),  # esquerda(-X)
        (4, 5, 6, 7),  # topo    (+Y)
        (3, 2, 1, 0),  # base    (-Y)
    ]
    pos, nor, idx = [], [], []
    for face in faces:
        a, b, d = c[face[0]], c[face[1]], c[face[3]]
        u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
        v = (d[0] - a[0], d[1] - a[1], d[2] - a[2])
        n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
        comp = (n[0] ** 2 + n[1] ** 2 + n[2] ** 2) ** 0.5 or 1.0
        n = (n[0] / comp, n[1] / comp, n[2] / comp)
        base = len(pos)
        for canto in face:
            pos.append(c[canto])
            nor.append(n)
        idx += [base, base + 1, base + 2, base, base + 2, base + 3]
    return pos, nor, idx


class Buffer:
    """Acumula os bytes e devolve o índice do acessor de cada bloco."""

    def __init__(self):
        self.dados = bytearray()
        self.views = []
        self.acessores = []

    def _alinhar(self):
        while len(self.dados) % 4:
            self.dados.append(0)

    def vec3(self, valores):
        self._alinhar()
        inicio = len(self.dados)
        for v in valores:
            self.dados += struct.pack("<3f", *v)
        self.views.append({"buffer": 0, "byteOffset": inicio,
                           "byteLength": len(self.dados) - inicio, "target": 34962})
        eixos = list(zip(*valores))
        self.acessores.append({
            "bufferView": len(self.views) - 1, "componentType": 5126,
            "count": len(valores), "type": "VEC3",
            "min": [min(e) for e in eixos], "max": [max(e) for e in eixos],
        })
        return len(self.acessores) - 1

    def indices(self, valores):
        self._alinhar()
        inicio = len(self.dados)
        for v in valores:
            self.dados += struct.pack("<H", v)
        self._alinhar()
        self.views.append({"buffer": 0, "byteOffset": inicio,
                           "byteLength": len(valores) * 2, "target": 34963})
        self.acessores.append({
            "bufferView": len(self.views) - 1, "componentType": 5123,
            "count": len(valores), "type": "SCALAR",
        })
        return len(self.acessores) - 1


def montar() -> bytes:
    buf = Buffer()
    materiais, indice_material = [], {}
    for nome, cor in MATERIAIS.items():
        indice_material[nome] = len(materiais)
        materiais.append({
            "name": nome,
            "pbrMetallicRoughness": {
                "baseColorFactor": [cor[0], cor[1], cor[2], 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 0.72,
            },
        })

    malhas, nos, por_nome = [], [], {}
    for nome, pai, t, dims, centro, topo, material in PECAS:
        pos, nor, idx = caixa(dims[0], dims[1], dims[2], centro, topo)
        malhas.append({"name": nome, "primitives": [{
            "attributes": {"POSITION": buf.vec3(pos), "NORMAL": buf.vec3(nor)},
            "indices": buf.indices(idx),
            "material": indice_material[material],
        }]})
        no = {"name": nome, "mesh": len(malhas) - 1, "translation": list(t)}
        if nome in POSE:
            no["rotation"] = euler_para_quaternio(*POSE[nome])
        por_nome[nome] = len(nos)
        nos.append(no)
        if pai is not None:
            nos[por_nome[pai]].setdefault("children", []).append(len(nos) - 1)

    raiz = {"name": "Lutador", "children": [por_nome["Quadril"]]}
    nos.append(raiz)

    gltf = {
        "asset": {"version": "2.0", "generator": "Punch Challenge / gerar_personagem_glb.py"},
        "scene": 0,
        "scenes": [{"name": "Arena", "nodes": [len(nos) - 1]}],
        "nodes": nos,
        "meshes": malhas,
        "materials": materiais,
        "accessors": buf.acessores,
        "bufferViews": buf.views,
        "buffers": [{"byteLength": len(buf.dados)}],
    }

    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_bytes = bytes(buf.dados)
    bin_bytes += b"\x00" * ((4 - len(bin_bytes) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    saida = bytearray()
    saida += struct.pack("<III", 0x46546C67, 2, total)
    saida += struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    saida += struct.pack("<II", len(bin_bytes), 0x004E4942) + bin_bytes
    return bytes(saida)


if __name__ == "__main__":
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    SAIDA.write_bytes(montar())
    print("%s  (%d peças, %.1f KB)" % (SAIDA, len(PECAS), SAIDA.stat().st_size / 1024.0))
