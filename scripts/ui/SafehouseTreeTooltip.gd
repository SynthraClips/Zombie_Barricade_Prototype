extends YggdrasilTooltip
class_name SafehouseTreeTooltip

func inspect(node: YggdrasilNodeButton) -> void:
	super.inspect(node)
	call_deferred("_clamp_to_viewport")

func _clamp_to_viewport() -> void:
	reset_size()
	var viewport_size := get_viewport_rect().size
	var margin := 12.0
	global_position.x = clamp(global_position.x, margin, max(margin, viewport_size.x - size.x - margin))
	global_position.y = clamp(global_position.y, margin, max(margin, viewport_size.y - size.y - margin))
