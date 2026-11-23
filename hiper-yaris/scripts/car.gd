class_name Car
extends RigidBody3D
## Gerçek fizikli araba: 4 tekerlek ışın süspansiyonu (yay + amortisör), tekerlek başına
## lastik tutuşu (sürtünme dairesi), motor gücü eğrisi, fren, el freni, aerodinamik
## bastırma/sürüklenme ve görsel tekerlek dönüşü/süspansiyon hareketi.
## Araç +Z yönüne bakar; yerel +X sol taraftır.

# --- Kontrol girdileri (oyuncu ya da yapay zekâ yazar)
var throttle := 0.0      # 0..1
var brake := 0.0         # 0..1 (dururken geri vites)
var steer := 0.0         # -1 sol .. +1 sağ
var handbrake := false
var nitro_on := false

# --- Ayarlar
var power_kw := 300.0
var nitro_kw := 170.0
var max_drive_force := 12500.0
var brake_force := 15000.0
var grip_front := 1.25
var grip_rear := 1.35
var corner_stiffness := 11000.0
var downforce := 1.6
var drag := 0.42
var spring := 32000.0
var damper := 3400.0
var rest := 0.25         # bağlantı noktasının tekerlek merkezinin üstündeki yüksekliği
var droop := 0.18
var max_steer := 0.55
var steer_assist := true
var yaw_gain := 2.5        # dönüş tepkisi (süspansiyon modifiyesiyle artar)

# --- Durum
var wheels: Array = []   # {mount, radius, front, left, pivot, base_pos, to_parent, spin, base_basis, axle, up, contact, comp}
var speed := 0.0         # ileri hız (m/s)
var lat_speed := 0.0
var on_ground := 0
var steer_angle := 0.0
var slip := 0.0          # 0..1 kayma miktarı (duman/ses için)
var air_time := 0.0
var wrecked := false     # kaza modu: sürüş yardımları kapalı, araç serbestçe savrulur


func setup(wheel_specs: Array, mass_kg: float) -> void:
	mass = mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.3, 0.05)
	# Godot'nun varsayılan sönümlemesini kapat (yoksa 0.1·m·v'lik görünmez fren olur)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.6
	can_sleep = false
	continuous_cd = true
	collision_layer = 2
	collision_mask = 1 | 2 | 4     # 1 yol/zemin, 2 araçlar, 4 bariyer duvarları
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	pm.bounce = 0.15
	physics_material_override = pm
	contact_monitor = true
	max_contacts_reported = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.75, 4.3)
	shape.shape = box
	shape.position = Vector3(0, 0.78, 0)
	add_child(shape)
	wheels = wheel_specs


func _physics_process(delta: float) -> void:
	if freeze: return
	var space := get_world_3d().direct_space_state
	var up := global_basis.y.normalized()
	var fwd := global_basis.z.normalized()
	var v := linear_velocity
	speed = v.dot(fwd)
	lat_speed = v.dot(global_basis.x.normalized())
	var spd := absf(speed)

	# Hıza duyarlı direksiyon (yüksek hızda daha az açı)
	var target_angle := steer * lerpf(max_steer, 0.11, clampf(spd / 70.0, 0.0, 1.0))
	# Merkeze dönüş daha hızlı: direksiyon bırakınca araç hemen toparlar
	var returning := absf(target_angle) < absf(steer_angle) or signf(target_angle) != signf(steer_angle)
	steer_angle = move_toward(steer_angle, target_angle, delta * (3.6 if returning else 2.6))

	# Motor kuvveti (güç sınırlı)
	var kw := power_kw + (nitro_kw if nitro_on else 0.0)
	var drive := 0.0
	var reversing := brake > 0.1 and speed < 1.0 and throttle < 0.1
	if throttle > 0.0:
		drive = minf(max_drive_force * (1.35 if nitro_on else 1.0), kw * 1000.0 / maxf(spd, 6.0)) * throttle
	elif reversing:
		drive = -4500.0 * brake
		if speed < -12.0: drive = 0.0

	on_ground = 0
	slip = 0.0
	var load_sum := 0.0
	for w in wheels:
		var origin: Vector3 = global_transform * w.mount
		var length: float = rest + w.radius + droop
		var q := PhysicsRayQueryParameters3D.create(origin, origin - up * length, 1)
		var hit := space.intersect_ray(q)
		var dist := length
		w.contact = not hit.is_empty()
		if w.contact:
			dist = origin.distance_to(hit.position)
			on_ground += 1
			var comp: float = minf(length - dist, rest + droop)
			var p: Vector3 = hit.position
			var r := p - global_position
			var vel_at := v + angular_velocity.cross(r)
			var fz := spring * comp - damper * vel_at.dot(up)
			# Tampon: süspansiyon sonuna gelince sert durdur (tekerlek gövdeye girmesin)
			if comp > rest + droop - 0.08: fz += (comp - (rest + droop - 0.08)) * spring * 6.0
			fz = clampf(fz, 0.0, 40000.0)
			load_sum += fz
			apply_force(up * fz, r)
			# Tekerlek yönleri (ön tekerlekler direksiyonla döner)
			var wf := fwd
			if w.front: wf = fwd.rotated(up, -steer_angle)
			var ws := wf.cross(up).normalized()   # sağ
			var v_long := vel_at.dot(wf)
			var v_lat := vel_at.dot(ws)
			var mu: float = grip_front if w.front else grip_rear
			var stiff := corner_stiffness
			if handbrake and not w.front:
				mu *= 0.62
				stiff *= 0.45
			var max_f := mu * fz
			# Boyuna: itiş (arka %65, ön %35) ve fren
			var f_long := 0.0
			f_long += drive * (0.35 if w.front else 0.65) * 0.5
			if brake > 0.0 and not reversing:
				f_long -= signf(v_long) * minf(brake_force * brake * 0.25, absf(v_long) * mass)
			if handbrake and not w.front:
				f_long -= signf(v_long) * minf(900.0, absf(v_long) * mass * 0.25)
			f_long -= v_long * 3.0   # yuvarlanma direnci
			# Motor freni: gaz bırakılınca araç ağırlığını hissettirir
			if throttle < 0.05 and brake < 0.05 and not w.front:
				f_long -= signf(v_long) * minf(260.0, absf(v_long) * 40.0)
			# Yanal: kayma ile orantılı, sürtünme dairesiyle sınırlı
			var f_lat := -v_lat * stiff
			var total := Vector2(f_long, f_lat)
			if total.length() > max_f:
				slip = maxf(slip, clampf((total.length() - max_f) / maxf(max_f, 1.0), 0.0, 1.0))
				total = total.normalized() * max_f
			slip = maxf(slip, clampf((absf(v_lat) - 2.5) / 8.0, 0.0, 1.0))
			# Kuvveti ağırlık merkezi yüksekliğine yakın uygula: devrilmeyi azaltır
			var app := r + up * 0.25
			apply_force(wf * total.x + ws * total.y, app)
			w.spin += v_long * delta / w.radius
			if throttle > 0.5 and spd < 8.0 and not w.front: w.spin += delta * 18.0 * throttle
		else:
			w.spin += (speed / w.radius) * delta * 0.98
		w.comp = length - dist
		_update_wheel_visual(w, dist)

	# Arcade: çarpışmalarda araçlar havaya fırlamasın
	if linear_velocity.y > (9.0 if wrecked else 5.0):
		linear_velocity.y = 9.0 if wrecked else 5.0
	# Aerodinamik
	apply_central_force(-v * v.length() * drag)
	if on_ground > 0:
		apply_central_force(-up * downforce * spd * spd)

	# Kararlılık yardımı: el freni yokken fazla savrulmayı sönümle (arka dağıtmasın)
	var yaw_rate := angular_velocity.dot(up)
	if on_ground >= 2 and not handbrake and not wrecked:
		var want := -steer_angle * spd / 2.7          # bisiklet modeli hedef dönüş hızı
		var lim := 16.0 / maxf(spd, 4.0)              # lastiklerin taşıyabileceği en fazla dönüş
		want = clampf(want, -lim, lim)
		apply_torque(up * (want - yaw_rate) * mass * yaw_gain)
	# Drift yardımı (arcade): el freninde kayma açısı ~28°'de tutulur, hız aracın baktığı yöne aktarılır
	if wrecked:
		pass
	elif handbrake and on_ground >= 2 and spd > 8.0:
		var beta := atan2(lat_speed, absf(speed))
		var excess := absf(beta) - 0.42
		if excess > 0.0:
			apply_torque(up * -yaw_rate * mass * 6.0 * clampf(excess * 5.0, 0.0, 1.0))
		var lat_v := global_basis.x.normalized() * lat_speed
		linear_velocity -= lat_v * clampf(delta * 1.6, 0.0, 1.0)
		linear_velocity += fwd * lat_v.length() * clampf(delta * 1.2, 0.0, 1.0)
	elif on_ground >= 2 and spd > 8.0:
		# Drift çıkışı: büyük kayma açısını yumuşakça topla (hız kaybetmeden)
		var beta2 := atan2(lat_speed, absf(speed))
		if absf(beta2) > 0.2:
			var lat_v2 := global_basis.x.normalized() * lat_speed
			linear_velocity -= lat_v2 * clampf(delta * 2.2, 0.0, 1.0)
			linear_velocity += fwd * signf(speed) * lat_v2.length() * clampf(delta * 1.8, 0.0, 1.0)
			apply_torque(up * -yaw_rate * mass * 2.0)
	# Devrilme önleyici: yerdeyken yan yatma 20°'yi geçerse doğrult
	if on_ground >= 1 and not wrecked:
		var tilt := up.cross(Vector3.UP)
		if tilt.length() > 0.34:
			apply_torque(tilt * mass * 18.0 - angular_velocity.project(fwd) * mass * 1.5)
	# Havadayken düz kal
	if on_ground == 0 and not wrecked:
		air_time += delta
		var axis := up.cross(Vector3.UP)
		apply_torque(axis * mass * 6.0 - angular_velocity * mass * 0.8)
	else:
		air_time = 0.0


func _update_wheel_visual(w: Dictionary, dist: float) -> void:
	if w.pivot == null: return
	# Tekerlek merkezinin araç uzayındaki yüksekliği
	var center_y: float = w.mount.y - (dist - w.radius)
	# Görsel tekerlek hareketini gerçekçi süspansiyon aralığında tut
	center_y = clampf(center_y, w.base_center.y - 0.16, w.base_center.y + 0.1)
	var delta_car := Vector3(0, center_y - w.base_center.y, 0)
	var pv: Node3D = w.pivot
	pv.position = w.base_pos + w.to_parent * delta_car
	var a: float = -steer_angle if w.front else 0.0
	pv.basis = Basis(w.up, a) * Basis(w.axle, w.spin) * w.base_basis


## Pistin üzerine düzgünce geri koy.
func place(pos: Vector3, forward: Vector3, keep_speed: float) -> void:
	var t := Transform3D()
	t.basis = Basis.looking_at(-forward, Vector3.UP)   # +Z ileri olacak şekilde
	t.origin = pos + Vector3.UP * 0.05
	global_transform = t
	linear_velocity = forward * keep_speed
	angular_velocity = Vector3.ZERO
	steer_angle = 0.0
	for w in wheels: w.comp = 0.0
