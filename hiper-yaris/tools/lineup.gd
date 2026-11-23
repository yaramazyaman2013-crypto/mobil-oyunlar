extends SceneTree
## Modelleri yan yana çizer (yan görünüş, +Z sağa bakar): godot --rendering-driver vulkan --script tools/lineup.gd -- a.glb b.glb ...
var f := 0
func _init():
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.7, 0.7, 0.7)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 60, 0); root.add_child(l)
	var args := OS.get_cmdline_user_args()
	var i := 0
	for p in args:
		var n: Node3D = load(p).instantiate(); root.add_child(n)
		n.position = Vector3(0, 0, 0) + Vector3(0, 0, 0)
		n.position.x = 0.0
		n.position.y = (i % 4) * -1.8 * 0 
		n.position = Vector3(0, -(i / 4) * 2.2, (i % 4) * 6.0 - 9.0)
		var lb := Label3D.new(); lb.text = p.get_file(); lb.font_size = 64; lb.position = n.position + Vector3(0, 1.8, 0); lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; root.add_child(lb)
		i += 1
	var c := Camera3D.new(); c.projection = Camera3D.PROJECTION_ORTHOGONAL; c.size = 26.0; c.position = Vector3(30, -1.5, 0); root.add_child(c); c.rotation_degrees = Vector3(0, 90, 0)
func _process(_d):
	f += 1
	if f == 6:
		root.get_viewport().get_texture().get_image().save_png("res://build/lineup.png"); quit()
