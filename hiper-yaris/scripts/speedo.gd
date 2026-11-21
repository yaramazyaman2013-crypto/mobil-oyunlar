extends Control
## Sağ alttaki analog hız göstergesi (km/s) ve nitro halkası.

var speed_kmh := 0.0
var max_kmh := 340.0
var nitro := 0.0
var boosting := false
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	var a0 := deg_to_rad(140.0)
	var a1 := deg_to_rad(400.0)
	draw_circle(c, r + 6, Color(0, 0, 0, 0.35))
	draw_arc(c, r, a0, a1, 64, Color(1, 1, 1, 0.18), 10.0, true)
	var t := clampf(speed_kmh / max_kmh, 0.0, 1.0)
	var col := Color(0.35, 0.85, 1.0) if boosting else Color(1.0, 0.55, 0.15)
	draw_arc(c, r, a0, lerpf(a0, a1, t), 64, col, 10.0, true)
	# Tik işaretleri
	for k in 18:
		var a := lerpf(a0, a1, k / 17.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r - 18), c + d * (r - 8), Color(1, 1, 1, 0.6), 2.0, true)
	# İbre
	var na := lerpf(a0, a1, t)
	draw_line(c, c + Vector2(cos(na), sin(na)) * (r - 14), Color(1, 0.25, 0.2), 4.0, true)
	draw_circle(c, 8, Color(0.9, 0.9, 0.9))
	# Nitro iç halkası
	draw_arc(c, r * 0.62, a0, a1, 48, Color(1, 1, 1, 0.1), 6.0, true)
	draw_arc(c, r * 0.62, a0, lerpf(a0, a1, nitro), 48, Color(0.3, 0.85, 1.0, 0.9), 6.0, true)
	var txt := str(int(speed_kmh))
	draw_string_outline(font, c + Vector2(-r, r * 0.55), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 58, 8, Color(0, 0, 0, 0.7))
	draw_string(font, c + Vector2(-r, r * 0.55), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 58, Color.WHITE)
	draw_string(font, c + Vector2(-r, r * 0.85), "KM/SA", HORIZONTAL_ALIGNMENT_CENTER, r * 2, 22, Color(1, 1, 1, 0.75))
