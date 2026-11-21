extends Node
## Yol tutuş testi: her model için tekerlek bilgisi; 130 km/sa'da tam direksiyon ve el freni.
## godot --headless --fixed-fps 60 -- --tool=handling
var t := 0.0
var phase := 0
@onready var g := get_parent()
func _ready() -> void:
	await get_tree().process_frame
	for m in g.MODELS:
		var c: Dictionary = g._make_car(m, Color.RED, false, 50.0, 0.0)
		var b = c.body
		var info := []
		for w in b.wheels: info.append("%s r=%.2f %s" % [str(w.mount.snapped(Vector3.ONE * 0.01)), w.radius, "pivot" if w.pivot != null else "YOK"])
		print(m, ": ", info)
		b.queue_free(); c.sparks.queue_free()
	g._start_race()
	g.countdown = 0.01
	# Pistten uzak, düz test zemini
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000, 2, 4000)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -501, 0)
	g.add_child(floor_body)
func _physics_process(delta: float) -> void:
	if g.state != g.State.RACE: return
	var p: Dictionary = g.player
	var b = p.body
	t += delta
	if phase == -1: return
	if phase == 0 and b.global_position.y > -400.0:
		b.place(Vector3(0, -499.5, 0), Vector3.FORWARD, 0.0)
		return
	if phase == 0:
		b.steer = 0.0
		b.brake = 0.0
		b.throttle = 1.0 if b.speed < 36.0 else 0.0
		if b.speed >= 36.0: phase = 1; t = 0.0
	elif phase == 1:
		b.throttle = 0.5; b.steer = 1.0; b.handbrake = false
		if fmod(t, 0.5) < delta: print("TAM DİREKSİYON t=%.1f v=%d yaw=%.2f kayma_açısı=%.1f° yanal_ivme=%.1f" % [t, int(b.speed * 3.6), b.angular_velocity.y, rad_to_deg(atan2(b.lat_speed, maxf(b.speed, 1.0))), b.speed * absf(b.angular_velocity.y)])
		if t > 2.0: phase = 2; t = 0.0
	elif phase == 2:
		b.throttle = 0.6; b.steer = 1.0; b.handbrake = true
		if fmod(t, 0.5) < delta: print("EL FRENİ t=%.1f v=%d yaw=%.2f kayma_açısı=%.1f°" % [t, int(b.speed * 3.6), b.angular_velocity.y, rad_to_deg(atan2(b.lat_speed, maxf(b.speed, 1.0)))])
		if t > 1.5: phase = 3; t = 0.0
	elif phase == 3:
		b.throttle = 0.6; b.steer = 0.0; b.handbrake = false
		if fmod(t, 0.5) < delta: print("TOPARLAMA t=%.1f v=%d yaw=%.2f kayma_açısı=%.1f°" % [t, int(b.speed * 3.6), b.angular_velocity.y, rad_to_deg(atan2(b.lat_speed, maxf(b.speed, 1.0)))])
		if t > 2.0: get_tree().quit()
