extends Area2D
## Zona di morte istantanea: qualunque corpo la tocchi muore sul colpo.
##
## Non guarda chi è. Se il nodo che entra espone un metodo die() glielo chiama, e
## vale allo stesso modo per il giocatore e per qualsiasi NPC. Chi non ha die()
## (piattaforme, oggetti, proiettili) attraversa la zona senza succedere niente.
##
## Ogni corpo viene ucciso una volta sola: die() è asincrono — aspetta
## l'animazione di morte prima della schermata di sconfitta — quindi chiamarlo
## due volte sullo stesso nodo sovrapporrebbe due morti.

# Chi è già stato ucciso da questa zona. Chiave = instance id, valore = true.
var _killed: Dictionary = {}


func _on_body_entered(body: Node2D) -> void:
	_kill(body)


## Il giocatore tocca la zona anche con la sua area di rilevamento, che è un
## nodo a parte dal corpo: la morte va data a chi se la porta dietro.
func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("overlap_player"):
		return
	var victim: Node = area
	while victim != null and not victim.has_method("die"):
		victim = victim.get_parent()
	_kill(victim)


func _kill(victim: Node) -> void:
	if victim == null or not victim.has_method("die"):
		return
	var id := victim.get_instance_id()
	if _killed.has(id):
		return
	_killed[id] = true
	victim.call("die")
