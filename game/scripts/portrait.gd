extends Control
const Art=preload("res://scripts/art.gd")
var character=0
func _draw() -> void:
	draw_circle(size*0.5,31,Color("25392e"))
	draw_arc(size*0.5,31,0,TAU,32,Art.COLORS[character].darkened(0.35),1.5,true)
	Art.pilot(self,size*0.5+Vector2(0,3),character,-0.15,0,Vector2.ZERO,false,1.2)
