extends Control
## Sağ üstteki mini harita: pist çizgisi, rakipler (beyaz) ve oyuncu (turuncu).

var game: Node
var _pts := PackedVector2Array()
var _min := Vector2.ZERO
var _scale := 1.0
var _offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(track: Track) -> void:
	_pts.clear()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in range(0, track.pos.size(), 6):
		var p := Vector2(track.pos[i].x, track.pos[i].z)
		_pts.append(p)
		mn = mn.min(p)
		mx = mx.max(p)
	_min = mn
	var span := mx - mn
	var pad := 14.0
	_scale = minf((size.x - pad * 2) / span.x, (size.y - pad * 2) / span.y)
	_offset = Vector2(pad, pad) + ((size - Vector2(pad, pad) * 2) - span * _scale) * 0.5
	for i in _pts.size(): _pts[i] = _map(_pts[i])


func _map(p: Vector2) -> Vector2:
	return (p - _min) * _scale + _offset


func _process(_d: float) -> void:
	if is_visible_in_tree(): queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	if _pts.size() < 2: return
	var closed := _pts.duplicate()
	closed.append(_pts[0])
	draw_polyline(closed, Color(0, 0, 0, 0.6), 7.0, true)
	draw_polyline(closed, Color(0.85, 0.85, 0.85, 0.9), 3.5, true)
	draw_circle(_pts[0], 4.0, Color(1, 1, 1))
	if game == null: return
	for c in game.cars:
		if c.player: continue
		var p: Vector3 = c.body.global_position
		draw_circle(_map(Vector2(p.x, p.z)), 4.0, Color(0.95, 0.95, 0.95))
	var pp: Vector3 = game.player.body.global_position
	draw_circle(_map(Vector2(pp.x, pp.z)), 7.0, Color(0, 0, 0, 0.7))
	draw_circle(_map(Vector2(pp.x, pp.z)), 5.5, Color(1.0, 0.55, 0.1))
