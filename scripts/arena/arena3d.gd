class_name Arena3D
extends SubViewport

## A ARENA: UM MUNDO 3D DE VERDADE, DENTRO DE UMA JANELA DA TELA 2D.
##
## O jogo inteiro é desenhado à mão, em 2D, por `main.gd`. A arena não:
## ela é uma cena 3D com câmera, luz e perspectiva, renderizada num
## `SubViewport` e depois COLADA na tela como se fosse um quadro pendurado
## na parede do salão. É daí que vem a impressão de profundidade que um
## desenho 2D não dá por mais sombra que leve — a perspectiva é real, o
## lutador realmente recua para o fundo quando apanha.
##
## POR QUE UM SUBVIEWPORT E NÃO 3D NA CENA PRINCIPAL. Misturar um mundo
## 3D com a tela 2D existente exigiria reorganizar todas as camadas de
## desenho do jogo — e a moldura de LED, o placar e os efeitos passariam
## a disputar ordem com a câmera 3D. Numa janela separada, a arena é só
## mais uma TEXTURA que o `_draw` desenha onde quiser, na ordem que
## quiser. O resto do jogo continua exatamente como era.
##
## O PREÇO ESTÁ CONTROLADO, porque isto vai para uma TV Box:
##
##   • a janela é pequena (a textura é ampliada na hora de desenhar; num
##     quadro com moldura ninguém conta pixel);
##   • sem antisserrilhado, sem sombra, sem brilho — três luzes e pronto;
##   • toda a arena (lona, postes, cordas, fundo) é UMA malha só, com
##     cor por vértice: um desenho, e não trinta;
##   • quando o vigia de desempenho aperta, a janela encolhe e passa a
##     desenhar em 30 quadros por segundo em vez de 60. O lutador
##     continua reagindo no mesmo tempo — só a imagem dele é que atualiza
##     na metade da taxa, e num quadro de 800 pixels isso não se vê.
##   • e ela só liga nas telas em que aparece. Na abertura, na contagem e
##     na tabela de recordes o mundo 3D não é desenhado nenhuma vez.

const TAMANHO_CHEIO := Vector2i(576, 645)
const TAMANHO_MAGRO := Vector2i(384, 430)

## Cores da arena. O salão é claro no 2D; aqui dentro é escuro de
## propósito — o quadro tem de ler como uma JANELA para outro lugar, e
## não como um pedaço da mesma parede.
const COR_LONA := Color("1b2436")
const COR_LONA_CENTRO := Color("232e45")
const COR_BORDA := Color("0e1520")
const COR_POSTE := Color("d81226")
const COR_CORDA := Color("f2f2f0")
const COR_FUNDO := Color("0a0d15")

var lutador: Lutador3D = null
var camera: Camera3D = null
var _mundo: Node3D = null
var _luz_chave: DirectionalLight3D = null
var _rim_quente: OmniLight3D = null
var _rim_frio: OmniLight3D = null
var _flashes: MultiMeshInstance3D = null
var _flash_fase: PackedFloat32Array = PackedFloat32Array()

var _relogio := 0.0
var _acumulado := 0.0
var _tremor := 0.0
var _clarao := 0.0
var _empurrao := 0.0
var _ativa := false
var _magra := false

## 1.0 = tudo; abaixo de 0,55 a janela encolhe e a taxa cai pela metade.
var qualidade := 1.0

func _ready() -> void:
	own_world_3d = true
	transparent_bg = false
	handle_input_locally = false
	msaa_3d = Viewport.MSAA_DISABLED
	screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	use_taa = false
	positional_shadow_atlas_size = 0
	size = TAMANHO_CHEIO
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_montar_mundo()

# ----------------------------------------------------------------- mundo
func _montar_mundo() -> void:
	_mundo = Node3D.new()
	_mundo.name = "Mundo"
	add_child(_mundo)

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COR_FUNDO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a6b")
	env.ambient_light_energy = 0.75
	ambiente.environment = env
	_mundo.add_child(ambiente)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 44.0
	camera.near = 0.15
	camera.far = 24.0
	camera.position = Vector3(0.0, 1.32, 3.35)
	_mundo.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.12, 0.0), Vector3.UP)

	# A LUZ PRINCIPAL vem de cima e da frente: é o refletor do ginásio, o
	# mesmo que o fundo 2D já desenha caindo sobre o saco.
	_luz_chave = DirectionalLight3D.new()
	_luz_chave.name = "Refletor"
	_luz_chave.light_energy = 1.35
	_luz_chave.light_color = Color("fff1d8")
	_luz_chave.shadow_enabled = false
	_luz_chave.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(28.0), 0.0)
	_mundo.add_child(_luz_chave)

	# AS DUAS LUZES DE CONTORNO SÃO A REFERÊNCIA QUE O OPERADOR MANDOU:
	# magenta de um lado, ciano do outro, recortando a silhueta contra o
	# fundo escuro. Não é enfeite — é o que impede o lutador preto e
	# vermelho de sumir dentro de um fundo preto e azul, e é o que dá ao
	# quadro o ar de pôster de jogo de luta em vez de maquete.
	_rim_quente = OmniLight3D.new()
	_rim_quente.name = "ContornoMagenta"
	_rim_quente.light_color = Color("ff2f8e")
	_rim_quente.light_energy = 3.2
	_rim_quente.omni_range = 7.5
	_rim_quente.shadow_enabled = false
	_rim_quente.position = Vector3(-2.1, 1.9, -1.5)
	_mundo.add_child(_rim_quente)

	_rim_frio = OmniLight3D.new()
	_rim_frio.name = "ContornoCiano"
	_rim_frio.light_color = Color("2fd8ff")
	_rim_frio.light_energy = 3.0
	_rim_frio.omni_range = 7.5
	_rim_frio.shadow_enabled = false
	_rim_frio.position = Vector3(2.2, 1.8, -1.4)
	_mundo.add_child(_rim_frio)

	var ringue := MeshInstance3D.new()
	ringue.name = "Ringue"
	ringue.mesh = _malha_do_ringue()
	var tinta := StandardMaterial3D.new()
	tinta.vertex_color_use_as_albedo = true
	tinta.roughness = 0.85
	tinta.metallic = 0.0
	ringue.material_override = tinta
	ringue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mundo.add_child(ringue)

	_montar_flashes()

## TODA A ARENA NUMA MALHA SÓ.
##
## Lona, borda, quatro postes, nove cordas e o painel do fundo são
## trinta e poucas caixas. Trinta `MeshInstance3D` seriam trinta
## chamadas de desenho por quadro, e chamada de desenho é justamente o
## que uma TV Box tem pouco. Costuradas numa malha com cor por vértice,
## viram UMA.
func _malha_do_ringue() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# fundo do ginásio: um painel escuro e um chão abaixo da lona
	_caixa(st, Vector3(0.0, 2.2, -4.2), Vector3(14.0, 7.0, 0.3), COR_FUNDO)
	_caixa(st, Vector3(0.0, -0.9, -0.4), Vector3(14.0, 0.3, 9.0), Color("060810"))
	# a lona e a saia do ringue
	_caixa(st, Vector3(0.0, -0.06, 0.0), Vector3(4.6, 0.12, 4.6), COR_LONA)
	_caixa(st, Vector3(0.0, 0.005, 0.0), Vector3(3.0, 0.02, 3.0), COR_LONA_CENTRO)
	_caixa(st, Vector3(0.0, -0.36, 0.0), Vector3(4.9, 0.50, 4.9), COR_BORDA)
	# quatro postes; os da frente ficam fora do enquadramento de propósito
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_caixa(st, Vector3(sx * 2.15, 0.78, sz * 2.15), Vector3(0.16, 1.72, 0.16), COR_POSTE)
			_caixa(st, Vector3(sx * 2.15, 1.68, sz * 2.15), Vector3(0.22, 0.10, 0.22), Color("f5c542"))
	# as cordas: só as do fundo e as laterais. As da frente cruzariam o
	# lutador na altura do peito e esconderiam justamente o que se quer
	# ver — num ringue de verdade a câmera também escolhe um lado.
	for i in range(3):
		var y := 0.42 + float(i) * 0.42
		_caixa(st, Vector3(0.0, y, -2.15), Vector3(4.34, 0.055, 0.055), COR_CORDA)
		_caixa(st, Vector3(-2.15, y, 0.0), Vector3(0.055, 0.055, 4.34), COR_CORDA)
		_caixa(st, Vector3(2.15, y, 0.0), Vector3(0.055, 0.055, 4.34), COR_CORDA)
	st.generate_normals()
	return st.commit()

func _caixa(st: SurfaceTool, centro: Vector3, tamanho: Vector3, cor: Color) -> void:
	var h := tamanho * 0.5
	var c := [
		centro + Vector3(-h.x, -h.y, h.z), centro + Vector3(h.x, -h.y, h.z),
		centro + Vector3(h.x, -h.y, -h.z), centro + Vector3(-h.x, -h.y, -h.z),
		centro + Vector3(-h.x, h.y, h.z), centro + Vector3(h.x, h.y, h.z),
		centro + Vector3(h.x, h.y, -h.z), centro + Vector3(-h.x, h.y, -h.z),
	]
	var faces := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]
	for face in faces:
		# O topo recebe um fio de luz a mais: sem isso a caixa vista de
		# cima some no fundo escuro e o ringue vira uma mancha.
		var tom := cor.lightened(0.16) if face[0] == 4 else cor
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for k in tri:
				st.set_color(tom)
				st.add_vertex(c[face[k]])

## OS FLASHES DA PLATEIA. Dezoito pontinhos brancos piscando no escuro,
## atrás das cordas — é o clichê que diz "há gente ali fora" sem desenhar
## uma única pessoa. Num `MultiMesh` eles custam um desenho só, e é o que
## permite haver dezoito em vez de três.
func _montar_flashes() -> void:
	var quantos := 18
	var malha := QuadMesh.new()
	malha.size = Vector2(0.11, 0.11)
	var tinta := StandardMaterial3D.new()
	tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tinta.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tinta.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tinta.vertex_color_use_as_albedo = true
	tinta.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tinta.albedo_color = Color.WHITE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malha
	mm.instance_count = quantos
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260915
	_flash_fase.resize(quantos)
	for i in range(quantos):
		var t := Transform3D()
		t.origin = Vector3(
			rng.randf_range(-3.4, 3.4), rng.randf_range(0.9, 2.9), rng.randf_range(-3.9, -2.6)
		)
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, Color(0, 0, 0, 1))
		_flash_fase[i] = rng.randf() * TAU
	_flashes = MultiMeshInstance3D.new()
	_flashes.name = "Flashes"
	_flashes.multimesh = mm
	_flashes.material_override = tinta
	_flashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mundo.add_child(_flashes)

# ------------------------------------------------------------- o lutador
## Põe o lutador na lona. `cena` é o GLB já carregado; sem ele a arena
## continua funcionando (ringue vazio) em vez de derrubar o jogo.
func instalar(cena: PackedScene) -> bool:
	if cena == null:
		return false
	var corpo := cena.instantiate()
	if not (corpo is Node3D):
		return false
	lutador = Lutador3D.new()
	lutador.name = "Lutador"
	_mundo.add_child(lutador)
	lutador.montar(corpo as Node3D)
	return true

# ---------------------------------------------------------------- ritmo
func ligar(ativa: bool) -> void:
	if _ativa == ativa:
		return
	_ativa = ativa
	if not ativa:
		render_target_update_mode = SubViewport.UPDATE_DISABLED

func ativa() -> bool:
	return _ativa

## O SOCO CHEGOU NA ARENA. Devolve o que o corpo fez com ele.
func golpe(forca: float, derruba := false) -> Dictionary:
	_tremor = clampf(0.35 + forca, 0.0, 1.35)
	_clarao = clampf(0.4 + forca * 0.6, 0.0, 1.0)
	_empurrao = forca
	if lutador == null:
		return {"nocaute": false, "dano": 0.0}
	return lutador.bater(forca, derruba)

func preparar() -> void:
	if lutador != null:
		lutador.preparar()
	_tremor = 0.0
	_clarao = 0.0

func guardar(ativo: bool) -> void:
	if lutador != null:
		lutador.guardar(ativo)

func dano() -> float:
	return lutador.dano if lutador != null else 0.0

func na_lona() -> bool:
	return lutador != null and lutador.queda > 0.35

func avancar(delta: float) -> void:
	if not _ativa:
		return
	_relogio += delta
	_tremor = maxf(0.0, _tremor - delta * 2.2)
	_clarao = maxf(0.0, _clarao - delta * 2.4)
	_empurrao = maxf(0.0, _empurrao - delta * 1.6)
	if lutador != null:
		lutador.atualizar(delta)
	_camera()
	_luzes()
	_piscar()
	# A JANELA SÓ DESENHA QUANDO PRECISA.
	#
	# `UPDATE_ALWAYS` deixaria o mundo 3D redesenhando a 60 Hz mesmo com o
	# jogo apertado. Pedindo um quadro de cada vez, a arena pode andar a
	# 30 Hz num aparelho fraco enquanto a interface 2D continua a 60 — e é
	# a interface que a pessoa lê.
	var intervalo := 1.0 / 62.0 if qualidade >= 0.55 else 1.0 / 31.0
	_acumulado += delta
	if _acumulado >= intervalo:
		_acumulado = 0.0
		render_target_update_mode = SubViewport.UPDATE_ONCE
	_ajustar_tamanho()

func _ajustar_tamanho() -> void:
	var magra := qualidade < 0.55
	if magra == _magra:
		return
	_magra = magra
	size = TAMANHO_MAGRO if magra else TAMANHO_CHEIO

## A CÂMERA TAMBÉM APANHA. Ela recua no impacto, treme junto e volta
## sozinha — é o que transforma "o boneco se mexeu" em "a pancada foi
## sentida daqui". Um passeio lento e contínuo, por baixo, mantém a
## profundidade viva mesmo quando ninguém está batendo.
func _camera() -> void:
	if camera == null:
		return
	var passeio := sin(_relogio * 0.33) * 0.16
	var sacode := Vector3.ZERO
	if _tremor > 0.02:
		sacode = Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.4, 0.4)
		) * _tremor * 0.055
	var pos := Vector3(passeio, 1.28 + sin(_relogio * 0.21) * 0.05, 2.95 - _empurrao * 0.24)
	var mira := Vector3(0.0, 1.06 + _empurrao * 0.06, 0.0)
	# QUANDO ELE CAI, A CÂMERA VAI JUNTO. Ficar parada na altura do peito
	# depois do nocaute deixaria a moldura com um ringue vazio e o corpo
	# fora de quadro — que foi exatamente o que aconteceu na primeira
	# montagem. Subir e olhar para baixo é o que qualquer transmissão faz.
	var caido := lutador.queda if lutador != null else 0.0
	if caido > 0.001:
		var t := ease(caido, 0.5)
		pos = pos.lerp(Vector3(0.18, 2.24, 2.70), t)
		mira = mira.lerp(Vector3(0.0, 0.30, -0.70), t)
	camera.position = pos + sacode
	camera.look_at(mira, Vector3.UP)

func _luzes() -> void:
	# O golpe ACENDE a arena por um instante, pelas luzes de contorno. Um
	# clarão branco por cima lavaria a imagem; puxar o contorno mantém as
	# cores e ainda assim diz "explodiu".
	var extra := _clarao * 6.0
	if _rim_quente != null:
		_rim_quente.light_energy = 3.2 + extra
	if _rim_frio != null:
		_rim_frio.light_energy = 3.0 + extra
	if _luz_chave != null:
		_luz_chave.light_energy = 1.35 + _clarao * 1.1

func _piscar() -> void:
	if _flashes == null:
		return
	var mm := _flashes.multimesh
	# Na pancada a plateia inteira dispara ao mesmo tempo; parada, é um
	# ou outro piscando aqui e ali.
	var festa := _clarao
	for i in range(mm.instance_count):
		var fase: float = _flash_fase[i]
		var base := maxf(0.0, sin(_relogio * 1.7 + fase) - 0.93) * 9.0
		var a := clampf(base + festa * (0.35 + 0.65 * absf(sin(fase * 3.1 + _relogio * 22.0))), 0.0, 1.0)
		# O BRILHO VAI NO RGB, E NÃO NA TRANSPARÊNCIA. Em mistura aditiva
		# o alfa não apaga nada: um flash "invisível" com alfa 0 continuava
		# somando branco na tela e virava um quadrado cinza permanente
		# dentro da arena. Escurecendo a COR, apagado é preto, e preto
		# somado não muda pixel nenhum.
		mm.set_instance_color(i, Color(a, a * 0.96, a * 0.88, 1.0))
