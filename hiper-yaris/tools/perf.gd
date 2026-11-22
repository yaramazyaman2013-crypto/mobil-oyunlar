extends Node
## Sahne maliyet analizi: her grup için üçgen ve nesne sayısı. godot --headless -- --tool=perf
@onready var g := get_parent()
func _tris(mi: MeshInstance3D) -> int:
	var t := 0
	if mi.mesh == null: return 0
	for i in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(i)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() / 3) if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size() / 3
	return t
func _ready() -> void:
	await get_tree().process_frame
	var groups := {}
	var cache := {}
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree(): continue
		var key := "diğer"
		var path := String(m.get_path())
		if path.contains("Car") or path.contains("@RigidBody") or m.get_parent_node_3d() != null and m.find_parent("*") is RigidBody3D: key = "araba"
		var sp := String(m.owner.scene_file_path) if m.owner else ""
		if sp.contains("plants"): key = "bitki:" + sp.get_file()
		elif sp.contains("rocks"): key = "kaya:" + sp.get_file()
		elif sp.contains("cars"): key = "araba:" + sp.get_file()
		if not cache.has(m.mesh): cache[m.mesh] = _tris(m)
		if not groups.has(key): groups[key] = [0, 0]
		groups[key][0] += 1
		groups[key][1] += cache[m.mesh]
	var mm_all := 0
	var mm_near := 0
	var mm_nodes := 0
	var cam: Vector3 = g.player.body.global_position
	for mmi in g.find_children("*", "MultiMeshInstance3D", true, false):
		var m := mmi as MultiMeshInstance3D
		var t := 0
		var mesh := m.multimesh.mesh
		for i in mesh.get_surface_count():
			t += mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size() / 3 if mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] != null else 0
		var cnt := m.multimesh.instance_count
		mm_all += t * cnt
		mm_nodes += 1
		var center: Vector3 = m.global_transform * m.get_aabb().get_center()
		if m.visibility_range_end == 0.0 or Vector2(center.x - cam.x, center.z - cam.z).length() < m.visibility_range_end + 120.0:
			mm_near += t * cnt
	print("MultiMesh düğüm=", mm_nodes, " tüm_üçgen=", mm_all, " başlangıçta_görünür_tahmini=", mm_near)
	var total := 0
	for k in groups: total += groups[k][1]
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	for k in keys: print("%-45s nesne=%5d  üçgen=%9d" % [k, groups[k][0], groups[k][1]])
	print("TOPLAM üçgen=", total)
	get_tree().quit()
