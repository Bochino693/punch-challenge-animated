class_name CameraService
extends Node

## Webcam nativa. No Windows, CameraServerExtension usa Media Foundation e
## entrega os quadros diretamente ao Godot: sem Python, OpenCV, processo
## auxiliar ou JPEG intermediário.

const PHOTO_DIR := "user://ranking_photos"
const THUMB_SIZE := 320
const VIDA_MAXIMA_MS := 10000
const INTERVALO_AMOSTRA_MS := 500
const INTERVALO_OBTURADOR_MS := 66
const INTERVALO_NOVA_BUSCA_MS := 2500
const CONTRASTE_MINIMO := 0.04

enum Estado { DESLIGADA, SUBINDO, ACESA, EXAME, PARADA }

var enabled := true
var mirrored := true
var selected_index := 0
var estado := Estado.DESLIGADA
var status := "PROCURANDO CÂMERA"
var ultima_foto: Image = null

# Não tipar como CameraFeed: o addon documenta que o upcast desabilita
# get_formats/set_format no CameraFeedExtension.
var _feed = null
var _texture: CameraTexture = null
var _camera_extension = null
var _extension_iniciada := false
var _proxima_amostra_ms := 0
var _proxima_busca_ms := 0
var _last_frame_ms := 0
var _last_image: Image = null
var _sessao_aprovada := false
var _assinatura_do_quadro := 0
var _ultima_mudanca_ms := 0

var _melhor_imagem: Image = null
var _melhor_nota := -1.0
var _obturador_ate_ms := 0
var _obturador_teve_vida := false
var _obturador_foi_aberto := false

func _ready() -> void:
	_acordar_servidor()
	if not CameraServer.camera_feed_added.is_connected(_on_camera_feeds_updated):
		CameraServer.camera_feed_added.connect(_on_camera_feeds_updated)
	if not CameraServer.camera_feed_removed.is_connected(_on_camera_feeds_updated):
		CameraServer.camera_feed_removed.connect(_on_camera_feeds_updated)
	if enabled:
		iniciar_captura()
	else:
		estado = Estado.DESLIGADA
		status = "CÂMERA DESATIVADA"
	set_process(true)

func _process(_delta: float) -> void:
	if not enabled or estado in [Estado.DESLIGADA, Estado.EXAME]:
		return
	var agora := Time.get_ticks_msec()
	if _feed == null:
		# Só repete a descoberta enquanto não há câmera. Uma câmera aberta
		# nunca é derrubada por relógio, evitando CONECTANDO/CONECTADA.
		if agora >= _proxima_busca_ms:
			_proxima_busca_ms = agora + INTERVALO_NOVA_BUSCA_MS
			_descobrir_cameras(true)
		return
	if agora < _proxima_amostra_ms:
		return
	var obturador_aberto := agora <= _obturador_ate_ms
	_proxima_amostra_ms = agora + (INTERVALO_OBTURADOR_MS if obturador_aberto else INTERVALO_AMOSTRA_MS)
	_amostrar_quadro()

func iniciar_captura() -> void:
	enabled = true
	estado = Estado.SUBINDO
	status = "PROCURANDO CÂMERA USB…"
	_descobrir_cameras(false)

func _descobrir_cameras(recriar_extensao: bool) -> void:
	_acordar_servidor()
	if OS.get_name() == "Windows" and ClassDB.class_exists(&"CameraServerExtension"):
		if recriar_extensao:
			_parar_feed()
			_camera_extension = null
			_extension_iniciada = false
		if not _extension_iniciada:
			_camera_extension = ClassDB.instantiate(&"CameraServerExtension")
			_extension_iniciada = _camera_extension != null
			if _camera_extension != null and _camera_extension.has_signal("permission_result"):
				var callback := Callable(self, "_on_permission_result")
				if not _camera_extension.is_connected("permission_result", callback):
					_camera_extension.connect("permission_result", callback)
			if _camera_extension != null and _camera_extension.has_method("permission_granted"):
				if not bool(_camera_extension.call("permission_granted")):
					status = "WINDOWS BLOQUEOU A CÂMERA — USE RESOLVER ACESSO"
					if _camera_extension.has_method("request_permission"):
						_camera_extension.call("request_permission")
					return
	_abrir_feed_disponivel()

func _abrir_feed_disponivel() -> void:
	if not enabled or _feed != null:
		return
	var feeds: Array = CameraServer.feeds()
	if feeds.is_empty():
		estado = Estado.SUBINDO
		status = "CONECTE UMA CÂMERA USB — BUSCANDO…"
		return
	selected_index = clampi(selected_index, 0, feeds.size() - 1)
	_feed = feeds[selected_index]
	_selecionar_formato_estavel()
	_feed.set_active(true)
	_texture = CameraTexture.new()
	_texture.camera_feed_id = _feed.get_id()
	_texture.which_feed = CameraServer.FEED_RGBA_IMAGE
	_proxima_amostra_ms = 0
	estado = Estado.SUBINDO
	status = "ABRINDO CÂMERA VIA MEDIA FOUNDATION…" if OS.get_name() == "Windows" else "ABRINDO CÂMERA…"

## Prefere 1280x720/30. Evitar 4K reduz USB e conversão sem sacrificar a
## miniatura quadrada de 320 px usada no ranking.
func _selecionar_formato_estavel() -> void:
	if _feed == null or not _feed.has_method("get_formats") or not _feed.has_method("set_format"):
		return
	var formatos: Array = _feed.get_formats()
	if formatos.is_empty():
		return
	var melhor := -1
	var melhor_nota := -1.0e30
	for i in range(formatos.size()):
		var formato: Dictionary = formatos[i]
		var largura := int(formato.get("width", 0))
		var altura := int(formato.get("height", 0))
		var numerador := float(formato.get("framerate_numerator", 0))
		var denominador := maxf(float(formato.get("framerate_denominator", 1)), 1.0)
		var fps := numerador / denominador
		if largura <= 0 or altura <= 0 or fps < 20.0:
			continue
		var distancia := absf(float(largura - 1280)) + absf(float(altura - 720)) * 1.5
		var nota := -distancia + minf(fps, 30.0) * 20.0
		if largura > 1920 or altura > 1080:
			nota -= 10000.0
		if str(formato.get("format", "")) == "MJPG":
			nota += 250.0
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = i
	_feed.set_format(0 if melhor < 0 else melhor, {})

func _amostrar_quadro() -> void:
	if _texture == null:
		return
	var imagem := _texture.get_image()
	if imagem == null or imagem.is_empty():
		return
	_registrar_quadro(imagem, Time.get_ticks_msec())
	if estado != Estado.ACESA:
		estado = Estado.ACESA
		status = "CÂMERA CONECTADA — VÍDEO AO VIVO"

func _on_permission_result(granted: bool) -> void:
	if granted:
		status = "ACESSO LIBERADO — PROCURANDO CÂMERA…"
		procurar_de_novo()
	else:
		estado = Estado.PARADA
		status = "ACESSO À CÂMERA NEGADO PELO WINDOWS"

func _on_camera_feeds_updated(_id: int = 0) -> void:
	if enabled and _feed == null:
		call_deferred("_abrir_feed_disponivel")

func _acordar_servidor() -> void:
	if CameraServer.has_method("set_monitoring_feeds"):
		CameraServer.call("set_monitoring_feeds", true)

func set_enabled(value: bool) -> void:
	if value:
		if enabled and _feed != null:
			return
		iniciar_captura()
	else:
		enabled = false
		_parar_feed()
		_sessao_aprovada = false
		estado = Estado.DESLIGADA
		status = "CÂMERA DESATIVADA"

func cycle_camera() -> void:
	var total := CameraServer.feeds().size()
	selected_index = (selected_index + 1) % maxi(total, 1)
	_parar_feed()
	_sessao_aprovada = false
	estado = Estado.SUBINDO
	_abrir_feed_disponivel()

func procurar_de_novo() -> void:
	_parar_feed()
	_sessao_aprovada = false
	estado = Estado.SUBINDO
	status = "PROCURANDO CÂMERA USB…"
	_descobrir_cameras(true)

func entregar_ao_exame() -> void:
	# O PowerShell consulta PnP/privacidade; não abre o vídeo.
	pass

func terminar_exame() -> void:
	if enabled and _feed == null:
		procurar_de_novo()

func pedir_abertura() -> void:
	set_enabled(true)

func pedir_fechamento() -> void:
	set_enabled(false)

func pedir_exame() -> void:
	entregar_ao_exame()

func pronta() -> bool:
	return enabled and _sessao_aprovada and estado == Estado.ACESA and ao_vivo()

func estado_curto() -> String:
	return status

func preview_texture() -> Texture2D:
	return _texture

func available() -> bool:
	return pronta() and ao_vivo()

func tem_imagem() -> bool:
	return enabled and _texture != null and _sessao_aprovada

func ao_vivo() -> bool:
	return enabled and _last_frame_ms > 0 and Time.get_ticks_msec() - _last_frame_ms <= VIDA_MAXIMA_MS

func motivo_curto() -> String:
	if not enabled:
		return "CÂMERA DESLIGADA NA CENTRAL"
	if estado == Estado.PARADA:
		return status
	if _feed == null:
		return "NENHUMA CÂMERA USB ENCONTRADA"
	if not _sessao_aprovada:
		return "AGUARDANDO O PRIMEIRO QUADRO"
	return status

func ficha_da_ponte() -> String:
	if _feed == null:
		return "CAPTURA NATIVA — AGUARDANDO DISPOSITIVO"
	var nome := str(_feed.get_name()) if _feed.has_method("get_name") else "CÂMERA USB"
	return "%s • MEDIA FOUNDATION • SEM PYTHON" % nome if OS.get_name() == "Windows" else "%s • CAPTURA NATIVA" % nome

func caminho_do_inspetor() -> String:
	# Em exportação com PCK embutido, res:// não é um arquivo que o
	# PowerShell consiga abrir. Materializamos uma cópia local somente para
	# o diagnóstico; ela não participa da captura de vídeo.
	var origem := FileAccess.open("res://tools/camera_windows.ps1", FileAccess.READ)
	if origem == null:
		return ""
	var conteudo := origem.get_as_text()
	origem.close()
	var pasta := "user://camera_native"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var destino_virtual := pasta + "/camera_windows.ps1"
	var destino := FileAccess.open(destino_virtual, FileAccess.WRITE)
	if destino == null:
		return ""
	destino.store_string(conteudo)
	destino.close()
	return ProjectSettings.globalize_path(destino_virtual)

func idade_do_quadro() -> int:
	return 999999 if _last_frame_ms <= 0 else Time.get_ticks_msec() - _last_frame_ms

func parada_ha() -> int:
	return 999999 if _ultima_mudanca_ms <= 0 else Time.get_ticks_msec() - _ultima_mudanca_ms

func abrir_obturador(janela_ms := 3200) -> void:
	_melhor_imagem = null
	_melhor_nota = -1.0
	_obturador_teve_vida = false
	_obturador_foi_aberto = true
	_obturador_ate_ms = Time.get_ticks_msec() + janela_ms
	_proxima_amostra_ms = 0

func _imagem_util(imagem: Image) -> bool:
	return _nota_da_imagem(imagem) >= CONTRASTE_MINIMO

func _nota_da_imagem(imagem: Image) -> float:
	return float(_medir_quadro(imagem)["nota"])

func _medir_quadro(imagem: Image) -> Dictionary:
	if imagem == null or imagem.is_empty() or imagem.get_width() < 8 or imagem.get_height() < 8:
		return {"nota": -1.0, "assinatura": 0}
	var claro := 0.0
	var escuro := 1.0
	var assinatura := 0
	for gx in range(8):
		for gy in range(6):
			var x := int((float(gx) + 0.5) / 8.0 * float(imagem.get_width()))
			var y := int((float(gy) + 0.5) / 6.0 * float(imagem.get_height()))
			var v := imagem.get_pixel(x, y).get_luminance()
			claro = maxf(claro, v)
			escuro = minf(escuro, v)
			assinatura = (assinatura * 31 + int(v * 255.0)) & 0x3FFFFFFF
	return {"nota": claro - escuro, "assinatura": assinatura}

func _registrar_quadro(imagem: Image, agora: int) -> void:
	if imagem == null or imagem.is_empty():
		return
	var medida := _medir_quadro(imagem)
	var assinatura := int(medida["assinatura"])
	if assinatura != _assinatura_do_quadro:
		_assinatura_do_quadro = assinatura
		_ultima_mudanca_ms = agora
		if agora <= _obturador_ate_ms:
			_obturador_teve_vida = true
	_last_image = imagem
	_last_frame_ms = agora
	_sessao_aprovada = true
	_oferecer_ao_obturador(imagem, float(medida["nota"]))

func _oferecer_ao_obturador(imagem: Image, nota_pronta := NAN) -> void:
	if imagem == null or Time.get_ticks_msec() > _obturador_ate_ms:
		return
	var nota := nota_pronta if not is_nan(nota_pronta) else _nota_da_imagem(imagem)
	if nota > _melhor_nota:
		_melhor_nota = nota
		_melhor_imagem = imagem.duplicate()

func capture_photo() -> String:
	var image: Image = null
	var captura_da_pose := _obturador_foi_aberto
	_obturador_foi_aberto = false
	_obturador_ate_ms = 0
	if _melhor_imagem != null and _obturador_teve_vida and _melhor_nota > 0.0:
		image = _melhor_imagem
	elif not captura_da_pose and _texture != null:
		image = _texture.get_image()
	_melhor_imagem = null
	_melhor_nota = -1.0
	_obturador_teve_vida = false
	if image == null or image.is_empty():
		status = "CÂMERA SEM IMAGEM — %s" % motivo_curto()
		return ""
	if _nota_da_imagem(image) <= 0.0:
		status = "IMAGEM CHAPADA — TAMPA NA LENTE"
		return ""
	ultima_foto = image
	var path := "%s/player_%d.jpg" % [PHOTO_DIR, Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PHOTO_DIR))
	WorkerThreadPool.add_task(_gravar_thumb_em_segundo_plano.bind(image.duplicate(), path, mirrored))
	status = "FOTO OK — VÍDEO CONTINUA AO VIVO"
	return path

func _gravar_thumb_em_segundo_plano(imagem: Image, path: String, espelhar: bool) -> void:
	var side := mini(imagem.get_width(), imagem.get_height())
	if side <= 0:
		return
	var origin := Vector2i((imagem.get_width() - side) / 2, (imagem.get_height() - side) / 2)
	var recorte := imagem.get_region(Rect2i(origin, Vector2i(side, side)))
	if espelhar:
		recorte.flip_x()
	recorte.resize(THUMB_SIZE, THUMB_SIZE, Image.INTERPOLATE_LANCZOS)
	recorte.save_jpg(path, 0.86)

func _parar_feed() -> void:
	if _feed != null:
		_feed.set_active(false)
	_feed = null
	_texture = null
	_last_image = null
	_last_frame_ms = 0

func _exit_tree() -> void:
	_parar_feed()
	_camera_extension = null
