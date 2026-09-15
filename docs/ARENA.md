# A arena e o lutador

Esta é a única diferença entre `punch-challenge-animated` e
`punch-challenge`. O resto do jogo — sensor, ponte serial, câmera,
ranking, Central Técnica, exportação — é o mesmo código, e deve continuar
sendo: correção que entra num repositório precisa poder entrar no outro
sem tradução.

## O que mudou na tela do soco

Antes, o meio da tela do soco era um alvo desenhado (na espera) e um
medalhão redondo com o número (no resultado). Os dois ocupavam o mesmo
retângulo escuro que o fundo do jogo já reservava, e os dois eram
desenho 2D plano.

Agora esse retângulo é uma **janela 3D com moldura**: um ringue de
verdade, com câmera, luz e perspectiva, e um lutador dentro dele que
**recua na medida do soco** e vai à lona quando não aguenta mais.

    ┌──────────────────────────────────────┐
    │              PUNCH CHALLENGE         │
    │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │
    │ █┃  ADVERSÁRIO · ABALADO 46%    ┃█   │  ← as colunas de dano
    │ █┃ ┌──────────────────────────┐ ┃█   │
    │ █┃ │                          │ ┃█   │
    │ █┃ │    a arena em 3D         │ ┃█   │  ← o SubViewport
    │ █┃ │                          │ ┃█   │
    │ █┃ └──────────────────────────┘ ┃█   │
    │  ┗━━━━━━━┏━━━━━━━━━━━━┓━━━━━━━━━┛    │
    │          ┃    8420    ┃              │  ← a plaqueta do placar
    │          ┗━━━━━━━━━━━━┛              │
    │              NOCAUTE                 │
    │        DIRETO NO QUEIXO!             │  ← a frase
    │   ┌───────────┐  ┌───────────┐       │
    │   │  SOCO 1   │  │  SOCO 2   │       │
    └──────────────────────────────────────┘

As medidas moram todas em `ArenaQuadro` (`scripts/arena/quadro.gd`),
como constantes públicas, porque três coisas dependem delas: o desenho,
o tamanho da janela 3D (que precisa da mesma proporção, senão a imagem
chega esticada) e os testes.

## As peças

| arquivo | o que faz |
|---|---|
| `tools/gerar_personagem_glb.py` | gera o lutador em `.glb` do zero |
| `assets/personagem/lutador.glb` | o boneco, 56 peças, ~76 KB |
| `scripts/arena/arena3d.gd` | o mundo 3D dentro do `SubViewport` |
| `scripts/arena/lutador.gd` | a animação do corpo, por código |
| `scripts/arena/quadro.gd` | a moldura e as colunas de dano, em 2D |
| `scripts/arena/frases.gd` | o que a máquina grita a cada nível |
| `tools/gerar_audio_arena.py` | o baque no corpo, a queda e a plateia |
| `tests/test_arena.gd` | o que não pode voltar a quebrar |

## Trocar o lutador

O boneco é um `.glb` comum. Para pôr outro no lugar, basta substituir
`assets/personagem/lutador.glb`. O jogo aceita três casos e nenhum
derruba a máquina:

1. **O GLB tem as peças com os nomes de `Lutador3D.JUNTAS`**
   (`Quadril`, `Tronco`, `Cabeca`, `Ombro_E`, `Antebraco_D`, `Luva_E`…):
   animação completa — recuo, chicote da cabeça, guarda, queda.
2. **O GLB tem um `AnimationPlayer`** com animações chamadas `idle`,
   `guard`, `hit` ou `ko`: o jogo toca as do arquivo e não mexe nas
   peças. Quem modelou sabe melhor como o boneco se move.
3. **O GLB não tem nem uma coisa nem outra**: o corpo inteiro ainda
   recua, sacode e tomba, porque o nó raiz sempre existe.

E se o arquivo **não existir**, a arena vira um ringue vazio iluminado e
o jogo segue inteiro — placar, ranking, foto, tudo. Um gabinete no salão
não tem quem conserte às onze da noite.

Para refazer o boneco que vem no repositório:

```
python3 tools/gerar_personagem_glb.py
```

O script é a fonte: apagar o `.glb` e rodar de novo devolve o mesmo
boneco. A aparência (cabelo espetado preto, luva vermelha, calção preto
com faixa vermelha e branca) e as cores estão na tabela `MATERIAIS`, no
topo do arquivo; a montagem do corpo, em `PECAS`; a guarda, em `POSE`.

## O dano

Cada soco tira `forca × 0,62` do adversário (`Lutador3D.DANO_POR_GOLPE`),
onde `forca` é a pontuação sobre o teto da escala. Na prática:

- dois socos perfeitos derrubam;
- um soco leve quase não mexe no medidor (e abaixo de 2% não conta,
  senão o ruído do sensor encheria a barra sozinho ao longo da noite);
- os níveis com *hit-stop* na tabela do `ScoreTier` — NOCAUTE,
  PESO-PESADO, LENDÁRIO e SOCO PERFEITO — derrubam **no primeiro golpe**,
  independentemente do medidor.

Quem cai levanta sozinho em 2,6 s, com o medidor voltando a 72%: a
rodada tem dois socos, e o segundo precisa ter para onde ir.

**Cada rodada começa com o adversário inteiro.** Herdar o dano faria a
segunda pessoa da fila derrubar alguém que já estava caindo, e as
colunas laterais mentiriam sobre o que ela fez.

## O custo, que é o que interessa numa TV Box

Esta versão vai para o mesmo aparelho que a original, então a arena foi
construída para custar pouco, não para impressionar em benchmark:

- **uma malha só** para todo o ringue (lona, borda, quatro postes, nove
  cordas, fundo), com cor por vértice — um desenho em vez de trinta;
- **três luzes**, nenhuma com sombra;
- **os flashes da plateia num `MultiMesh`** — dezoito pontos, um desenho;
- **sem antisserrilhado, sem brilho, sem TAA**;
- **a janela encolhe e cai para 30 Hz** quando o vigia de desempenho
  aperta (`Desempenho.qualidade < 0,55`). A interface 2D continua a 60;
  num quadro de 800 pixels, metade da taxa no 3D não se vê;
- **a janela só desenha nas telas do soco.** Na abertura, na contagem,
  na tabela de recordes e na Central o mundo 3D não é calculado nenhuma
  vez (`main.gd::_arena_no_ar`).

Para medir na máquina de destino:

```
godot --path . --script tools/medir_arena.gd
```

Ele roda a mesma tela duas vezes, com e sem a janela 3D, e imprime a
diferença. Não use `--headless`: sem rasterizador o custo do 3D não
aparece. Num PC de desenvolvimento com vídeo por software (llvmpipe), a
arena custou **0,77 ms por quadro** — menos de 4% de um quadro que já
levava 21 ms só com o 2D. Com GPU de verdade a diferença é menor ainda.

## Conferir

```
godot --headless --path . --script tests/test_arena.gd
godot --path . --script tools/capturar_telas.gd   # PNG de cada tela
```

`tests/test_arena.gd` guarda, entre outras coisas, os dois erros que a
arena cometeu de verdade durante a construção:

- **o nocaute afundava o lutador.** A queda baixava o corpo 62 cm além
  de tombá-lo; como o nó raiz fica na altura da lona, o boneco saía por
  baixo do ringue e a moldura mostrava um ringue vazio no momento mais
  importante do jogo;
- **a janela 3D e o buraco da moldura tinham proporções diferentes**, e
  a imagem chegava esticada.

As capturas ficam em `.telas/` (ignorado pelo Git) e são o jeito mais
rápido de conferir a tela inteira sem montar o gabinete.
