# Esempio di DialogueBox funzionante
extends Label

@onready var label: Label = $"."

func show_text(text: String):
	print("DEBUG DialogueBox: Mostrando testo: ", text)
	
	if label == null:
		print("ERRORE: Label è null!")
		return
	
	if text.is_empty():
		print("ERRORE: Testo vuoto ricevuto!")
		return
	
	label.text = text
	self.visible = true
	
	# Opzionale: nascondere dopo un po'
	# await get_tree().create_timer(5.0).timeout
	# self.visible = false

func hide_dialogue():
	self.visible = false
