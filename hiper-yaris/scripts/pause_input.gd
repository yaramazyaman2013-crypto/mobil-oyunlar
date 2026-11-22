extends Node
## Oyun duraklatılmışken de Esc tuşunu dinler (process_mode = ALWAYS).

signal toggle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle.emit()
		get_viewport().set_input_as_handled()
