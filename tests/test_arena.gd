extends SceneTree

## A ARENA SOB TESTE.
##
## Tudo aqui nasceu de um erro que a tela de verdade cometeu e que
## nenhum teste antigo pegaria — porque nenhum teste antigo sabia que
## existia um mundo 3D. Os dois piores:
##
##   • o nocaute AFUNDAVA o lutador. A queda baixava o corpo 62 cm além
##     de tombá-lo, e como o nó raiz já fica na altura da lona, o boneco
##     saía por baixo do ringue: a moldura mostrava um ringue vazio no
##     momento mais importante do jogo.
##   • a janela 3D e o buraco da moldura tinham proporções diferentes, e
##     a imagem chegava esticada na tela — o tipo de coisa que ninguém vê
##     olhando o código e que salta aos olhos na máquina.
##
## Os dois viraram teste. Os demais guardam as regras que a arena promete
## ao resto do jogo: dano que só sobe dentro da rodada, frase que não
## troca sozinha, som que existe de verdade no disco.

const CAMINHO_DO_GLB := "res://assets/personagem/lutador.glb"

var falhas := 0

func _ok(condicao: bool, o_que: String) -> void:
	if not condicao:
		falhas += 1
		print("FALHOU: %s" % o_que)

func _perto(a: float, b: float, folga: float, o_que: String) -> void:
	_ok(absf(a - b) <= folga, "%s (%.4f vs %.4f)" % [o_que, a, b])

func _initialize() -> void:
	_test_o_glb_existe_e_tem_as_juntas()
	_test_a_janela_tem_a_proporcao_do_buraco()
	_test_as_barras_cabem_na_moldura()
	_test_o_dano_soma_e_nao_passa_de_um()
	_test_o_nocaute_nao_afunda_o_lutador()
	_test_levantar_devolve_o_lutador_para_cima_da_lona()
	_test_as_frases_cobrem_todos_os_niveis()
	_test_a_frase_nao_troca_sozinha()
	_test_os_sons_da_arena_existem()
	_test_a_arena_so_liga_nas_telas_do_soco()
	if falhas == 0:
		print("ARENA_OK")
	quit(1 if falhas > 0 else 0)

# ----------------------------------------------------------------- GLB
func _test_o_glb_existe_e_tem_as_juntas() -> void:
	_ok(ResourceLoader.exists(CAMINHO_DO_GLB), "o lutador em GLB tem de estar no disco")
	if not ResourceLoader.exists(CAMINHO_DO_GLB):
		return
	var cena := load(CAMINHO_DO_GLB) as PackedScene
	_ok(cena != null, "o GLB tem de abrir como cena")
	if cena == null:
		return
	var corpo := cena.instantiate()
	# TODAS as juntas que o script anima têm de existir no arquivo. Uma
	# faltando não derruba o jogo (é ignorada), e é justamente por isso
	# que precisa de teste: o boneco pararia de mexer a cabeça e ninguém
	# veria erro nenhum no console.
	for nome in Lutador3D.JUNTAS:
		_ok(corpo.find_child(nome, true, false) != null, "o GLB precisa da peça %s" % nome)
	corpo.free()

# -------------------------------------------------------------- moldura
func _test_a_janela_tem_a_proporcao_do_buraco() -> void:
	var buraco := ArenaQuadro.TELA.size.x / ArenaQuadro.TELA.size.y
	for tamanho in [Arena3D.TAMANHO_CHEIO, Arena3D.TAMANHO_MAGRO]:
		var janela := float(tamanho.x) / float(tamanho.y)
		_perto(janela, buraco, 0.01, "a janela 3D %s tem de ter a proporção do buraco da moldura" % tamanho)

func _test_as_barras_cabem_na_moldura() -> void:
	# As colunas ficam FORA da moldura e DENTRO da tela. Encostar numa
	# coisa ou sair da outra é o tipo de deslize que só aparece quando o
	# gabinete já está montado.
	_ok(ArenaQuadro.BARRA_E.end.x < ArenaQuadro.MOLDURA.position.x, "a coluna esquerda não pode invadir a moldura")
	_ok(ArenaQuadro.BARRA_D.position.x > ArenaQuadro.MOLDURA.end.x, "a coluna direita não pode invadir a moldura")
	_ok(ArenaQuadro.BARRA_E.position.x > 0.0, "a coluna esquerda não pode sair da tela")
	_ok(ArenaQuadro.BARRA_D.end.x < 1080.0, "a coluna direita não pode sair da tela")
	# E o buraco tem de estar inteiro dentro da moldura, senão a imagem
	# vaza por cima da borda.
	_ok(ArenaQuadro.MOLDURA.encloses(ArenaQuadro.TELA), "o buraco tem de caber na moldura")

# ------------------------------------------------------------- o corpo
func _lutador() -> Lutador3D:
	var l := Lutador3D.new()
	var corpo := (load(CAMINHO_DO_GLB) as PackedScene).instantiate()
	l.montar(corpo as Node3D)
	l.preparar()
	return l

func _test_o_dano_soma_e_nao_passa_de_um() -> void:
	var l := _lutador()
	_ok(l.dano == 0.0, "o lutador começa a rodada inteiro")
	l.bater(0.30)
	var depois_de_um := l.dano
	_ok(depois_de_um > 0.0, "um soco de verdade tem de marcar o adversário")
	l.bater(0.30)
	_ok(l.dano > depois_de_um, "o segundo soco soma em cima do primeiro")
	for i in range(10):
		l.bater(1.0)
	_ok(l.dano <= 1.0, "o medidor de dano não pode passar de 100%")
	# Um tapa não conta: sem este piso, o ruído do sensor encheria a barra
	# sozinho ao longo de uma noite.
	l.preparar()
	l.bater(0.005)
	_ok(l.dano == 0.0, "golpe abaixo do mínimo não marca dano")
	l.free()

func _test_o_nocaute_nao_afunda_o_lutador() -> void:
	var l := _lutador()
	var reacao := l.bater(1.0, true)
	_ok(bool(reacao["nocaute"]), "um nível que derruba tem de derrubar no primeiro soco")
	# Dois segundos de queda, no ritmo do jogo.
	for i in range(120):
		l.atualizar(1.0 / 60.0)
	_ok(l.queda > 0.9, "depois de dois segundos ele tem de estar na lona")
	var corpo := l.get_child(0) as Node3D
	# ESTA É A LINHA QUE O ERRO ORIGINAL QUEBRAVA. O corpo caído tem de
	# continuar POR CIMA da lona (y ≈ 0) e dentro do enquadramento da
	# câmera — não debaixo do ringue, que foi onde ele foi parar.
	_ok(corpo.position.y > -0.10, "o lutador caído não pode afundar na lona (y=%.2f)" % corpo.position.y)
	_ok(absf(corpo.position.x) < 1.0, "o lutador caído não pode sair de lado do quadro")
	_ok(corpo.position.z > -1.0, "o lutador caído não pode ir para trás das cordas")
	l.free()

func _test_levantar_devolve_o_lutador_para_cima_da_lona() -> void:
	var l := _lutador()
	l.bater(1.0, true)
	# Queda, contagem e volta: seis segundos cobrem o ciclo inteiro.
	for i in range(360):
		l.atualizar(1.0 / 60.0)
	_ok(l.queda <= 0.001, "ele tem de levantar sozinho para o próximo soco")
	_ok(l.dano < 1.0, "quem levanta volta com fôlego para levar o segundo soco")
	var corpo := l.get_child(0) as Node3D
	_perto(corpo.rotation.x, 0.0, 0.02, "de pé, o corpo volta ao prumo")
	l.free()

# ------------------------------------------------------------- frases
func _test_as_frases_cobrem_todos_os_niveis() -> void:
	for nivel in ScoreTier.NIVEIS:
		var id := str(nivel["id"])
		_ok(ArenaFrases.GOLPES.has(id), "o nível %s precisa das frases dele" % id)
		var lista: Array = ArenaFrases.GOLPES.get(id, [])
		# Uma frase por nível vira rótulo; duas ou mais viram narrador.
		_ok(lista.size() >= 2, "o nível %s precisa de mais de uma frase" % id)
		for i in range(6):
			_ok(not ArenaFrases.de_golpe(id, i).is_empty(), "frase vazia no nível %s" % id)
	_ok(ArenaFrases.de_dano(0.0) == "INTEIRO", "sem dano, o adversário está inteiro")
	_ok(ArenaFrases.de_dano(1.0) == "POR UM FIO", "no talo, o adversário está por um fio")

func _test_a_frase_nao_troca_sozinha() -> void:
	# `_draw` roda sessenta vezes por segundo: a mesma semente TEM de
	# devolver a mesma frase, senão o texto pisca trocando de palavra
	# enquanto a pessoa lê.
	var primeira := ArenaFrases.de_golpe("NOCAUTE", 3)
	for i in range(20):
		_ok(ArenaFrases.de_golpe("NOCAUTE", 3) == primeira, "a frase não pode mudar com a mesma semente")

# --------------------------------------------------------------- som
func _test_os_sons_da_arena_existem() -> void:
	const Catalogo = preload("res://scripts/audio/audio_catalog.gd")
	for cue in ["arena_corpo", "arena_queda", "arena_publico"]:
		_ok(cue in Catalogo.EXTRA, "%s tem de estar no catálogo" % cue)
		var caminho: String = Catalogo.path_for(cue)
		_ok(ResourceLoader.exists(caminho) or FileAccess.file_exists(caminho),
			"o arquivo de %s tem de existir" % cue)
	# O baque do corpo divide o barramento do soco: se ele caísse em SFX,
	# o controle de volume dos efeitos o abafaria junto com os bipes.
	_ok(Catalogo.bus_for("arena_corpo") == "Impact", "o baque do corpo é som de impacto")
	_ok(Catalogo.bus_for("arena_queda") == "Impact", "a queda é som de impacto")

# ------------------------------------------------------------ ligação
func _test_a_arena_so_liga_nas_telas_do_soco() -> void:
	var jogo := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(jogo)
	jogo.intro_active = false
	jogo.central_aberta = false
	var esperado := {
		GameDef.State.IDLE: false,
		GameDef.State.COUNTDOWN: false,
		GameDef.State.ARMED: true,
		GameDef.State.MEASURING: true,
		GameDef.State.RESULT: true,
	}
	for estado in esperado:
		jogo.state = estado
		jogo.verdict_time = -1.0
		_ok(jogo._arena_no_ar() == esperado[estado], "arena ligada no estado %d" % estado)
	# Na tabela de recordes a moldura já saiu da tela: manter o mundo 3D
	# desenhando ali é gastar uma TV Box por nada.
	jogo.state = GameDef.State.RESULT
	jogo.verdict_time = 3.0
	_ok(not jogo._arena_no_ar(), "a arena desliga quando a tabela de recordes entra")
	jogo.verdict_time = -1.0
	jogo.central_aberta = true
	jogo.state = GameDef.State.ARMED
	_ok(not jogo._arena_no_ar(), "a arena desliga com a Central aberta")
	jogo.queue_free()
