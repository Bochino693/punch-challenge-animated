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


if __name__ == "__main__":
    salvar("arena_corpo", corpo(), alvo_rms=0.17)
    salvar("arena_queda", queda(), alvo_rms=0.16)
    e, d = publico()
    salvar("arena_publico", e, d, alvo_rms=0.11)
    print("arena_corpo, arena_queda, arena_publico gerados")
