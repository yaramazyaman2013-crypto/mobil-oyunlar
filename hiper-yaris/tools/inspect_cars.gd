extends SceneTree
## Araç modellerinin parça konumlarını yazar: godot --headless --script tools/inspect_cars.gd -- <dosya.glb>
func _box(n: Node) -> AABB:
	var out := AABB(); var first := true
	var list: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D: list.append(n)
	for m in list:
		var b: AABB = m.global_transform * m.get_aabb()
		out = b if first else out.merge(b); first = false
	return out
func _walk(n: Node, depth: int) -> void:
	if n is Node3D and depth <= 5:
		var b := _box(n)
		if b.size.length() > 0.0: print("  ".repeat(depth), n.name, " c=", b.get_center().snapped(Vector3.ONE * 0.01), " s=", b.size.snapped(Vector3.ONE * 0.01))
	for c in n.get_children(): _walk(c, depth + 1)
var f := 0
var nodes := {}
func _init():
	for p in OS.get_cmdline_user_args():
		var n: Node3D = load(p).instantiate(); root.add_child(n); nodes[p] = n
func _process(_d):
	f += 1
	if f == 2:
		for p in nodes: print("== ", p); _walk(nodes[p], 0)
		quit()
