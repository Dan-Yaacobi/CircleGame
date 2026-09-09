extends Camera2D

func zoom_out(value: Vector2) -> void:
	var zoom_tween: Tween = create_tween()
	zoom_tween.tween_property(self, "zoom", zoom - value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
