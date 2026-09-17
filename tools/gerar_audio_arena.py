"""OS SONS QUE A ARENA TROUXE: corpo, queda e plateia.

POR QUE NÃO BASTAVAM OS SONS QUE JÁ EXISTIAM. O banco original tem o
`hit` (o couro estalando), o `subgrave` (o peso no peito) e os oito sons
de nível. Os três descrevem o SOCO — nenhum descreve quem leva. Com um
lutador na tela recuando, o ouvido continuava ouvindo saco de areia, e é
exatamente aí que a cena desmonta: o olho vê um corpo, o ouvido ouve um
objeto.

    arena_corpo    o baque abafado no tronco. Grave curto, sem estalo
                   agudo: é o oposto do `hit`, que é todo transiente.
                   Os dois tocam JUNTOS no golpe — um é a luva, o outro
                   é a costela.
    arena_queda    o corpo encontrando a lona. Um estrondo largo, com a
                   madeira do estrado ressoando embaixo.
    arena_publico  o ginásio de pé. Ruído filtrado subindo e descendo,
                   que é o que uma multidão é acusticamente; sem isso o
                   nocaute acontece no silêncio.

Este arquivo reaproveita a mesa de `gerar_audio_arcade.py` de propósito:
dois bancos com dois conjuntos de ferramentas de DSP acabariam com dois
volumes, duas saturações e dois "sons da casa" diferentes.

Uso: python3 tools/gerar_audio_arena.py
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar_audio_arcade import (  # noqa: E402
    RATE, biquad, env_ad, n_amostras, reverb, ruido, salvar, satura,
    senoide, somar, tempo, varredura,
)


def corpo() -> np.ndarray:
    """O BAQUE NO TRONCO.

    A receita é a de um soco de cinema: um grave que despenca (o peso),
    um estalo curtíssimo e SURDO (o ar saindo), e nada de agudo. Todo o
    brilho fica por conta do `hit`, que toca junto — se os dois tivessem
    transiente agudo, o golpe soaria dobrado em vez de encorpado.
    """
    d = 0.55
    grave = varredura(148.0, 41.0, d, curva=2.6) * env_ad(d, 0.002, 0.34, 2.2)
    peito = senoide(78.0, d) * env_ad(d, 0.004, 0.22, 3.0) * 0.6
    # O "uf": ruído passado num passa-baixas bem fechado. É o ar deixando
    # o pulmão, e é o que separa "bateu numa parede" de "bateu em alguém".
    ar = biquad(ruido(d), 420.0, 0.8, "lp") * env_ad(d, 0.008, 0.18, 2.4) * 0.5
    couro = biquad(ruido(0.06), 1800.0, 1.1, "bp") * env_ad(0.06, 0.001, 0.05, 4.0) * 0.35
    saida = np.zeros(n_amostras(d))
    somar(saida, grave, 0, 1.0)
    somar(saida, peito, 0, 1.0)
    somar(saida, ar, 0, 1.0)
    somar(saida, couro, 0, 1.0)
    return satura(saida, 2.2)


def queda() -> np.ndarray:
    """O CORPO NA LONA.

    Duas coisas soam ao mesmo tempo quando alguém cai num ringue: o
    corpo (grave, curto) e o ESTRADO (madeira ressoando, longa). A
    segunda é a que dá tamanho — sem ela a queda tem o mesmo peso de um
    livro caindo na mesa.
    """
    d = 1.5
    baque = varredura(120.0, 33.0, 0.7, curva=3.2) * env_ad(0.7, 0.002, 0.5, 2.0)
    estrado = np.zeros(n_amostras(d))
    for freq, ganho, queda_t in ((62.0, 1.0, 1.1), (97.0, 0.55, 0.85), (151.0, 0.3, 0.6)):
        estrado += senoide(freq, d) * env_ad(d, 0.004, queda_t, 2.4) * ganho
    poeira = biquad(ruido(0.35), 900.0, 0.7, "lp") * env_ad(0.35, 0.004, 0.3, 2.0) * 0.4
    saida = np.zeros(n_amostras(d))
    somar(saida, baque, 0, 1.1)
    somar(saida, estrado * 0.45, n_amostras(0.012), 1.0)
    somar(saida, poeira, 0, 1.0)
    # Uma sala grande em volta: a queda é o único som do jogo que
    # precisa soar LONGE, porque é o momento em que a câmera se afasta.
    return satura(reverb(saida, tamanho=0.72, mistura=0.30), 1.8)


def publico() -> np.ndarray:
    """O GINÁSIO DE PÉ.

    Multidão, acusticamente, é ruído rosa com formantes por volta de
    500 Hz a 2 kHz e uma modulação lenta e irregular por cima — nunca um
    "aaah" afinado. A onda de aplauso entra depois do grito, porque é
    assim que acontece: primeiro o susto, depois a mão.
    """
    d = 2.6
    t = tempo(d)
    base = ruido(d)
    vozes = biquad(base, 850.0, 0.55, "bp") * 1.0 + biquad(base, 1750.0, 0.9, "bp") * 0.55
    # A onda: sobe rápido, se sustenta, desce devagar.
    onda = np.clip(1.6 * (1.0 - np.exp(-t * 7.0)) * np.exp(-np.maximum(0.0, t - 0.9) * 1.25), 0.0, 1.6)
    # Irregularidade: sem ela o ruído soa como chuveiro, não como gente.
    tremor = 1.0 + 0.22 * np.sin(2 * np.pi * 3.7 * t) + 0.14 * np.sin(2 * np.pi * 1.3 * t + 1.1)
    grito = vozes * onda * tremor

    palmas = np.zeros(n_amostras(d))
    rng = np.random.default_rng(4471)
    # Setenta palmas espalhadas, cada uma um estalo de 12 ms. Setenta e
    # não setecentas: o ouvido preenche o resto, e setecentas custariam
    # meio minuto de geração para soar igual.
    for _ in range(70):
        quando = n_amostras(float(rng.uniform(0.35, d - 0.2)))
        estalo = biquad(ruido(0.012), float(rng.uniform(1600.0, 3400.0)), 1.4, "bp")
        estalo *= env_ad(0.012, 0.0005, 0.010, 3.0)
        somar(palmas, estalo, quando, float(rng.uniform(0.25, 0.75)))
    palmas *= np.clip((t - 0.3) * 1.4, 0.0, 1.0) * np.exp(-np.maximum(0.0, t - 1.4) * 0.9)

    misto = grito * 0.75 + palmas * 0.9
    # Estéreo de verdade: a plateia é o único som do jogo que tem de
    # parecer vir de TODOS os lados, e dois ruídos independentes fazem
    # isso melhor que qualquer atraso.
    outro = biquad(ruido(d), 1150.0, 0.6, "bp") * onda * tremor * 0.55
    esquerda = misto + outro * 0.4
    direita = misto * 0.92 + outro * 0.7
    return reverb(esquerda, 0.8, 0.22), reverb(direita, 0.8, 0.22)


def torcida_estadio(d: float, intensidade: float, seed: int):
    """Torcida de estádio para a cerimônia do ranking.

    Combina massa vocal, canto grave, palmas, assobios e a cauda longa do
    ginásio. As quatro colocações usam durações e densidades diferentes;
    não são o mesmo WAV apenas tocado mais baixo.
    """
    t = tempo(d)
    rng = np.random.default_rng(seed)
    entrada = np.clip((1.0 - np.exp(-t * (9.0 + intensidade * 3.0))), 0.0, 1.0)
    saida = np.exp(-np.maximum(0.0, t - d * 0.68) * (1.0 + 0.45 / intensidade))
    onda = entrada * saida

    # Milhares de vozes viram bandas largas; duas fontes independentes
    # dão largura real, sem copiar o mesmo ruído nos dois canais.
    massa_l = (
        biquad(ruido(d), 620.0, 0.45, "bp")
        + biquad(ruido(d), 1280.0, 0.65, "bp") * 0.72
        + biquad(ruido(d), 2350.0, 0.90, "bp") * 0.32
    )
    massa_r = (
        biquad(ruido(d), 710.0, 0.48, "bp")
        + biquad(ruido(d), 1460.0, 0.70, "bp") * 0.68
        + biquad(ruido(d), 2700.0, 1.00, "bp") * 0.28
    )
    modulacao = 1.0 + 0.16 * np.sin(2 * np.pi * 2.7 * t) + 0.10 * np.sin(2 * np.pi * 4.3 * t + 0.8)
    esquerda = massa_l * onda * modulacao * (0.55 + intensidade * 0.28)
    direita = massa_r * onda * np.roll(modulacao, 117) * (0.55 + intensidade * 0.28)

    # Canto coletivo "ô-ô": não forma uma palavra, mas dá à massa a
    # identidade de arquibancada que ruído filtrado sozinho não possui.
    pulso = np.power(np.clip(np.sin(2 * np.pi * 1.65 * t), 0.0, 1.0), 0.55)
    canto = np.zeros(n_amostras(d))
    for _ in range(18 + int(22 * intensidade)):
        fundamental = float(rng.uniform(145.0, 235.0))
        fase = float(rng.uniform(0.0, np.pi * 2.0))
        voz = np.sin(2 * np.pi * fundamental * t + fase)
        voz += 0.38 * np.sin(2 * np.pi * fundamental * 2.02 * t + fase * 0.7)
        canto += voz * float(rng.uniform(0.018, 0.040))
    canto *= onda * (0.35 + pulso * 0.65) * intensidade
    esquerda += canto * 0.78
    direita += np.roll(canto, 71) * 0.74

    # Palmas densas e curtas. A posição estéreo de cada grupo varia.
    palmas_l = np.zeros(n_amostras(d))
    palmas_r = np.zeros(n_amostras(d))
    total_palmas = int((85.0 + d * 52.0) * intensidade)
    for _ in range(total_palmas):
        quando = n_amostras(float(rng.uniform(0.18, max(0.19, d - 0.08))))
        estalo = biquad(ruido(0.014), float(rng.uniform(1700.0, 3900.0)), 1.25, "bp")
        estalo *= env_ad(0.014, 0.0004, 0.012, 2.8)
        panorama = float(rng.uniform(0.08, 0.92))
        ganho = float(rng.uniform(0.20, 0.62))
        somar(palmas_l, estalo, quando, ganho * (1.0 - panorama))
        somar(palmas_r, estalo, quando, ganho * panorama)
    esquerda += palmas_l * onda
    direita += palmas_r * onda

    # Assobios aparecem apenas nas festas maiores e sobem como grito de gol.
    for _ in range(int(2 + intensidade * 5)):
        inicio = float(rng.uniform(0.12, max(0.13, d * 0.56)))
        dur = float(rng.uniform(0.28, 0.72))
        apito = varredura(float(rng.uniform(1700.0, 2400.0)), float(rng.uniform(2500.0, 3600.0)), dur, 1.2)
        apito *= env_ad(dur, 0.025, dur * 0.82, 1.5) * 0.055 * intensidade
        pos = n_amostras(inicio)
        if rng.random() < 0.5:
            somar(esquerda, apito, pos, 1.0)
            somar(direita, apito, pos, 0.28)
        else:
            somar(esquerda, apito, pos, 0.28)
            somar(direita, apito, pos, 1.0)

    return (
        satura(reverb(esquerda, tamanho=0.90, mistura=0.30), 1.35),
        satura(reverb(direita, tamanho=0.90, mistura=0.30), 1.35),
    )


def torcida_desdenho():
    """Murmúrio, vaias curtas e assobios descendentes para golpe fraco."""
    d = 2.15
    t = tempo(d)
    rng = np.random.default_rng(606)
    env = np.clip(t * 9.0, 0.0, 1.0) * np.exp(-np.maximum(0.0, t - 0.72) * 1.35)
    massa_l = biquad(ruido(d), 720.0, 0.55, "bp") * env * 0.50
    massa_r = biquad(ruido(d), 890.0, 0.62, "bp") * env * 0.47
    # Pulsos graves imitam o "ôôô" de desaprovação sem sintetizar fala.
    vaias = np.zeros(n_amostras(d))
    for freq in (132.0, 151.0, 178.0, 204.0):
        fase = float(rng.uniform(0.0, np.pi * 2.0))
        vaias += np.sin(2 * np.pi * freq * t + fase) * 0.055
    vaias *= env * (0.72 + 0.28 * np.sin(2 * np.pi * 3.1 * t))
    massa_l += vaias
    massa_r += np.roll(vaias, 83) * 0.92
    for i in range(4):
        inicio = 0.18 + i * 0.31 + float(rng.uniform(-0.05, 0.05))
        dur = 0.34
        apito = varredura(float(rng.uniform(2700.0, 3400.0)), float(rng.uniform(1500.0, 2100.0)), dur, 1.1)
        apito *= env_ad(dur, 0.018, 0.28, 1.8) * 0.05
        if i % 2 == 0:
            somar(massa_l, apito, n_amostras(inicio), 1.0)
            somar(massa_r, apito, n_amostras(inicio), 0.24)
        else:
            somar(massa_l, apito, n_amostras(inicio), 0.24)
            somar(massa_r, apito, n_amostras(inicio), 1.0)
    return reverb(massa_l, 0.84, 0.26), reverb(massa_r, 0.84, 0.26)


if __name__ == "__main__":
    salvar("arena_corpo", corpo(), alvo_rms=0.17)
    salvar("arena_queda", queda(), alvo_rms=0.16)
    e, d = publico()
    salvar("arena_publico", e, d, alvo_rms=0.11)
    # Reação exclusiva do golpe abaixo de 6.000; não compartilha o áudio
    # de comemoração para não premiar visualmente um golpe fraco.
    e, d = torcida_desdenho()
    salvar("torcida_desdenho", e, d, alvo_rms=0.105)
    for nome, duracao, intensidade, seed in (
        ("torcida_recorde", 5.4, 1.00, 101),
        ("torcida_podio", 4.4, 0.82, 202),
        ("torcida_top10", 3.5, 0.62, 303),
        ("torcida_top20", 2.7, 0.44, 404),
    ):
        e, d = torcida_estadio(duracao, intensidade, seed)
        salvar(nome, e, d, alvo_rms=0.13 if intensidade >= 0.8 else 0.11)
    print("arena, desdenho e quatro torcidas de ranking gerados")
