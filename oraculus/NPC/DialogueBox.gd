# La casella di dialogo sopra ogni NPC. Il testo compare una lettera alla
# volta e si sente con la voce sintetica dell'NPC (vedi voce_parlante.gd):
# il tono lo decide npc_name dell'NPC che la contiene.
extends Label

@onready var label: Label = $"."

var _voce: VoceParlante

func _ready() -> void:
	var npc := get_parent()
	var nome := ""
	if npc != null and npc.get("npc_name") != null:
		nome = String(npc.get("npc_name"))
	_voce = VoceParlante.new()
	_voce.name = "Voce"
	add_child(_voce)
	_voce.configura(self, VoceSintetica.profilo(nome), true)

func show_text(text: String):

	if label == null:
		return

	if text.is_empty():
		return

	self.visible = true
	if _voce == null:
		label.text = text
		return
	_voce.dici(text)

func hide_dialogue():
	self.visible = false
