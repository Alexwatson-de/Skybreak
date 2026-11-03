extends Node2D
const Maps=preload("res://scripts/maps.gd")
const TerrainArt=preload("res://scripts/terrain_art.gd")
var map_id=-1
var surface: SubViewport
var image: Sprite2D

func set_map(index: int) -> void:
	if map_id==index:return
	map_id=index
	if is_instance_valid(image):image.visible=false;image.queue_free()
	if is_instance_valid(surface):surface.queue_free()
	# Thousands of static dirt/brick/grass strokes are rasterized once per map,
	# then camera motion draws one texture. Only the active map stays allocated.
	surface=SubViewport.new()
	surface.size=Vector2i(Maps.WIDTH,Maps.HEIGHT)
	surface.disable_3d=true
	surface.transparent_bg=true
	surface.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(surface)
	var art=TerrainArt.new()
	surface.add_child(art)
	art.set_map(index)
	image=Sprite2D.new()
	image.centered=false
	image.texture=surface.get_texture()
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(image)
	queue_redraw()

func _draw() -> void:
	if map_id>=0:draw_rect(Rect2(-1600,-1000,6400,3800),Maps.PALETTES[map_id][4].darkened(0.28))
