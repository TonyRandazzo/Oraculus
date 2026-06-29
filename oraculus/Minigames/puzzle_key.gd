extends Area2D

var collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.is_in_group("player") or body.name == "Player":
		collected = true
		GameState.collect_puzzle_key()
		queue_free()
