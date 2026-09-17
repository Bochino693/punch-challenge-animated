class_name Lutador3D
extends Node3D

## Controlador do adversário humanoide. O contrato preferido é um GLB com
## Skeleton3D, skin e AnimationPlayer; a pose procedural existe somente como
## fallback para um asset externo incompleto.

const DANO_POR_GOLPE := 0.62
const DANO_MINIMO := 0.02
const TEMPO_NA_LONA := 3.35
const TEMPO_LEVANTAR := 1.65

const JUNTAS := [
	"Quadril", "Tronco", "Cabeca", "Pescoco", "Ombro_E", "Ombro_D",
	"Antebraco_E", "Antebraco_D", "Luva_E", "Luva_D", "Coxa_E", "Coxa_D",
	"Canela_E", "Canela_D",
]

const ALIASES := {
	"idle": ["idle", "breathing_idle", "boxer_idle"],
	"guard": ["guard", "boxing_guard", "fighting_idle"],
	"taunt_weak": ["taunt_weak", "taunt", "mock", "disdain"],
	"hit_light": ["hit_light", "light_hit", "hit_reaction_1"],
	"hit_medium": ["hit_medium", "medium_hit", "hit_reaction_2"],
	"hit_heavy": ["hit_heavy", "heavy_hit", "hit_reaction_3"],
	"stagger": ["stagger", "stumble", "impact_heavy"],
	"knockout": ["knockout", "ko", "fall_back", "knock_down"],
	"get_up": ["get_up", "stand_up", "recover"],
}

var _juntas: Dictionary = {}
var _repouso: Dictionary = {}
var _raiz: Node3D = null
var _animador: AnimationPlayer = null
var _esqueleto: Skeleton3D = null
var _animacoes: Dictionary = {}
var _relogio := 0.0
var _recuo := 0.0
var _forca_do_recuo := 0.0
var _lado := 1.0
var _tempo_reacao := 0.0
var _tempo_na_lona := 0.0
var _levantando := false
var queda := 0.0
var _caindo := false
var dano := 0.0
var em_guarda := false

func montar(corpo: Node3D) -> void:
	_raiz = corpo
	add_child(corpo)
	_animador = _achar_animador(corpo)
	_esqueleto = _achar_esqueleto(corpo)
	_indexar_animacoes()
	for nome in JUNTAS:
		var no := corpo.find_child(nome, true, false)
		if no is Node3D:
			_juntas[nome] = no
			_repouso[nome] = (no as Node3D).transform
	_repouso["__raiz__"] = corpo.transform

func tem_esqueleto() -> bool:
	return _esqueleto != null and _esqueleto.get_bone_count() >= 15

func animacoes_disponiveis() -> PackedStringArray:
	var nomes := PackedStringArray()
	for nome in _animacoes:
		nomes.append(str(nome))
	return nomes

func _achar_animador(no: Node) -> AnimationPlayer:
	if no is AnimationPlayer:
		return no
	for filho in no.get_children():
		var achado := _achar_animador(filho)
		if achado != null:
			return achado
	return null

func _achar_esqueleto(no: Node) -> Skeleton3D:
	if no is Skeleton3D:
		return no
	for filho in no.get_children():
		var achado := _achar_esqueleto(filho)
		if achado != null:
			return achado
	return null

func _normalizar(nome: String) -> String:
	var n := nome.to_lower().replace(" ", "_").replace("-", "_")
	for separador in ["|", "/", ":"]:
		if separador in n:
			n = n.get_slice(separador, n.get_slice_count(separador) - 1)
	return n

func _indexar_animacoes() -> void:
	_animacoes.clear()
	if _animador == null:
		return
	var existentes := _animador.get_animation_list()
	for papel in ALIASES:
		for real in existentes:
			var normal := _normalizar(str(real))
			for alias in ALIASES[papel]:
				if normal == alias or normal.ends_with("_" + alias) or alias in normal:
					_animacoes[papel] = real
					break
			if _animacoes.has(papel):
				break

func _tocar(papel: String, mistura := 0.16, velocidade := 1.0) -> bool:
	if _animador == null or not _animacoes.has(papel):
		return false
	var real: StringName = _animacoes[papel]
	if _animador.current_animation == str(real) and _animador.is_playing():
		return true
	_animador.play(real, mistura, velocidade)
	return true

func preparar() -> void:
	dano = 0.0
	queda = 0.0
	_caindo = false
	_levantando = false
	_recuo = 0.0
	_tempo_reacao = 0.0
	_tempo_na_lona = 0.0
	em_guarda = false
	if _raiz != null and _repouso.has("__raiz__"):
		_raiz.transform = _repouso["__raiz__"]
	_tocar("idle", 0.05)

func guardar(ativo: bool) -> void:
	em_guarda = ativo
	if _caindo:
		return
	if ativo:
		if not _tocar("guard", 0.22):
			_tocar("idle", 0.22)
	else:
		_tocar("idle", 0.22)

func bater(forca: float, derruba := false, pontos := -1) -> Dictionary:
	var f := clampf(forca, 0.0, 1.0)
	_recuo = 1.0
	_forca_do_recuo = f
	# Alternar o lado mantém variedade sem depender de aleatoriedade: duas
	# máquinas com o mesmo golpe exibem a mesma intensidade e duração.
	_lado *= -1.0
	var antes := dano
	if f > DANO_MINIMO:
		dano = clampf(dano + f * DANO_POR_GOLPE, 0.0, 1.0)
	var nocaute := not _caindo and (derruba or (dano >= 1.0 and antes < 1.0))
	var papel := ""
	var desdenhou := false
	if nocaute:
		papel = "knockout"
		_caindo = true
		_levantando = false
		_tempo_na_lona = 0.0
		_tempo_reacao = TEMPO_NA_LONA + TEMPO_LEVANTAR
		_tocar("knockout", 0.08, lerpf(0.92, 1.12, f))
	elif not _caindo:
		# A nota é a linguagem do jogador. Abaixo de 6.000 o adversário
		# entende que o golpe foi fraco e desdenha, mesmo que a calibração
		# física da máquina tenha registrado algum movimento. Na lona ele
		# nunca executa esta resposta: um nocaute não pode virar deboche.
		papel = reacao_para_pontos(pontos, f)
		desdenhou = papel == "taunt_weak" and pontos >= 0 and pontos < 6000
		var duracao := 1.25
		if papel == "taunt_weak":
			duracao = 1.18
		elif papel == "stagger":
			duracao = 1.35
		elif papel == "hit_heavy":
			duracao = 1.05
		elif papel == "hit_medium":
			duracao = 0.82
		elif papel == "hit_light":
			duracao = 0.58
		_tempo_reacao = duracao
		_tocar(papel, 0.06, lerpf(0.92, 1.10, f))
	return {"nocaute": nocaute, "dano": dano, "reacao": papel, "desdenhou": desdenhou}

static func reacao_para_pontos(pontos: int, forca: float) -> String:
	if pontos >= 0 and pontos < 6000:
		return "taunt_weak"
	var reacao := reacao_para_forca(forca)
	# Depois do corte competitivo, no mínimo reconhece o golpe. Isso evita
	# que uma calibração de velocidade conservadora contradiga os pontos.
	if pontos >= 6000 and reacao == "taunt_weak":
		return "hit_light"
	return reacao

static func reacao_para_forca(forca: float) -> String:
	var f := clampf(forca, 0.0, 1.0)
	if f >= 0.82:
		return "stagger"
	if f >= 0.62:
		return "hit_heavy"
	if f >= 0.38:
		return "hit_medium"
	if f >= 0.18:
		return "hit_light"
	return "taunt_weak"

func atualizar(delta: float) -> void:
	_relogio += delta
	_recuo = maxf(0.0, _recuo - delta * 2.1)
	_tempo_reacao = maxf(0.0, _tempo_reacao - delta)
	if _caindo:
		_tempo_na_lona += delta
		queda = minf(1.0, queda + delta * 2.8)
		if _tempo_na_lona >= TEMPO_NA_LONA and not _levantando:
			_levantando = true
			_tocar("get_up", 0.12)
		if _levantando:
			queda = maxf(0.0, 1.0 - (_tempo_na_lona - TEMPO_NA_LONA) / TEMPO_LEVANTAR)
		if _tempo_na_lona >= TEMPO_NA_LONA + TEMPO_LEVANTAR:
			_caindo = false
			_levantando = false
			queda = 0.0
			dano = minf(dano, 0.72)
			_tocar("guard" if em_guarda else "idle", 0.20)
	elif _tempo_reacao <= 0.0:
		_tocar("guard" if em_guarda else "idle", 0.20)

	if _animador != null and not _animacoes.is_empty():
		return
	_pose_fallback()

func _pose_fallback() -> void:
	if _raiz == null:
		return
	var raiz: Transform3D = _repouso.get("__raiz__", _raiz.transform)
	var impacto := ease(_recuo, 0.35)
	var tombo := ease(queda, 0.6)
	raiz.origin.z -= impacto * (0.08 + _forca_do_recuo * 0.26) + tombo * 0.18
	raiz.origin.x += _lado * impacto * 0.06
	raiz.basis = raiz.basis * Basis.from_euler(Vector3(-tombo * 1.30, 0.0, _lado * tombo * 0.20))
	_raiz.transform = raiz
	_junta("Tronco", Vector3(-impacto * (0.12 + _forca_do_recuo * 0.40), _lado * impacto * 0.16, 0.0))
	_junta("Cabeca", Vector3(-impacto * (0.22 + _forca_do_recuo * 0.60), _lado * impacto * 0.30, 0.0))

func _junta(nome: String, giro: Vector3) -> void:
	var no: Node3D = _juntas.get(nome)
	if no == null:
		return
	var base: Transform3D = _repouso[nome]
	no.transform = Transform3D(base.basis * Basis.from_euler(giro), base.origin)
