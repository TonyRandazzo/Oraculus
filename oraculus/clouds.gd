extends ParallaxLayer

var cloud_speed = 5


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	self.motion_offset.x += cloud_speed*delta
