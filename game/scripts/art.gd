class_name PilotArt
extends RefCounted
const Arsenal=preload("res://scripts/arsenal_art.gd")
const COLORS=[Color("b8ef70"),Color("ffae78"),Color("b7a0ff"),Color("70d6ed")]
const NAMES=["WREN","RIVET","VESPER","KITE"]
const ROLES=["HOODED PATHFINDER","ARMORED AUTOMATON","MASKED SHADOW RUNNER","GOGGLE-EYED AVIATOR"]
static var styles: Dictionary={}

static func pilot(c: CanvasItem,pos: Vector2,character: int,aim: float,time: float,velocity: Vector2=Vector2.ZERO,jet: bool=false,size: float=1.0,shield: bool=false,weapon: int=0,crouched: bool=false) -> void:
	character=clampi(character,0,3)
	c.draw_set_transform(pos,0,Vector2.ONE*size)
	var accent=COLORS[character]
	var side=1.0 if cos(aim)>=0 else -1.0
	var stride=sin(time*15)*minf(6,absf(velocity.x)/45)
	var bob=sin(time*4)*0.7
	var head_y=-5.0 if crouched else -17.0
	var torso_y=1.0 if crouched else -8.0
	var foot_y=14.0 if crouched else 25.0
	if shield:c.draw_arc(Vector2(0,-2),31,0,TAU,32,Color(0.7,0.95,1,0.45),1.5,true)
	if jet:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-side*19,9),Vector2(-side*10,9),Vector2(-side*15,35+sin(time*43)*8)]),Color("ffb263"))
		c.draw_line(Vector2(-side*15,9),Vector2(-side*15,25+sin(time*60)*4),Color("e0ffff"),4,true)
	# Knees fold sideways while the feet keep the authoritative floor contact.
	for leg in [-1,1]:
		var knee=Vector2(leg*10+(stride if leg<0 else -stride),foot_y-6)
		c.draw_line(Vector2(leg*5,8),knee,Color("334a50"),7,true)
		c.draw_line(knee,knee+Vector2(side*6,6),Color("172526"),6,true)
	c.draw_style_box(_box(Color("263b40"),3),Rect2(-side*15-6,torso_y-2,12,21))
	if character==0:
		# Wren: cloth hood, exposed face, scarf and a slim ranger jacket.
		c.draw_style_box(_box(Color("536b35"),4),Rect2(-10,torso_y,20,18))
		c.draw_colored_polygon(PackedVector2Array([Vector2(-12,head_y+6),Vector2(-12,head_y-8),Vector2(-5,head_y-16),Vector2(10,head_y-9),Vector2(13,head_y+7)]),Color("364d2d"))
		c.draw_circle(Vector2(side*3,head_y),8,Color("d9ae83"))
		c.draw_line(Vector2(side*3,head_y-1),Vector2(side*9,head_y-1),Color("192b24"),2,true)
		c.draw_line(Vector2(-11,torso_y),Vector2(11,torso_y),accent,5,true)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-side*8,torso_y),Vector2(-side*27,torso_y+sin(time*8)*3),Vector2(-side*21,torso_y+8)]),accent.darkened(0.25))
	elif character==1:
		# Rivet: wide metal chassis, square head, separate eye lamps and bolts.
		c.draw_style_box(_box(Color("59676a"),3),Rect2(-14,torso_y-1,28,22))
		c.draw_style_box(_box(Color("a0aaa3"),3),Rect2(-13,head_y-11,26,19))
		for x in [-7,7]:
			c.draw_circle(Vector2(x,head_y-2),3,Color("ffc77e"))
			c.draw_circle(Vector2(x*1.8,head_y+3),2,Color("3f4c50"))
		c.draw_rect(Rect2(-7,head_y+4,14,3),Color("263639"))
		c.draw_circle(Vector2(0,torso_y+8),5,accent)
		c.draw_line(Vector2(-16,torso_y+2),Vector2(-19,torso_y+11),Color("c38e5f"),7,true)
		c.draw_line(Vector2(16,torso_y+2),Vector2(19,torso_y+11),Color("c38e5f"),7,true)
	elif character==2:
		# Vesper: pointed hood, full respirator, asymmetric cape and chest straps.
		c.draw_colored_polygon(PackedVector2Array([Vector2(-side*13,torso_y-7),Vector2(-side*30,foot_y-2),Vector2(side*10,foot_y-7),Vector2(side*13,torso_y+5)]),Color("3e354f"))
		c.draw_style_box(_box(Color("675a80"),3),Rect2(-10,torso_y,20,19))
		c.draw_colored_polygon(PackedVector2Array([Vector2(-13,head_y+9),Vector2(-11,head_y-9),Vector2(0,head_y-16),Vector2(13,head_y-7),Vector2(12,head_y+9)]),Color("332c44"))
		c.draw_line(Vector2(-7,head_y-2),Vector2(8,head_y-2),Color("dfc8fc"),3,true)
		c.draw_style_box(_box(Color("86928c"),2),Rect2(-6,head_y+2,14,7))
		c.draw_line(Vector2(-8,torso_y),Vector2(8,torso_y+17),Color("b8a090"),3,true)
	else:
		# Kite: leather flight cap, twin oversized goggles, white wing pack.
		c.draw_colored_polygon(PackedVector2Array([Vector2(-side*12,torso_y),Vector2(-side*32,torso_y-6),Vector2(-side*25,torso_y+15),Vector2(-side*12,torso_y+19)]),Color("d4dfcf"))
		c.draw_style_box(_box(Color("486c7d"),4),Rect2(-11,torso_y,22,20))
		c.draw_circle(Vector2(0,head_y),11,Color("c3936e"))
		c.draw_arc(Vector2(0,head_y-1),11,PI,TAU,18,Color("795341"),6,true)
		for x in [-5,6]:
			c.draw_circle(Vector2(x,head_y-1),6,Color("273e44"))
			c.draw_circle(Vector2(x,head_y-1),4,Color("b6f0ec"))
		c.draw_line(Vector2(-8,torso_y+4),Vector2(8,torso_y+4),Color("e9e3c5"),4,true)
	var hand=Vector2(0,torso_y+5+bob)
	var dir=Vector2.from_angle(aim)
	c.draw_line(hand-Vector2(side*8,0),hand+dir*15,accent.darkened(0.2),6,true)
	c.draw_circle(hand+dir*17,3,Color("cdb594"))
	var body=Transform2D(0,pos).scaled_local(Vector2.ONE*size)
	Arsenal.gun(c,weapon,body*Transform2D(aim,hand+dir*9).scaled_local(Vector2(1,-1 if dir.x<0 else 1)))
	c.draw_set_transform(Vector2.ZERO)

static func _box(color: Color,radius: int) -> StyleBoxFlat:
	var key=color.to_html()+str(radius)
	if not styles.has(key):
		var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(radius);styles[key]=s
	return styles[key]
