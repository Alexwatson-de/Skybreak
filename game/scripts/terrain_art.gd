extends Node2D
const Maps=preload("res://scripts/maps.gd")
var map_id=-1

func set_map(index: int) -> void:
	if map_id==index:return
	map_id=index;queue_redraw()

func _draw() -> void:
	if map_id<0:return
	var map=Maps.data(map_id);var colors=Maps.PALETTES[map_id];var accent=Maps.ACCENTS[map_id]
	var rng=RandomNumberGenerator.new();rng.seed=200+map_id
	draw_rect(Rect2(-1600,-1000,6400,3800),colors[4].darkened(0.28))
	draw_atmosphere(colors,accent)
	# Layered rock silhouettes and stone niches give the underground negative space depth.
	for layer in range(3):
		for j in range(13):
			var x=j*310-190+layer*45;var y=90+layer*70
			var points=PackedVector2Array([Vector2(x,-500),Vector2(x+340,-500),Vector2(x+320,y+300+rng.randf()*350),Vector2(x+190,y+260+rng.randf()*350),Vector2(x+40,y+480)])
			draw_colored_polygon(points,colors[4].lightened(0.015*layer))
	for j in range(0 if map_id==3 else 25):
		var x=140+(j%8)*410+((j/8)%2)*80;var y=260+(j/8)*510
		var col=colors[1].darkened(0.63)
		draw_style_box(box(col,42),Rect2(x,y,140,240))
		draw_style_box(box(colors[4].darkened(0.18),35),Rect2(x+16,y+16,108,222))
		draw_line(Vector2(x-4,y+241),Vector2(x+147,y+241),colors[2].darkened(0.65),8,true)
		for k in range(4):draw_line(Vector2(x-2,y+72+k*43),Vector2(x+15,y+72+k*43),colors[2].darkened(0.61),2,true)
	# Soft shafts of dusty daylight enter through fractured ceilings.
	for x in [520,1670,2780]:
		draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+50,0),Vector2(x+280,1400),Vector2(x-110,1400)]),Color(accent,0.025))
	for p in map.lamps:
		for radius in [190,140,95,48]:draw_circle(p,radius,Color(accent,0.018))
	for j in range(180):
		var point=Vector2(rng.randf_range(100,3100),rng.randf_range(100,1740))
		draw_circle(point,rng.randf_range(0.5,1.5),Color(accent,rng.randf_range(0.035,0.12)))
	for piece in map.terrain:
		var points: PackedVector2Array=piece.points
		var bounds=Rect2(points[0],Vector2.ZERO)
		for v in points:bounds=bounds.expand(v)
		var stone=piece.material==1;var timber=piece.material==2
		var fill=colors[1] if not stone else colors[2].darkened(0.17)
		if timber:fill=Color("79533b")
		var shadow=PackedVector2Array()
		for v in points:shadow.append(v+Vector2(7,14))
		draw_colored_polygon(shadow,Color(0.015,0.02,0.02,0.35))
		draw_colored_polygon(points,fill)
		draw_polyline(points+PackedVector2Array([points[0]]),colors[0].darkened(0.22),5,true)
		# Grain and small mineral fragments are confined to each irregular polygon.
		var density=clampi(int(bounds.get_area()/310),10,420)
		for j in range(density):
			var p=Vector2(rng.randf_range(bounds.position.x,bounds.end.x),rng.randf_range(bounds.position.y,bounds.end.y))
			if not Geometry2D.is_point_in_polygon(p,points):continue
			var tint=fill.lightened(rng.randf_range(-0.18,0.15))
			draw_line(p,p+Vector2(rng.randf_range(2,9),rng.randf_range(-2,2)),tint,rng.randf_range(1,3),true)
		if stone:
			for y in range(int(bounds.position.y)+8,int(bounds.end.y),24):
				for x in range(int(bounds.position.x)+((y/24)%2)*21,int(bounds.end.x),48):
					var corners=[Vector2(x+3,y+2),Vector2(x+43,y+2),Vector2(x+43,y+20),Vector2(x+3,y+20)]
					var valid=true
					for v in corners:
						if not Geometry2D.is_point_in_polygon(v,points):valid=false;break
					if valid:
						draw_style_box(box(colors[2].lightened(rng.randf_range(-0.25,-0.03)),3),Rect2(x+3,y+2,40,18))
		for j in range(points.size()):
			var a=points[j];var b=points[(j+1)%points.size()]
			if b.x>a.x and absf(b.y-a.y)<absf(b.x-a.x)*0.9:
				draw_line(a,b,colors[3].darkened(0.15),5,true)
				draw_line(a+Vector2(0,7),b+Vector2(0,7),colors[0].lightened(0.1),3,true)
				if not stone:
					var count=int(a.distance_to(b)/18)
					for k in range(count):
						var point=a.lerp(b,(k+0.4)/maxf(1,count));var h=rng.randf_range(5,19)
						draw_line(point,point+Vector2(rng.randf_range(-7,7),-h),Color("667749") if map_id!=2 else Color("ad8552"),2,true)
						if k%6==0:
							draw_line(point,point+Vector2(7,-h*0.65),Color("a5ac6e") if map_id!=2 else Color("d3ab72"),2,true)
			if a.y>b.y and absf(a.y-b.y)>70 and not stone:
				for k in range(3):
					var root=a.lerp(b,float(k+1)/4)
					draw_polyline(PackedVector2Array([root,root+Vector2(16,20),root+Vector2(5,54),root+Vector2(18,68)]),colors[2].darkened(0.2),3,true)
	draw_string(ThemeDB.fallback_font,Vector2(905,1618),"LOW PASSAGE / S TO CRAWL",HORIZONTAL_ALIGNMENT_LEFT,-1,18,colors[3])
	for prop in map.props:draw_prop(Vector2(prop.x,prop.y),int(prop.z),colors)
	draw_landmarks(colors,accent)
	# Wooden mine braces and hanging chains frame the third arena.
	if map_id==2:
		for x in [460,1280,2030,2710]:
			draw_line(Vector2(x,530),Vector2(x-12,755),Color("3a302b"),18,true)
			draw_line(Vector2(x-70,535),Vector2(x+110,530),Color("514033"),21,true)
			draw_line(Vector2(x-8,550),Vector2(x+65,616),Color("5f4937"),12,true)
	for p in map.lamps:
		draw_line(p-Vector2(0,65),p-Vector2(0,20),Color("8d8169"),2,true)
		draw_style_box(box(Color("514a3b"),3),Rect2(p-Vector2(10,18),Vector2(20,36)))
		draw_rect(Rect2(p-Vector2(5,11),Vector2(10,23)),Color("eec47f"))
		draw_line(p+Vector2(-11,16),p+Vector2(11,16),Color("1e2523"),4,true)

func draw_atmosphere(colors: Array,accent: Color) -> void:
	if map_id==3:
		# Open-air outpost: layered dawn haze makes the high routes legible at a glance.
		for j in range(9):
			draw_rect(Rect2(0,j*205,3200,206),Color("6f93a0",0.055+0.012*j))
		for x in [260,980,1740,2490]:
			draw_circle(Vector2(x,180+(x%4)*37),115,Color("dce0b1",0.035))
	elif map_id==4:
		# A low desert glow frames the pyramid without relying on a copied backdrop.
		for radius in [840,640,430]:draw_circle(Vector2(1600,720),radius,Color("edc977",0.018))
		for x in range(160,3200,260):
			draw_line(Vector2(x,190),Vector2(x+180,0),Color("f4d89a",0.035),2,true)
	elif map_id==5:
		for y in [265,720,1170]:
			draw_line(Vector2(120,y),Vector2(3080,y),Color("b9d8dd",0.055),2,true)
		for x in range(180,3160,360):
			draw_circle(Vector2(x,340+(x%5)*60),85,Color(accent,0.025))
	elif map_id==0:
		for x in range(190,3150,320):
			draw_colored_polygon(PackedVector2Array([Vector2(x,80),Vector2(x+120,80),Vector2(x+190,520),Vector2(x-65,520)]),Color("d8a85f",0.016))

func draw_landmarks(colors: Array,accent: Color) -> void:
	if map_id==0:
		# Original catacomb identity: a recessed central reliquary and repeated arches.
		for y in [520,925,1325]:
			for x in [760,1600,2440]:
				draw_arc(Vector2(x,y),46,PI,TAU,20,colors[3].darkened(0.35),6,true)
				draw_line(Vector2(x-46,y),Vector2(x-46,y+44),colors[3].darkened(0.35),6,true)
				draw_line(Vector2(x+46,y),Vector2(x+46,y+44),colors[3].darkened(0.35),6,true)
		for x in [1500,1700]:
			draw_style_box(box(colors[2].darkened(0.34),4),Rect2(x,1120,82,118))
			draw_line(Vector2(x+41,1134),Vector2(x+41,1218),accent.darkened(0.1),3,true)
	elif map_id==3:
		# Distinct fortified outpost, with lookout lanterns and wind-torn flags.
		for x in [420,2025,2780]:
			draw_line(Vector2(x,420),Vector2(x,165),Color("473a2c"),13,true)
			draw_line(Vector2(x,177),Vector2(x+92,205),accent.darkened(0.22),18,true)
			draw_line(Vector2(x+8,177),Vector2(x+90,203),Color("d4c772"),2,true)
			draw_circle(Vector2(x,430),16,Color("e6c76f",0.38))
		for x in [1000,2440]:
			draw_line(Vector2(x,1510),Vector2(x+130,1390),Color("5b4933"),16,true)
			draw_line(Vector2(x+130,1390),Vector2(x+218,1510),Color("5b4933"),16,true)
	elif map_id==4:
		# Original sandstone iconography gives the hollow fortress a readable focal point.
		for y in [755,1045,1320]:
			draw_line(Vector2(1180,y),Vector2(2020,y),colors[3].darkened(0.24),3,true)
		for x in [1280,1600,1920]:
			draw_style_box(box(colors[3].darkened(0.3),3),Rect2(x-23,980,46,68))
			draw_circle(Vector2(x,1006),9,accent.darkened(0.16))
		draw_arc(Vector2(1600,1320),138,PI,TAU,32,colors[3],8,true)
		draw_line(Vector2(1462,1320),Vector2(1462,1398),colors[3],8,true)
		draw_line(Vector2(1738,1320),Vector2(1738,1398),colors[3],8,true)
	elif map_id==5:
		# Long map: rails, signal lamps and bridge seams support the high-speed lanes.
		for y in [602,1017,1502]:
			draw_line(Vector2(120,y),Vector2(3080,y),Color("25343a"),11,true)
			draw_line(Vector2(120,y-4),Vector2(3080,y-4),colors[3].darkened(0.38),2,true)
		for x in [390,880,1360,1840,2320,2810]:
			draw_line(Vector2(x,470),Vector2(x,550),Color("39474b"),9,true)
			draw_circle(Vector2(x,464),12,Color("d7c677",0.48))
			draw_line(Vector2(x-32,1495),Vector2(x+32,1495),Color("8d9fa1"),3,true)

func box(color: Color,radius: int) -> StyleBoxFlat:
	var b=StyleBoxFlat.new();b.bg_color=color;b.set_corner_radius_all(radius);return b

func draw_prop(p: Vector2,kind: int,colors: Array) -> void:
	if kind==0:
		draw_style_box(box(colors[2].darkened(0.16),12),Rect2(p-Vector2(20,62),Vector2(40,62)))
		draw_line(p+Vector2(-7,-38),p+Vector2(7,-38),colors[0],4,true)
		draw_line(p+Vector2(0,-48),p+Vector2(0,-25),colors[0],4,true)
		draw_line(p+Vector2(-25,0),p+Vector2(25,0),colors[0],7,true)
	elif kind==1:
		draw_circle(p-Vector2(0,11),12,Color("c8b58d"))
		draw_circle(p+Vector2(-4,-12),3,Color("3a322b"));draw_circle(p+Vector2(4,-12),3,Color("3a322b"))
		draw_line(p+Vector2(-8,1),p+Vector2(10,-1),Color("b4a27f"),5,true)
	elif kind==2:
		draw_style_box(box(colors[2].darkened(0.22),3),Rect2(p-Vector2(22,46),Vector2(44,46)))
		draw_style_box(box(colors[3].darkened(0.25),2),Rect2(p-Vector2(28,52),Vector2(56,9)))
		draw_line(p+Vector2(0,-60),p+Vector2(0,-160),colors[0],22,true)
		draw_line(p+Vector2(0,-55),p+Vector2(0,-160),colors[2],13,true)
	elif kind==3:
		for j in range(7):
			var root=p+Vector2(randi_range(-15,15),-1)
			draw_line(root,root+Vector2(-23+j*8,-20-absf(3-j)*4),Color("5c794e"),3,true)
	else:
		draw_style_box(box(Color("7b5b3f"),3),Rect2(p-Vector2(24,44),Vector2(48,44)))
		draw_rect(Rect2(p-Vector2(24,34),Vector2(48,5)),Color("302c27"))
		draw_rect(Rect2(p-Vector2(24,12),Vector2(48,5)),Color("302c27"))
