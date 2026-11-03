class_name PilotArt
extends RefCounted
const Arsenal=preload("res://scripts/arsenal_art.gd")
const COLORS=[Color("b8ef70"),Color("ffae78"),Color("b7a0ff"),Color("70d6ed")]
const NAMES=["WREN","RIVET","VESPER","KITE"]
const ROLES=["RELAY SCOUT","FORGE RUNNER","NIGHT SIGNAL","ORBIT RANGER"]

static func pilot(c: CanvasItem, pos: Vector2, character: int, aim: float, time: float, velocity: Vector2=Vector2.ZERO, jet: bool=false, size: float=1.0, shield: bool=false, weapon: int=0) -> void:
	c.draw_set_transform(pos,0,Vector2.ONE*size)
	var accent=COLORS[character%4]
	var side=1.0 if cos(aim)>=0 else -1.0
	var stride=sin(time*15)*minf(8,absf(velocity.x)/35)
	var bob=sin(time*3)*1.2 if velocity.length()<10 else sin(time*20)*1.4
	if shield: c.draw_arc(Vector2(0,-3),37,0,TAU,40,Color(0.7,0.95,1,0.4+sin(time*8)*0.2),1.5,true)
	if jet:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-side*19,8),Vector2(-side*11,8),Vector2(-side*16,35+sin(time*43)*9)]),Color("ffb263"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(-side*18,9),Vector2(-side*13,9),Vector2(-side*16,25+sin(time*63)*5)]),Color("d8f9fd"))
	# Pack, articulated boots, jacket, helmet and visor are all original vector art.
	c.draw_style_box(_box(Color("263b4d"),4),Rect2(-side*17-7,-14,14,25))
	c.draw_line(Vector2(-6,8),Vector2(-8+stride,25),Color("263b4d"),9,true)
	c.draw_line(Vector2(6,8),Vector2(8-stride,25),Color("3c5364"),9,true)
	c.draw_line(Vector2(-10+stride,25),Vector2(-2+stride,25),Color("121f2d"),6,true)
	c.draw_line(Vector2(4-stride,25),Vector2(13-stride,25),Color("121f2d"),6,true)
	c.draw_style_box(_box(accent.darkened(0.22),5),Rect2(-12,-15+bob,24,27))
	c.draw_line(Vector2(-9,-1+bob),Vector2(10,-1+bob),accent,5,true)
	c.draw_line(Vector2(-6,12),Vector2(9,12),Color("162533"),5,true)
	c.draw_circle(Vector2(0,-26+bob),16,Color("172b3b"),true,-1,true)
	c.draw_arc(Vector2(0,-26+bob),16,PI,TAU,20,accent,4,true)
	c.draw_style_box(_box(Color("b7c7b0"),4),Rect2(-10 if side<0 else -2,-31+bob,16,8))
	c.draw_line(Vector2(side*1,-30+bob),Vector2(side*10,-30+bob),Color("f1e5c3"),2,true)
	if character==0:
		c.draw_line(Vector2(-9,-39+bob),Vector2(-14,-48+bob),accent,4,true)
	elif character==1:
		c.draw_circle(Vector2(-side*11,-26+bob),6,Color("fcbb7c"))
	elif character==2:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-14,-16),Vector2(-side*30,12),Vector2(-12,7)]),accent.darkened(0.42))
	else:
		c.draw_line(Vector2(side*10,-36),Vector2(side*14,-48),accent,2,true)
		c.draw_circle(Vector2(side*14,-48),3,Color("ecffff"))
	var hand=Vector2(0,-7+bob)
	var dir=Vector2.from_angle(aim)
	c.draw_line(hand-Vector2(side*8,0),hand+dir*15,accent,7,true)
	c.draw_circle(hand+dir*17,4,Color("cdb594"))
	var body=Transform2D(0,pos).scaled_local(Vector2.ONE*size)
	Arsenal.gun(c,weapon,body*Transform2D(aim,hand+dir*9).scaled_local(Vector2(1,-1 if dir.x<0 else 1)))
	c.draw_set_transform(Vector2.ZERO)

static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	return s
