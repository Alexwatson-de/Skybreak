class_name ArsenalArt
extends RefCounted
const GrenadeData=preload("res://scripts/grenade_art_data.gd")
static var grenade_textures: Dictionary={}
static var box_cache: Dictionary={}
const INK=Color("17211f")
const STEEL=Color("88968d")
const COLORS=[Color("b4bca2"),Color("c4a76d"),Color("d6a179"),Color("96b6aa"),Color("c0c09e"),Color("9dc6cb")]

static func rect(c: CanvasItem,r: Rect2,color: Color,radius: int=2) -> void:
	var key=color.to_html()+str(radius)
	if not box_cache.has(key):
		var cached=StyleBoxFlat.new();cached.bg_color=color;cached.border_color=INK;cached.set_border_width_all(2);cached.set_corner_radius_all(radius);box_cache[key]=cached
	var box: StyleBoxFlat=box_cache[key]
	c.draw_style_box(box,r)

static func gun(c: CanvasItem,index: int,transform: Transform2D) -> void:
	c.draw_set_transform_matrix(transform)
	var color=COLORS[index%6]
	if index==0:
		rect(c,Rect2(-6,-7,25,11),STEEL)
		rect(c,Rect2(15,-5,9,5),INK)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-3,1),Vector2(8,2),Vector2(4,15),Vector2(-4,15)]),Color("654c39"))
		c.draw_line(Vector2(0,-8),Vector2(13,-8),Color("dae1cc"),2,true)
		c.draw_arc(Vector2(10,5),5,0,PI,10,INK,2,true)
	else:
		var length=[0,40,49,28,59,43][index]
		c.draw_colored_polygon(PackedVector2Array([Vector2(-28,-4),Vector2(-13,-6),Vector2(-9,3),Vector2(-27,9)]),Color("675542"))
		c.draw_polyline(PackedVector2Array([Vector2(-28,-4),Vector2(-13,-6),Vector2(-9,3),Vector2(-27,9),Vector2(-28,-4)]),INK,2,true)
		rect(c,Rect2(-12,-8,30,13),color,3)
		rect(c,Rect2(14,-5,length-10,6),Color("79877f"))
		rect(c,Rect2(length+1,-6,8,8),INK)
		c.draw_line(Vector2(-7,-9),Vector2(14,-9),Color("e1d6b4"),2,true)
		c.draw_line(Vector2(-2,4),Vector2(-6,16),Color("584735"),7,true)
		c.draw_arc(Vector2(6,7),5,0,PI,10,INK,2,true)
		if index in [1,3,5]:
			c.draw_colored_polygon(PackedVector2Array([Vector2(9,4),Vector2(18,4),Vector2(15,21),Vector2(6,20)]),INK)
			c.draw_line(Vector2(10,7),Vector2(9,16),Color("6e796b"),4,true)
		for x in [-6,2,10]:
			c.draw_circle(Vector2(x,-3),1.2,Color("414e46"),true,-1,true)
			c.draw_line(Vector2(x-1,-5),Vector2(x,-5),Color("e0ddbf"),1,true)
		for x in range(18,length,6):c.draw_line(Vector2(x,-4),Vector2(x,0),Color("46574d"),1.5,true)
		c.draw_line(Vector2(length-4,-7),Vector2(length-4,-12),INK,3,true)
		c.draw_line(Vector2(-8,-11),Vector2(12,-11),Color("9c9e86"),1,true)
		if index==2:
			rect(c,Rect2(13,-3,23,11),Color("9d6a43"))
			for x in [18,23,28]:c.draw_line(Vector2(x,-1),Vector2(x,6),Color("503d2e"),1,true)
		if index in [4,5]:
			rect(c,Rect2(0,-18,25,8),INK)
			c.draw_circle(Vector2(23,-14),5,Color("7cb7b5"))
			c.draw_line(Vector2(5,-10),Vector2(5,-6),INK,3)
		if index==5:
			for x in [19,25,31]:c.draw_line(Vector2(x,-4),Vector2(x,3),Color("8fe4df"),2,true)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func grenade(c: CanvasItem,kind: int,transform: Transform2D) -> void:
	if not grenade_textures.has(kind):
		var image=Image.new()
		if image.load_svg_from_string(GrenadeData.SVG[kind])==OK:grenade_textures[kind]=ImageTexture.create_from_image(image)
	c.draw_set_transform_matrix(transform)
	if grenade_textures.has(kind):
		c.draw_texture_rect(grenade_textures[kind],Rect2(-12,-23,24,39),false)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if kind==0:
		# Cast-iron fragmentation body, segmented jacket, cap, spoon and pull ring.
		var body=PackedVector2Array([Vector2(-5,-10),Vector2(4,-10),Vector2(9,-4),Vector2(10,5),Vector2(6,13),Vector2(-5,14),Vector2(-10,7),Vector2(-10,-2)])
		c.draw_colored_polygon(body,Color("667345"));c.draw_polyline(body+PackedVector2Array([body[0]]),INK,2,true)
		for y in [-4,2,8]:c.draw_line(Vector2(-7,y),Vector2(7,y-1),Color("37462e"),1.5,true)
		for x in [-4,2]:c.draw_line(Vector2(x,-7),Vector2(x+1,11),Color("37462e"),1.5,true)
		c.draw_line(Vector2(-6,-5),Vector2(-6,6),Color("96a56c"),2,true)
		rect(c,Rect2(-4,-15,9,5),Color("909784"),1)
		c.draw_polyline(PackedVector2Array([Vector2(3,-14),Vector2(10,-13),Vector2(12,7)]),Color("b8b6a0"),3,true)
		c.draw_arc(Vector2(-7,-17),5,-1,TAU-1,18,Color("b6b9a5"),1.8,true)
	elif kind==1:
		rect(c,Rect2(-9,-11,18,25),Color("6c8073"),5)
		c.draw_line(Vector2(-7,-3),Vector2(7,-3),Color("b8c9a1"),3,true)
		c.draw_line(Vector2(-7,4),Vector2(7,4),Color("344e46"),2,true)
		rect(c,Rect2(-5,-17,10,6),Color("abb5a1"),1)
		c.draw_polyline(PackedVector2Array([Vector2(3,-15),Vector2(11,-14),Vector2(11,5)]),Color("b8b9a4"),3,true)
		c.draw_arc(Vector2(-8,-17),5,0,TAU,18,Color("c0c4b2"),1.8,true)
	else:
		rect(c,Rect2(-8,-12,17,29),Color("9a6240"),3)
		rect(c,Rect2(-6,-4,13,9),Color("dba963"),1)
		c.draw_colored_polygon(PackedVector2Array([Vector2(1,-3),Vector2(-3,2),Vector2(0,5),Vector2(4,2)]),Color("573e2e"))
		rect(c,Rect2(-4,-18,9,6),Color("9eaa98"),1)
		c.draw_polyline(PackedVector2Array([Vector2(3,-16),Vector2(11,-15),Vector2(11,8)]),Color("c1b8a0"),3,true)
		c.draw_arc(Vector2(-7,-19),5,0,TAU,18,Color("c6c2a8"),1.8,true)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

