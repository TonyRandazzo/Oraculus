# ============================================================================
# Collaudo dello streaming delle risposte.
#
# Tre livelli, dal piu' puro al piu' vivo:
#  [1] pulisci_parziale(): mentre la battuta arriva non compare mai cio' che
#      pulisci() togliera' alla fine (prefissi, token speciali, parentesi,
#      righe sporche) e non vengono aggiunti punti;
#  [2] FlussoSSE: un flusso SSE consegnato a pezzi arbitrari, anche a meta'
#      di una lettera accentata, si ricompone identico;
#  [3] il percorso completo contro il proxy (ORACULUS_API_URL, default
#      Render): i parziali arrivano prima della risposta finale. Se il proxy
#      non conosce ancora lo streaming (deploy precedente) si verifica invece
#      che il client ricada sul JSON di sempre.
#
#   godot --headless --path . res://ai/tests/stream_check.tscn
#
# Il livello [3] senza rete o senza inferenza si dichiara saltato.
# ============================================================================
extends Node

var _ko: Array[String] = []
var _ok := 0


func _ready() -> void:
	print("=".repeat(70))
	print("  COLLAUDO DELLO STREAMING")
	print("=".repeat(70))

	_test_pulisci_parziale()
	_test_flusso_sse()
	await _test_proxy()

	print("")
	if _ko.is_empty():
		print("  %d controlli superati." % _ok)
	else:
		print("  %d superati, %d FALLITI:" % [_ok, _ko.size()])
		for k in _ko:
			print("    - ", k)
	print("=".repeat(70))
	get_tree().quit(0 if _ko.is_empty() else 1)


func _check(nome: String, cond: bool, extra: String = "") -> void:
	if cond:
		_ok += 1
	else:
		_ko.append(nome + ("  (" + extra + ")" if not extra.is_empty() else ""))


func _test_pulisci_parziale() -> void:
	print("  [1] pulisci_parziale")
	var grezzo := "Levias: Sono io, Levias (il custode delle mura antiche), e tu <|eot_id|> non passerai.\nUser: ciao"

	# Il testo cresce di tre caratteri alla volta, come farebbero i token.
	var visti: Array[String] = []
	var i := 3
	while i < grezzo.length() + 3:
		visti.append(OraculusLogic.pulisci_parziale(grezzo.substr(0, i), "Levias"))
		i += 3

	var sporchi: Array[String] = []
	for p in visti:
		var inizio_ok := p.is_empty() or p.begins_with("Sono") or "Sono".begins_with(p)
		if not inizio_ok or p.contains("<") or p.contains("(") or p.contains("User"):
			sporchi.append(p)
	_check("nessun parziale mostra prefisso, token speciali, parentesi o righe sporche",
		sporchi.is_empty(), ", ".join(sporchi.slice(0, 3)))
	_check("l'ultimo parziale coincide con pulisci() sul testo completo",
		visti[-1] == OraculusLogic.pulisci(grezzo, "Levias"),
		"«%s» vs «%s»" % [visti[-1], OraculusLogic.pulisci(grezzo, "Levias")])

	_check("un prefisso a meta' non si mostra", OraculusLogic.pulisci_parziale("Lev", "Levias") == "")
	_check("gli spazi in testa non nascondono il prefisso",
		OraculusLogic.pulisci_parziale("\n Levias: Chi", "Levias") == "Chi",
		OraculusLogic.pulisci_parziale("\n Levias: Chi", "Levias"))
	_check("il parziale non chiude la frase con un punto",
		OraculusLogic.pulisci_parziale("Sono io", "Levias") == "Sono io",
		OraculusLogic.pulisci_parziale("Sono io", "Levias"))
	_check("una parentesi corta, chiusa, resta come in pulisci()",
		OraculusLogic.pulisci_parziale("Ah (ride) no", "Levias") == "Ah (ride) no")
	_check("il parziale non supera i 240 caratteri",
		OraculusLogic.pulisci_parziale("a".repeat(400), "Levias").length() == 240)


func _test_flusso_sse() -> void:
	print("  [2] FlussoSSE")
	var eventi := [
		'data: {"choices":[{"index":0,"delta":{"role":"assistant","content":"Sì, "}}]}',
		'data: {"choices":[{"index":0,"delta":{"content":null}}]}',
		'data: {"choices":[{"index":0,"delta":{"content":"è così"}}]}',
		'data: {"choices":[]}',
		': commento di keep-alive',
		'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}',
		'data: [DONE]',
		'data: {"choices":[{"index":0,"delta":{"content":" dopo DONE"}}]}',
	]
	for a_capo: String in ["\n", "\r\n"]:
		var byte := (a_capo + a_capo).join(PackedStringArray(eventi)).to_utf8_buffer()
		byte.append_array((a_capo + a_capo).to_utf8_buffer())
		var flusso := OraculusRemoteBackend.FlussoSSE.new()
		var crescite := 0
		# Un byte alla volta: "ì" ed "è" sono due byte in UTF-8, quindi
		# arrivano spezzati a meta'.
		for b in byte:
			if flusso.aggiungi(PackedByteArray([b])):
				crescite += 1
		var nome := "LF" if a_capo == "\n" else "CRLF"
		_check("%s: testo ricomposto identico byte per byte" % nome, flusso.testo == "Sì, è così",
			flusso.testo)
		_check("%s: una crescita per frammento con testo" % nome, crescite == 2, str(crescite))
		_check("%s: [DONE] chiude il flusso e ignora il resto" % nome, flusso.finito)

	var rotto := OraculusRemoteBackend.FlussoSSE.new()
	rotto.aggiungi('data: {"choices":[{"delta":{"content":"a meta"}}]}\n\ndata: {"error": "provider caduto"}\n\n'.to_utf8_buffer())
	_check("un evento di errore viene riportato", rotto.errore == "provider caduto", rotto.errore)
	_check("il testo arrivato prima dell'errore resta", rotto.testo == "a meta", rotto.testo)


func _test_proxy() -> void:
	print("  [3] percorso completo contro il proxy")
	var engine := OraculusEngine.new()
	engine.name = "OraculusEngineStream"
	add_child(engine)
	await get_tree().process_frame
	print("      url: ", engine.remote.base_url)

	# Timeout largo: Render, se dormiva, ci mette fino a un minuto a svegliarsi.
	var salute: Variant = await engine.remote._get_json(engine.remote.base_url + "/health", 90.0)
	if typeof(salute) != TYPE_DICTIONARY or String(salute.get("status", "")) != "ok":
		print("      SALTATO: il proxy non risponde (%s)" % str(salute))
		return
	if not bool(salute.get("llama", false)):
		print("      SALTATO: il proxy non ha inferenza: ", salute.get("last_error"))
		return
	var in_streaming := bool(salute.get("stream", false))

	engine._using_remote = true
	engine._available = true

	var parziali: Array = []
	var t0 := Time.get_ticks_msec()
	var on_partial := func(testo: String) -> void:
		parziali.append([Time.get_ticks_msec() - t0, testo])
	var res: Dictionary = await engine.generate_response({
		"player_input": "Chi sorveglia questo luogo?",
		"npc_name": "Levias",
		"hostility": 70,
	}, on_partial)
	var t_fine := Time.get_ticks_msec() - t0
	var finale := String(res.get("response", ""))

	print("      Levias: «%s»" % finale)
	_check("la risposta arriva dal modello, non dal fallback", res.get("source") == "llama",
		String(res.get("source", "?")))
	_check("la risposta finale non e' vuota", not finale.is_empty())

	if not in_streaming:
		print("      il proxy non dichiara \"stream\": deploy precedente, risposta intera in %d ms" % t_fine)
		_check("senza streaming lato proxy si ricade sul JSON, senza parziali", parziali.is_empty(),
			str(parziali.size()))
		return

	print("      %d aggiornamenti; primo testo a %s ms, risposta completa a %d ms" % [
		parziali.size(), str(parziali[0][0]) if not parziali.is_empty() else "-", t_fine])
	for p in parziali.slice(0, 4):
		print("        %5d ms  «%s»" % [p[0], p[1]])
	_check("arrivano piu' aggiornamenti parziali", parziali.size() >= 2, str(parziali.size()))
	if not parziali.is_empty():
		_check("il primo testo arriva prima della risposta completa", int(parziali[0][0]) < t_fine,
			"%d vs %d ms" % [parziali[0][0], t_fine])
		var sporchi := parziali.filter(func(p: Array) -> bool:
			return String(p[1]).to_lower().begins_with("levias:") or String(p[1]).contains("<|"))
		_check("nessun parziale mostra prefissi o token speciali", sporchi.is_empty(), str(sporchi))
