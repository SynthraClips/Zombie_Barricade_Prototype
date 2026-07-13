extends YggdrasilConnection
class_name SafehouseTreeConnection

func _ready() -> void:
	width = 6.0
	default_color = Color("53616b")
	# The Yggdrasil tree already places the lines container below nodes. A
	# negative child z-index drops lines behind the tree background entirely.
	z_index = 0
