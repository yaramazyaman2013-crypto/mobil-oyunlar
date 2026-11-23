extends SceneTree
var f := 0
var n: Node3D
func _init():
	n = load(OS.get_cmdline_user_args()[0]).instantiate(); root.add_child(n)
func _process(_d):
	f += 1
	if f == 2:
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform * m.get_aabb()
			var mats := []
			for i in m.mesh.get_surface_count():
				var mt = m.get_active_material(i)
				mats.append(mt.resource_name if mt else "-")
			print("  %s | %s | c=%s s=%s | %s" % [m.name, m.get_parent().name, str(b.get_center().snapped(Vector3.ONE * 0.01)), str(b.size.snapped(Vector3.ONE * 0.01)), ",".join(mats)])
		quit()
