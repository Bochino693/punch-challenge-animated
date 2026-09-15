class_name Lutador3D
extends Node3D

## O LUTADOR QUE LEVA O SOCO.
##
## Esta é a peça que muda o jogo da versão original para esta: antes o
## soco batia num alvo desenhado e virava número; agora ele bate em
## ALGUÉM, e é o corpo desse alguém que conta o quanto o golpe valeu,
## antes de o placar terminar de subir.
##
## O CORPO É UM .GLB, E A ANIMAÇÃO É CÓDIGO. Não há arquivo de animação:
## o boneco vem em peças nomeadas (`Quadril`, `Tronco`, `Cabeca`,
## `Ombro_E`…) e quem as move é este script. A escolha é de máquina e de
## manutenção ao mesmo tempo:
##
##   • numa TV Box, animar vinte transformações por código custa menos
##     que interpolar trilhas de animação e muito menos que deformar uma
##     malha com esqueleto;
##   • uma reação por código pode responder à FORÇA do soco de verdade —
##     um golpe de 1200 pontos e um de 9800 não são a mesma animação com
##     velocidade diferente, são recuos de tamanhos diferentes. Com
##     trilhas gravadas seriam oito animações quase iguais, que é como
##     dois níveis acabam parecendo o mesmo.
##
## TROCAR O LUTADOR NÃO EXIGE PROGRAMAR. Basta substituir
## `assets/personagem/lutador.glb`. Três casos, e nenhum quebra a tela:
##
##   1. o GLB tem as peças com os nomes desta lista → animação completa;
##   2. o GLB tem um AnimationPlayer com "idle"/"hit"/"ko" → o jogo toca
##      as animações do arquivo e não mexe nas peças;
##   3. o GLB não tem nem uma coisa nem outra → o corpo inteiro ainda
##      recua, sacode e cai, porque o nó raiz sempre existe.

## As peças que o script procura. Faltar uma não é erro: o que existe é
## animado, o que não existe é ignorado.
const JUNTAS := [
	"Quadril", "Tronco", "Cabeca", "Pescoco",
	"Ombro_E", "Ombro_D", "Antebraco_E", "Antebraco_D",
	"Luva_E", "Luva_D", "Coxa_E", "Coxa_D", "Canela_E", "Canela_D",
]

## Quanto de dano um soco máximo causa. Dois golpes perfeitos derrubam;
## um golpe leve quase não mexe no medidor. É o que faz as barras
## laterais contarem uma história ao longo da rodada em vez de piscarem
## um valor solto por soco.
const DANO_POR_GOLPE := 0.62
## Abaixo disto o golpe não conta como dano de verdade — é um tapa.
const DANO_MINIMO := 0.02

var _juntas: Dictionary = {}     ## nome -> Node3D
var _repouso: Dictionary = {}    ## nome -> Transform3D de origem
var _raiz: Node3D = null
var _animador: AnimationPlayer = null

var _relogio := 0.0
## Recuo do golpe: cai de 1 a 0 e leva o corpo inteiro junto.
var _recuo := 0.0
var _forca_do_recuo := 0.0
## O tranco lateral, sorteado por golpe, para dois socos iguais não
## produzirem exatamente o mesmo movimento.
var _lado := 1.0
var _tremor := 0.0

## 0 = de pé; 1 = na lona. Sobe rápido e desce devagar: cair é queda,
## levantar é esforço.
var queda := 0.0
var _caindo := false
var _tempo_na_lona := 0.0

## Quanto o lutador já apanhou nesta rodada, de 0 a 1. É o número que as
## barras laterais mostram.
var dano := 0.0
## Guarda alta e saltitando: o estado de quem está esperando o soco.
var em_guarda := false

func montar(corpo: Node3D) -> void:
	_raiz = corpo
	add_child(corpo)
	_animador = _achar_animador(corpo)
	for nome in JUNTAS:
		var no := corpo.find_child(nome, true, false)
		if no is Node3D:
			_juntas[nome] = no
			_repouso[nome] = (no as Node3D).transform
	_repouso["__raiz__"] = corpo.transform

func _achar_animador(no: Node) -> AnimationPlayer:
	if no is AnimationPlayer:
		return no
	for filho in no.get_children():
		var achado := _achar_animador(filho)
		if achado != null:
			return achado
	return null

## Um GLB de fora pode trazer as próprias animações. Se trouxer, são elas
## que mandam — quem modelou o boneco sabe como ele se move melhor do que
## esta tabela de ângulos sabe.
func _tocar(nome: String) -> bool:
	if _animador == null or not _animador.has_animation(nome):
		return false
	_animador.play(nome)
	return true

## Nova rodada: de pé, sem dano, de guarda.
func preparar() -> void:
	dano = 0.0
	queda = 0.0
	_caindo = false
	_recuo = 0.0
	_tremor = 0.0
	_tempo_na_lona = 0.0
	em_guarda = false
	_tocar("idle")

func guardar(ativo: bool) -> void:
	em_guarda = ativo
	if ativo:
		_tocar("guard")

## O SOCO CHEGOU. `forca` é 0..1 (a pontuação sobre o teto da escala) e
## `derruba` diz se o nível é dos que põem alguém na lona por si só.
##
## Devolve o que aconteceu, porque quem chamou precisa saber se houve
## nocaute para escolher a frase e o som — e não pode descobrir isso
## lendo um campo no quadro seguinte, quando o som já teria atrasado.
func bater(forca: float, derruba := false) -> Dictionary:
	var f := clampf(forca, 0.0, 1.0)
	_recuo = 1.0
	_forca_do_recuo = f
	_tremor = f
	_lado = 1.0 if randf() < 0.5 else -1.0
	var antes := dano
	if f > DANO_MINIMO:
		dano = clampf(dano + f * DANO_POR_GOLPE, 0.0, 1.0)
	var nocaute := not _caindo and (derruba or (dano >= 1.0 and antes < 1.0))
	if nocaute:
		_caindo = true
		_tempo_na_lona = 0.0
		if not _tocar("ko"):
			pass
	elif not _caindo:
		_tocar("hit")
	return {"nocaute": nocaute, "dano": dano}

func atualizar(delta: float) -> void:
	_relogio += delta
	_recuo = maxf(0.0, _recuo - delta * 1.9)
	_tremor = maxf(0.0, _tremor - delta * 2.6)
	if _caindo:
		# CAIR É RÁPIDO, LEVANTAR É DEVAGAR. Os dois na mesma velocidade
		# fariam a queda parecer um boneco sendo deitado com a mão.
		queda = minf(1.0, queda + delta * 3.4)
		_tempo_na_lona += delta
		if _tempo_na_lona > 2.6:
			_caindo = false
	else:
		queda = maxf(0.0, queda - delta * 1.25)
		if queda <= 0.0 and dano >= 1.0:
			# Levantou: o juiz deu a contagem e ele voltou. O dano cede um
			# pouco para o segundo soco da rodada ainda ter para onde ir.
			dano = 0.72
	if _animador != null and _animador.is_playing():
		# O arquivo está mandando. Só o tranco da tela continua nosso.
		return
	_pose()

func _pose() -> void:
	if _raiz == null:
		return
	var t := _relogio
	# O RESPIRO. Um corpo parado de verdade não fica parado: sobe e desce
	# devagar. Sem isto o lutador lê como estátua, e estátua não apanha.
	var respiro := sin(t * 1.9) * 0.012
	var salto := 0.0
	if em_guarda:
		# De guarda ele SALTITA, no compasso de quem espera o golpe.
		salto = absf(sin(t * 4.6)) * 0.055
	var recuo := ease(_recuo, 0.35)
	var derrubado := ease(queda, 0.6)

	# O corpo inteiro: recua para o fundo da arena no golpe e tomba na
	# queda. É esta transformação que dá o peso — as juntas só temperam.
	var raiz := Transform3D(_repouso["__raiz__"])
	raiz.origin.z -= recuo * (0.08 + _forca_do_recuo * 0.26)
	raiz.origin.x += _lado * recuo * 0.06
	# A QUEDA GIRA EM VOLTA DOS PÉS, E NÃO AFUNDA O BONECO.
	#
	# A primeira versão baixava o corpo inteiro 62 cm além de tombá-lo — e
	# como o nó raiz já fica na altura da lona, isso enfiava o lutador
	# DEBAixo do ringue: nas capturas de nocaute a arena aparecia vazia. O
	# giro em torno dos pés já deita o corpo sozinho, que é o que um corpo
	# caindo faz.
	#
	# E o tombo é para TRÁS, não para o lado: deitado de lado ele mede
	# quase dois metros atravessados e sai pelas bordas do quadro; caindo
	# para o fundo da arena ele encurta na perspectiva e continua inteiro
	# dentro da moldura. O `_lado` fica só como tempero.
	raiz.origin.z -= derrubado * 0.18
	var tombo := -derrubado * 1.30
	raiz.basis = Basis.from_euler(Vector3(tombo, 0.0, _lado * derrubado * 0.22))
	_raiz.transform = raiz

	_junta("Quadril", Vector3(0.0, respiro + salto, 0.0),
		Vector3(recuo * 0.10, _lado * recuo * 0.12, 0.0))
	# O TRONCO É QUEM MOSTRA O IMPACTO. Ele dobra para trás na medida da
	# força: um tapa mal o inclina, um nocaute o joga.
	_junta("Tronco", Vector3.ZERO,
		Vector3(-recuo * (0.12 + _forca_do_recuo * 0.40), _lado * recuo * 0.18, 0.0))
	# A CABEÇA CHICOTEIA. É o movimento que o olho procura num soco, e
	# vem DEPOIS do tronco (amplitude maior, mesma direção).
	_junta("Cabeca", Vector3.ZERO, Vector3(
		-recuo * (0.22 + _forca_do_recuo * 0.62) + sin(t * 1.4) * 0.02,
		_lado * recuo * 0.34 + sin(t * 0.7) * 0.05, _lado * recuo * 0.26))
	# Os braços abrem quando o golpe passa da guarda — é o que separa
	# "ele aparou" de "ele levou".
	var abertura := recuo * _forca_do_recuo
	_junta("Ombro_E", Vector3.ZERO, Vector3(-abertura * 0.5, 0.0, abertura * 0.85))
	_junta("Ombro_D", Vector3.ZERO, Vector3(-abertura * 0.5, 0.0, -abertura * 0.85))
	_junta("Antebraco_E", Vector3.ZERO, Vector3(0.0, 0.0, abertura * 0.40))
	_junta("Antebraco_D", Vector3.ZERO, Vector3(0.0, 0.0, -abertura * 0.40))
	# As pernas cedem: joelho dobra no impacto e desdobra na recuperação.
	_junta("Coxa_E", Vector3.ZERO, Vector3(recuo * 0.20, 0.0, 0.0))
	_junta("Coxa_D", Vector3.ZERO, Vector3(recuo * 0.16, 0.0, 0.0))
	_junta("Canela_E", Vector3.ZERO, Vector3(-recuo * 0.26, 0.0, 0.0))
	_junta("Canela_D", Vector3.ZERO, Vector3(-recuo * 0.22, 0.0, 0.0))

func _junta(nome: String, deslocamento: Vector3, giro: Vector3) -> void:
	var no: Node3D = _juntas.get(nome)
	if no == null:
		return
	var base: Transform3D = _repouso[nome]
	no.position = base.origin + deslocamento
	no.basis = base.basis * Basis.from_euler(giro)
