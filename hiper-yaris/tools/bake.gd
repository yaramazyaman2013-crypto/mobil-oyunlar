extends Node
## Araç gövde/tekerlek mesh'lerini LOD'larıyla assets/baked/ içine kaydeder: BAKE=1 godot -- --tool=bake
@onready var g := get_parent()
func _ready() -> void:
	await get_tree().process_frame
	for m in g.MODELS:
		var t0 := Time.get_ticks_msec()
		g._make_car(m, Color(0.5, 0.5, 0.5), false, 50.0, 0.0)
		print("pişirildi ", m, " ", Time.get_ticks_msec() - t0, " ms")
	get_tree().quit()
