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
| `tools/gerar_personagem_blender.py` | gera o humanoide rigado, materiais e nove ações |
| `tools/gerar_personagem_glb.py` | gera o lutador articulado leve, também com nove ações |
| `GERAR_PERSONAGEM.bat` | atalho de dois cliques para o gerador Blender no Windows |
| `tools/gerar_personagem_windows.ps1` | encontra o Blender e executa o gerador no Windows |
| `assets/personagem/lutador.glb` | modelo carregado pelo jogo |
| `scripts/arena/arena3d.gd` | o mundo 3D dentro do `SubViewport` |
| `scripts/arena/lutador.gd` | integra AnimationPlayer, com ou sem Skeleton3D/skin |
| `scripts/arena/quadro.gd` | a moldura e as colunas de dano, em 2D |
| `scripts/arena/frases.gd` | o que a máquina grita a cada nível |
| `scripts/ranking_celebration.gd` | quatro cerimônias, conforme a colocação |
| `tools/gerar_audio_arena.py` | o baque no corpo, a queda e a plateia |
| `tests/test_arena.gd` | o que não pode voltar a quebrar |

## Trocar o lutador

O boneco é um `.glb` comum. Para pôr outro no lugar, basta substituir
`assets/personagem/lutador.glb`. O contrato recomendado é `Skeleton3D`,
mesh com skin e `AnimationPlayer`. O controlador reconhece nomes com
prefixos de exportadores e procura: `idle`, `guard`, `taunt_weak`,
`hit_light`, `hit_medium`, `hit_heavy`, `stagger`, `knockout` e `get_up`.
Um fallback de transformação da raiz mantém um GLB externo incompleto
visível, mas não substitui o contrato rigado.

E se o arquivo **não existir**, a arena vira um ringue vazio iluminado e
o jogo segue inteiro — placar, ranking, foto, tudo. Um gabinete no salão
não tem quem conserte às onze da noite.

Para gerar o humanoide no Windows, a partir da raiz do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gerar_personagem_windows.ps1
```

O resultado tem uma malha skinned, 24 ossos, guarda anatômica como pose
de repouso, bíceps e antebraços com volume, olhos completos, sobrancelhas,
boca, lábio e protetor bucal, cabelo em mechas, materiais PBR cartoon,
luvas vermelhas, shorts preto/vermelho/branco e nove ações.
O arquivo anterior fica em `lutador.glb.anterior` até a validação local.
Na **Central Técnica → Operação**, o indicador `HUMANOIDE BLENDER`
confirma que o jogo carregou de fato a versão rigada; `MODELO LEVE ATIVO`
significa que ainda está usando o GLB de segurança incluído no ZIP.

## Premiação e torcida

A colocação escolhe uma receita própria em `RankingCelebration`:

- **1º lugar:** selo de campeão, três canhões, chuva cheia e torcida longa;
- **2º–3º:** cerimônia de pódio, dois canhões e torcida própria;
- **4º–10º:** entrada no Top 10, um canhão e comemoração média;
- **11º–20º:** reconhecimento curto, sem fingir que foi recorde.

Os quatro sons são estéreo e combinam massa vocal, canto de arquibancada,
palmas, assobios e reverberação de ginásio. O confete é atualizado no lugar
e desenhado como uma fita de uma chamada, evitando a alocação e a
triangulação que faziam a chuva engasgar.

Abaixo de **6.000 pontos**, o adversário baixa a guarda, nega com a cabeça
e desdenha, acompanhado por vaias e assobios próprios. Com 6.000 ou mais
ele reconhece o golpe e reage fisicamente; caído na lona, nunca desdenha.

## O dano

Cada soco tira `forca × 0,62` do adversário (`Lutador3D.DANO_POR_GOLPE`),
onde `forca` é a posição da velocidade real dentro da faixa calibrada.
A nota continua usando o expoente competitivo, mas ele não achata a
animação: golpe físico médio parece médio, mesmo com pontuação difícil.
Na prática:

- dois socos perfeitos derrubam;
- um soco leve quase não mexe no medidor (e abaixo de 2% não conta,
  senão o ruído do sensor encheria a barra sozinho ao longo da noite);
- os níveis com *hit-stop* na tabela do `ScoreTier` — NOCAUTE,
  PESO-PESADO, LENDÁRIO e SOCO PERFEITO — derrubam **no primeiro golpe**,
  independentemente do medidor.

Quem cai permanece visível na lona e completa queda/levantamento em cerca
de 5 s, com o medidor voltando a 72%: a
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
- **flashes e silhuetas da plateia em `MultiMesh`** — dois desenhos, com
  reação proporcional à força;
- **dois emissores GPU reutilizados** para faíscas e poeira da lona;
- **sem antisserrilhado, sem brilho, sem TAA**;
- **a janela encolhe** quando o vigia de desempenho aperta
  (`Desempenho.qualidade < 0,55`), mas continua atualizando em todo quadro;
- **a janela só desenha nas telas da rodada.** Liga no 3–2–1, permanece
  até o resultado e desliga na abertura, na tabela e na Central
  (`main.gd::_arena_no_ar`).

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
