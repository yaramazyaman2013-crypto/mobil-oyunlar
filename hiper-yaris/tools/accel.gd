extends Node
## Düz çizgi hızlanma testi: godot --headless --fixed-fps 60 -- --tool=accel
var t := 0.0
@onready var g := get_parent()
func _ready() -> void:
	await get_tree().process_frame
	g._start_race()
	g.countdown = 0.01
func _physics_process(delta: float) -> void:
	if g.state != g.State.RACE: return
	t += delta
	var b = g.player.body
	b.throttle = 1.0
	b.steer = 0.0
	b.brake = 0.0
	g.autopilot = false
	if fmod(t, 1.0) < delta:
		var fz := 0.0
		print("t=%.0f v=%.1f km/h=%d zemin=%d y=%.2f pitch=%.3f kayma=%.2f lat=%.2f" % [t, b.speed, int(b.speed * 3.6), b.on_ground, b.global_position.y, b.global_basis.z.y, b.slip, b.lat_speed])
	if t > 12.0: get_tree().quit()
