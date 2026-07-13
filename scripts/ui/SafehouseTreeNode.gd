extends YggdrasilNodeButton
class_name SafehouseTreeNode

var safehouse_state := "locked"
var selected := false

func _ready() -> void:
	super._ready()
	queue_redraw()

func set_safehouse_state(value: String) -> void:
	safehouse_state = value
	disabled = value == "disabled"
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not disabled:
		pressed.emit()
		accept_event()
		return
	super._gui_input(event)

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func set_state(new_state: Yggdrasil.AllocationState) -> void:
	state = new_state
	if new_state == Yggdrasil.AllocationState.ACTIVE:
		safehouse_state = "purchased"
	queue_redraw()

func _draw() -> void:
	var fill := Color("28333d")
	var edge := Color("66727d")
	match safehouse_state:
		"available":
			fill = Color("274b38")
			edge = Color("7be495")
		"unaffordable":
			fill = Color("4b352b")
			edge = Color("e6a15a")
		"purchased":
			fill = Color("244b5a")
			edge = Color("9ee3ff")
		"disabled":
			fill = Color("24282c")
			edge = Color("555b60")
	if selected:
		edge = Color("ffd166")
	draw_style_box(_panel(fill, edge, 4.0 if selected else 2.0), Rect2(Vector2.ZERO, size))

func _panel(fill: Color, edge: Color, width: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(10)
	return box
