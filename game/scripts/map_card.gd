extends Button
const Maps=preload("res://scripts/maps.gd")
var map_id=0
var selected=false
var font=ThemeDB.fallback_font
func _ready() -> void:
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
func _draw() -> void:
	var box=StyleBoxFlat.new();box.bg_color=Color("283124") if selected else Color("1c251e");box.border_color=Color("d8b878") if selected else Color("515844");box.set_border_width_all(2 if selected else 1);box.set_corner_radius_all(9)
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	var map=Maps.data(map_id);var col=Maps.PALETTES[map_id]
	for terrain in map.terrain:
		var points=PackedVector2Array()
		for v in terrain.points:points.append(Vector2(12,10)+Vector2(v.x/Maps.WIDTH*(size.x-24),v.y/Maps.HEIGHT*76))
		draw_colored_polygon(points,col[2].darkened(0.15))
	draw_rect(Rect2(1,91,size.x-2,size.y-92),Color("20281f"))
	draw_string(font,Vector2(14,116),Maps.NAMES[map_id],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ecdbb7") if selected else Color("b9c2a7"))
	draw_string(font,Vector2(14,136),["CATACOMBS / 3 LEVELS","TEMPLE / VERTICAL ROUTES","MINE / OPEN SHAFTS"][map_id],HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("8f9d81"))
	if is_hovered():draw_rect(Rect2(Vector2.ZERO,size),Color(1,0.9,0.65,0.04))
