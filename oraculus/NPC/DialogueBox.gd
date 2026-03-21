# Esempio di DialogueBox funzionante
extends Label

@onready var label: Label = $"."

func show_text(text: String):
	
	if label == null:
		return
	
	if text.is_empty():
		return
	
	label.text = text
	self.visible = true
	
	# Opzionale: nascondere dopo un po'
	# await get_tree().create_timer(5.0).timeout
	# self.visible = false

func hide_dialogue():
	self.visible = false
