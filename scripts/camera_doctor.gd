class_name CameraDoctor
extends Node

## Diagnóstico leve. O PowerShell apenas enumera PnP, lê a privacidade e,
## quando solicitado, libera o acesso do usuário. Ele nunca transporta vídeo
## e nunca disputa a webcam com o jogo.

signal terminou

var linhas: Array[String] = []
var rodando := false
var indices: Array[int] = []
var backend := ""
var cameras_do_windows := -1
var privacidade := ""
var ocupantes := ""

var _thread: Thread = null
var _mutex := Mutex.new()
var _fila: Array[String] = []
var _fim := false
var _resolver := false
var _caminho_inspetor := ""

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	_mutex.lock()
	var novas := _fila.duplicate()
	_fila.clear()
	var acabou := _fim
	_fim = false
	_mutex.unlock()
	if not novas.is_empty():
		linhas.append_array(novas)
		while linhas.size() > 12:
			linhas.remove_at(0)
	if acabou:
		rodando = false
		if _thread != null:
			_thread.wait_to_finish()
			_thread = null
		terminou.emit()

func diagnosticar(resolver: bool, _caminho_antigo := "", caminho_inspetor := "") -> void:
	if rodando:
		return
	rodando = true
	linhas.clear()
	indices.clear()
	backend = ""
	cameras_do_windows = -1
	privacidade = ""
	ocupantes = ""
	_resolver = resolver
	_caminho_inspetor = caminho_inspetor
	_thread = Thread.new()
	_thread.start(_trabalhar)

func _trabalhar() -> void:
	if OS.get_name() != "Windows":
		_dizer("Captura nativa ativa neste sistema.")
		_dizer("Use PROCURAR DE NOVO após conectar a câmera.")
		_terminar()
		return
	if _caminho_inspetor.is_empty() or not FileAccess.file_exists(_caminho_inspetor):
		_dizer("DIAGNÓSTICO POWERSHELL NÃO ENCONTRADO NO PACOTE.")
		_terminar()
		return
	_dizer("Consultando câmeras e privacidade do Windows…")
	var saida: Array = []
	var acao := "liberar" if _resolver else "listar"
	var codigo := OS.execute(
		"powershell.exe",
		PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", _caminho_inspetor, "-Acao", acao]),
		saida,
		true
	)
	for bloco in saida:
		for bruta in str(bloco).split("\n"):
			var linha := str(bruta).strip_edges()
			if linha.is_empty():
				continue
			_interpretar(linha)
	if codigo != 0:
		_dizer("POWERSHELL RETORNOU ERRO %d." % codigo)
	elif cameras_do_windows <= 0:
		_dizer("WINDOWS NÃO ENCONTROU CÂMERA — CONFIRA CABO E PORTA USB.")
	else:
		backend = "MEDIA FOUNDATION"
		_dizer("MEDIA FOUNDATION PRONTA — %d CÂMERA(S)." % cameras_do_windows)
	_terminar()

func _interpretar(linha: String) -> void:
	if linha.begins_with("DISPOSITIVO="):
		_dizer(linha.trim_prefix("DISPOSITIVO="))
	elif linha.begins_with("WINDOWS_CAMERAS="):
		cameras_do_windows = int(linha.trim_prefix("WINDOWS_CAMERAS="))
		for i in range(maxi(cameras_do_windows, 0)):
			indices.append(i)
	elif linha.begins_with("PRIVACIDADE_PROGRAMAS="):
		privacidade = linha.trim_prefix("PRIVACIDADE_PROGRAMAS=")
		_dizer("Privacidade para programas: %s" % privacidade)
	elif linha.begins_with("OCUPANTES="):
		ocupantes = linha.trim_prefix("OCUPANTES=")
		_dizer("Programas que podem usar câmera: %s" % ocupantes)
	elif linha.begins_with("LIBEROU=") or linha.begins_with("FALHOU="):
		_dizer(linha)

func _veredito() -> String:
	if cameras_do_windows == 0:
		return "Windows não encontrou câmera: confira cabo e porta USB."
	if privacidade.to_lower() == "deny":
		return "PRIVACIDADE bloqueada: use RESOLVER ACESSO."
	if not ocupantes.is_empty() and ocupantes != "nenhum":
		return "Feche antes: %s" % ocupantes
	if cameras_do_windows > 0:
		return "Media Foundation pronta para captura nativa."
	return "Conecte a câmera e use PROCURAR DE NOVO."

func _dizer(texto: String) -> void:
	_mutex.lock()
	_fila.append(texto)
	_mutex.unlock()

func _terminar() -> void:
	_mutex.lock()
	_fim = true
	_mutex.unlock()

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
