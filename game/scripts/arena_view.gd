extends Node2D
const ArenaMaps=preload("res://scripts/maps.gd")
const GameSim=preload("res://scripts/sim.gd")
const PilotArt=preload("res://scripts/art.gd")
const Arsenal=preload("res://scripts/arsenal_art.gd")
var main: Node
var terrain: Node2D
var detail_scale=1.0
var panel_styles: Dictionary={}
var camera=Vector2(800,550)
var zoom=0.94
var origin=Vector2.ZERO
var particles: Array=[]
var feed: Array=[]
var time=0.0
var hurt_flash=0.0
var pickup_label=""
var pickup_until=0.0
var font=ThemeDB.fallback_font
var touch_points: Dictionary={}
var touch_aim=Vector2.ZERO

const TOUCH_STICK=Vector2(150,760)
const TOUCH_JUMP=Vector2(1265,596)
const TOUCH_JET=Vector2(1350,680)
const TOUCH_FIRE=Vector2(1175,594)
const TOUCH_CROUCH=Vector2(330,790)
const TOUCH_GRENADE=Vector2(1090,730)
const TOUCH_RELOAD=Vector2(990,730)
const TOUCH_PICKUP=Vector2(890,730)

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		set_process(false)
		return
	terrain=load("res://scripts/terrain_cache.gd").new()
	terrain.show_behind_parent=true
	add_child(terrain)
	Net.effects.connect(_effects)

func _effects(events: Array) -> void:
	for event in events:
		var e=event.duplicate();e.age=0.0
		if e.kind=="kill":
			feed.push_front(e)
			if feed.size()>4:feed.pop_back()
		elif e.kind=="pickup":
			if e.id==Net.local_id:pickup_label=e.label;pickup_until=time+2.4
		else:particles.append(e)
		var weight=0.8 if e.get("by",0)==Net.local_id else 0.25
		match e.kind:
			"shot":main.audio.play("gun_"+str(int(e.weapon)),weight)
			"boom":main.audio.play("boom",0.6)
			"hit":
				if e.id==Net.local_id:hurt_flash=0.3
				if e.by==Net.local_id:main.audio.play("hit",0.6)

func _process(delta: float) -> void:
	time+=delta;hurt_flash=maxf(0,hurt_flash-delta)
	for p in particles:p.age+=delta
	particles=particles.filter(func(p):return p.age<(0.12 if p.kind=="shot" else 0.7))
	for e in feed:e.age+=delta
	feed=feed.filter(func(e):return e.age<5)
	var playing=Net.active and Net.state.get("phase","") in ["match","results"]
	var index=Net.map_id if Net.active else main.selected_map
	terrain.set_map(index,detail_scale)
	if playing:
		zoom=0.94
		var players=Net.render_players();var local=players.get(Net.local_id,{})
		if not local.is_empty():camera=camera.lerp(local.p,1-exp(-8*delta))
		camera.x=clampf(camera.x,720/zoom,ArenaMaps.WIDTH-720/zoom)
		camera.y=clampf(camera.y,345/zoom,ArenaMaps.HEIGHT-345/zoom)
		origin=Vector2(720,345)-camera*zoom
	else:
		zoom=0.53;origin=Vector2(1000,435)-Vector2(1690,870)*zoom
	terrain.position=origin;terrain.scale=Vector2.ONE*zoom
	update_touch_intent(playing)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not main.mobile_controls_active(): return
	if event is InputEventScreenTouch:
		if event.pressed: touch_points[event.index]=event.position
		else: touch_points.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		touch_points[event.index]=event.position
		get_viewport().set_input_as_handled()

func in_touch_button(point: Vector2, center: Vector2, radius: float=46.0) -> bool:
	return point.distance_to(center)<=radius

func update_touch_intent(playing: bool) -> void:
	if not main.mobile_controls_active(): return
	var intent=GameSim.blank()
	if not playing or main.paused:
		main.controls.touch_intent=intent
		return
	var stick=Vector2.ZERO
	var aiming=false
	var selected_weapon=-1
	for point in touch_points.values():
		# Weapon cells remain reachable through the lower HUD.
		if point.y>=795 and point.y<=890 and point.x>=304 and point.x<1060:
			selected_weapon=clampi(int((point.x-304)/124),0,5)
			continue
		if in_touch_button(point,TOUCH_JUMP): intent.jump=true;continue
		if in_touch_button(point,TOUCH_JET): intent.jet=true;continue
		if in_touch_button(point,TOUCH_CROUCH): intent.crouch=true;continue
		if in_touch_button(point,TOUCH_GRENADE): intent.grenade=true;continue
		if in_touch_button(point,TOUCH_RELOAD): intent.reload=true;continue
		if in_touch_button(point,TOUCH_PICKUP): intent.interact=true;continue
		if point.x<430 and point.y>570:
			stick=(point-TOUCH_STICK)/92.0
			continue
		# A free touch on the right half aims and fires. This preserves two-thumb
		# movement + firing while allowing the action buttons to be held separately.
		if point.x>470:
			touch_aim=point;aiming=true;intent.fire=true
	if selected_weapon>=0: main.controls.weapon=selected_weapon
	intent.x=clampf(stick.x,-1.0,1.0)
	if stick.y<-0.42: intent.jump=true
	if stick.y>0.54: intent.crouch=true
	var local=Net.render_players().get(Net.local_id,{})
	if aiming and not local.is_empty():
		intent.aim=(touch_aim-(origin+local.p*zoom)).angle()
	elif not local.is_empty(): intent.aim=float(local.get("aim",0.0))
	main.controls.touch_intent=intent

func touch_button(center: Vector2, radius: float, text: String, active: bool=false) -> void:
	var fill=Color("e1b96f",0.74) if active else Color("17231b",0.88)
	draw_circle(center,radius,fill)
	draw_arc(center,radius,0,TAU,40,Color("f3d99d") if active else Color("718069"),2.0,true)
	var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_CENTER,-1,13).x
	text_at(center+Vector2(-width/2,5),text,13,Color("25291d") if active else Color("e4e0c8"))

func touch_controls() -> void:
	if not main.mobile_controls_active() or not Net.active or Net.state.get("phase","")!="match": return
	var stick=Vector2.ZERO
	for point in touch_points.values():
		if point.x<430 and point.y>570: stick=(point-TOUCH_STICK).limit_length(70)
	draw_circle(TOUCH_STICK,76,Color("101810",0.45));draw_arc(TOUCH_STICK,76,0,TAU,36,Color("8f9c7a",0.65),2,true)
	draw_circle(TOUCH_STICK+stick,29,Color("d8bd7b",0.72))
	touch_button(TOUCH_JUMP,42,"JUMP")
	touch_button(TOUCH_JET,45,"JET",main.controls.touch_intent.get("jet",false))
	touch_button(TOUCH_FIRE,45,"FIRE",main.controls.touch_intent.get("fire",false))
	touch_button(TOUCH_CROUCH,38,"CROUCH",main.controls.touch_intent.get("crouch",false))
	touch_button(TOUCH_GRENADE,37,"GRENADE",main.controls.touch_intent.get("grenade",false))
	touch_button(TOUCH_RELOAD,35,"RELOAD",main.controls.touch_intent.get("reload",false))
	touch_button(TOUCH_PICKUP,35,"PICK UP",main.controls.touch_intent.get("interact",false))

func text_at(pos: Vector2,text: String,size: int=16,color: Color=Color("d8d5be")) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2,color: Color=Color("202720"),border: Color=Color("545747"),radius: int=10) -> void:
	var key=color.to_html()+border.to_html()+str(radius)
	if not panel_styles.has(key):
		var style=StyleBoxFlat.new();style.bg_color=color;style.border_color=border;style.set_border_width_all(1);style.set_corner_radius_all(radius);panel_styles[key]=style
	draw_style_box(panel_styles[key],rect)

func world_transform(point: Vector2,scale_value: float=1,angle: float=0) -> Transform2D:
	return Transform2D(angle,origin+point*zoom).scaled_local(Vector2.ONE*zoom*scale_value)

func _draw() -> void:
	if not is_instance_valid(terrain):return
	var playing=Net.active and Net.state.get("phase","") in ["match","results"]
	var index=Net.map_id if Net.active else main.selected_map
	var map=ArenaMaps.data(index);var accent=ArenaMaps.ACCENTS[index]
	var world=Transform2D(0,origin).scaled_local(Vector2.ONE*zoom)
	if not playing:
		# Warm, quiet surfaces let the illustrated arena do the work.
		draw_rect(Rect2(0,0,1440,900),Color(0.05,0.065,0.052,0.28))
		for j in range(24):draw_rect(Rect2(j*28,0,29,900),Color(0.065,0.078,0.063,clampf(0.92-j*0.036,0,0.92)))
		if main.screen in ["menu","lan"]:
			text_at(Vector2(625,174),"BATTLEFIELD / 0"+str(index+1),12,accent)
			text_at(Vector2(625,213),ArenaMaps.NAMES[index],33,Color("f0e5cb"))
			text_at(Vector2(625,242),ArenaMaps.SUBTITLES[index],14,Color("b9b99e"))

		if main.screen=="character":
			panel(Rect2(594,138,786,638),Color(0.09,0.115,0.09,0.92),Color("505848"))
			draw_circle(Vector2(1005,479),190,Color(accent,0.035))
			draw_arc(Vector2(1005,479),190,0,TAU,80,Color(accent,0.22),1.5,true)
			PilotArt.pilot(self,Vector2(1005,475),main.selected_character,-0.14,time,Vector2.ZERO,true,4.2,false,1)
			text_at(Vector2(665,705),PilotArt.NAMES[main.selected_character],38,Color("f0e5cb"))
			text_at(Vector2(665,738),PilotArt.ROLES[main.selected_character]+" / JETPACK OPERATOR",13,accent)
		elif main.screen=="online":
			panel(Rect2(594,138,786,638),Color(0.09,0.115,0.09,0.92),Color("505848"))
			PilotArt.pilot(self,Vector2(1005,450),main.selected_character,-0.12,time,Vector2.ZERO,true,4.8,false,1)
			text_at(Vector2(666,650),PilotArt.NAMES[main.selected_character],40,Color("f0e5cb"))
			text_at(Vector2(666,689),PilotArt.ROLES[main.selected_character],15,accent)
			text_at(Vector2(666,738),"ROOM CODES / INVITE LINKS / 2–8 PILOTS",13,Color("aab89b"))
		elif main.screen=="armory":draw_armory()
		return
	# Live supplies, clearly readable silhouettes, with grounded weapon racks.
	for j in range(map.loot.size()):
		var item=map.loot[j];var available=Net.state.pickups[j]<=0;var p: Vector2=item.p
		draw_set_transform_matrix(world)
		if item.kind=="gun":
			draw_line(p+Vector2(-32,24),p+Vector2(35,24),Color("252d25"),11,true)
			draw_line(p+Vector2(-27,19),p+Vector2(30,19),Color("997e51"),3,true)
			if not available:
				text_at(p+Vector2(-20,0),str(ceili(Net.state.pickups[j]))+"s",12,Color("857f67"));continue
			draw_circle(p,40,Color(accent,0.05))
			Arsenal.gun(self,int(item.item),world_transform(p+Vector2(-4,sin(time*2+j)*3),0.78))
		else:
			if not available:continue
			draw_circle(p,27,Color(accent,0.045))
			if item.kind=="grenade":Arsenal.grenade(self,int(item.item),world_transform(p,1.25))
			else:
				panel(Rect2(p-Vector2(17,12),Vector2(34,27)),Color("8a8b65"),Color("2e382b"),4)
				draw_line(p-Vector2(8,0),p+Vector2(8,0),Color("efe1bc"),5,true)
				draw_line(p-Vector2(0,8),p+Vector2(0,8),Color("efe1bc"),5,true)
	draw_set_transform_matrix(world)
	for g in Net.state.grenades:
		if g.burn:
			for j in range(13):
				var point=g.p+Vector2(-90+j*15,8)
				var h=12+sin(time*12+j*2.7)*7+absf(sin(j*12.4))*19
				draw_colored_polygon(PackedVector2Array([point-Vector2(8,0),point+Vector2(8,0),point+Vector2(sin(time*7+j)*6,-h)]),Color(0.93,0.48,0.18,0.7))
				draw_line(point,point+Vector2(2,-h*0.6),Color("f8d47b"),3,true)
		else:
			Arsenal.grenade(self,int(g.type),world_transform(g.p,0.7,time*5+g.by))
			draw_set_transform_matrix(world)
	for p in particles:
		if p.kind=="shot":
			draw_line(p.from,p.to,Color(1,0.86,0.57,maxf(0,1-p.age/0.12)),1.8,true)
			draw_circle(p.from,6*(1-p.age/0.12),Color("ffe9a9"))
		elif p.kind=="boom":
			var col=Color("e89145") if int(p.get("type",0))!=1 else Color("f2d491")
			draw_circle(p.p,20+p.age*160,Color(col,maxf(0,0.42-p.age)))
			draw_arc(p.p,15+p.age*220,0,TAU,48,Color(col,1-p.age/0.7),4,true)
			for j in range(11):
				var point=p.p+Vector2.from_angle(j*TAU/11)*p.age*230
				draw_circle(point,4*(1-p.age/0.7),Color("edd5a2"))
		elif p.kind=="hit":
			for j in range(5):draw_line(p.p,p.p+Vector2.from_angle(j*1.24)*p.age*95,Color(0.89,0.72,0.47,1-p.age/0.7),1.5,true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var players=Net.render_players()
	for p in players.values():
		if p.hp<=0:continue
		var point=origin+p.p*zoom
		PilotArt.pilot(self,point,int(p.char),p.aim,time,p.v,p.jet,zoom,p.shield>0,int(p.weapon),p.get("crouched",false))
		var color=Color("e9c785") if p.id==Net.local_id else (Color("a5c5bb") if p.team==0 else Color("e6a17c"))
		text_at(point+Vector2(-22,-54),p.name,12,color if p.online else Color("877f6c"))
		draw_rect(Rect2(point+Vector2(-20,-47),Vector2(40,3)),Color("33372e"))
		draw_rect(Rect2(point+Vector2(-20,-47),Vector2(p.hp*0.4,3)),color)
	hud(players.get(Net.local_id,{}),map)
	touch_controls()

func draw_armory() -> void:
	var item=main.selected_armory
	panel(Rect2(594,138,786,638),Color(0.09,0.115,0.09,0.97),Color("505848"))
	if item<6:
		text_at(Vector2(645,190),"FIELD ARMORY / 0"+str(item+1),12,Color("e5b66b"))
		text_at(Vector2(645,234),GameSim.WEAPONS[item],35,Color("f2e5c8"))
		Arsenal.gun(self,item,Transform2D(0,Vector2(922,400)).scaled_local(Vector2.ONE*6))
		for j in range(3):
			var x=645+j*225
			panel(Rect2(x,560,205,90),Color("242d24"),Color("444c3e"),6)
			text_at(Vector2(x+17,586),["DAMAGE","MAGAZINE","RELOAD"][j],11,Color("a1aa91"))
			text_at(Vector2(x+17,627),[str(GameSim.DAMAGE[item]),str(GameSim.CLIP[item]),str(GameSim.RELOAD[item])+" s"][j],29,Color("f1dfb8"))
		text_at(Vector2(645,710),"START WITH THE SABLE. SCAVENGE THE REST.",15,Color("e5b66b"))
		text_at(Vector2(645,741),"Look for weapon racks, then press E to pick up a gun.",16)
	else:
		var kind=item-6
		text_at(Vector2(645,190),"ORDNANCE / 0"+str(kind+1),12,Color("e5b66b"))
		text_at(Vector2(645,234),GameSim.GRENADE_NAMES[kind]+" GRENADE",35,Color("f2e5c8"))
		Arsenal.grenade(self,kind,Transform2D(-0.13,Vector2(990,408)).scaled_local(Vector2.ONE*5.8))
		text_at(Vector2(645,631),["Timed blast. Bounces off stone and earth.","Detonates when it strikes the terrain.","Creates a burning patch that denies a route."][kind],21,Color("e8d4af"))
		text_at(Vector2(645,705),"G  THROW     /     Q  CHANGE GRENADE",15,Color("e5b66b"))
		text_at(Vector2(645,738),"Collect grenade supplies around the battlefield.",16)

func hud(local: Dictionary,map: Dictionary) -> void:
	draw_rect(Rect2(0,690,1440,210),Color("151f18"))
	var state=Net.state;var amber=Color("e8bf79")
	panel(Rect2(552,18,336,75),Color(0.07,0.09,0.07,0.94),Color("535542"))
	var remaining=int(state.remaining)
	text_at(Vector2(678,53),"%02d:%02d"%[remaining/60,remaining%60],26,Color("f0e6cb"))
	text_at(Vector2(608,78),"TEAM DEATHMATCH" if state.mode==1 else "DEATHMATCH / FIRST TO 15",12,Color("b9bda5"))
	if state.mode==1:
		text_at(Vector2(578,56),str(state.scores[0]),29,Color("a5c5bb"));text_at(Vector2(837,56),str(state.scores[1]),29,Color("e6a17c"))
	text_at(Vector2(28,35),ArenaMaps.NAMES[Net.map_id],18,Color("e7d9b9"))
	text_at(Vector2(28,59),"LOCAL MATCH" if Net.is_host else "CONNECTED / "+str(Net.ping_ms)+" ms",11,Color("aab99b"))
	if not local.is_empty():
		main.audio.set_jet(local.jet and local.hp>0)
		panel(Rect2(22,758,272,118),Color(0.07,0.09,0.07,0.94),Color("535542"))
		text_at(Vector2(40,786),local.name,15,Color("e7d9b9"))
		text_at(Vector2(40,824),str(local.hp),32,Color("c6d6a0"))
		text_at(Vector2(96,822),"HEALTH",10,Color("9ca98d"))
		draw_rect(Rect2(40,836,236,6),Color("3a4232"));draw_rect(Rect2(40,836,236*local.hp/100.0,6),Color("b9cf8c"))
		text_at(Vector2(40,860),"JET",10,Color("8fae9e"))
		draw_rect(Rect2(70,852,206,4),Color("3a4232"));draw_rect(Rect2(70,852,206*local.fuel/100.0,4),Color("9fbca9"))
		for j in range(6):
			var x=316+j*124;var chosen=int(local.weapon)==j
			panel(Rect2(x,806,115,70),Color("30372a") if chosen else Color(0.07,0.09,0.07,0.91),amber if chosen else Color("414a3a"),7)
			Arsenal.gun(self,j,Transform2D(0,Vector2(x+46,837)).scaled_local(Vector2.ONE*0.73))
			if not local.owned[j]:draw_rect(Rect2(x+1,807,113,68),Color(0.08,0.1,0.08,0.79))
			text_at(Vector2(x+9,823),str(j+1),11,amber if chosen else Color("929c85"))
			text_at(Vector2(x+9,866),str(local.ammo[j]) if local.owned[j] else "FIND IN ARENA",10,Color("d8d7bb") if local.owned[j] else Color("7d8875"))
		panel(Rect2(1100,758,318,118),Color(0.07,0.09,0.07,0.94),Color("535542"))
		text_at(Vector2(1119,787),GameSim.WEAPONS[int(local.weapon)],14,amber)
		text_at(Vector2(1119,836),str(local.ammo[local.weapon]),39,Color("f2e5c8"))
		text_at(Vector2(1185,834),"/ "+str(local.reserve[local.weapon]),20,Color("a0aa91"))
		text_at(Vector2(1119,860),"R  RELOAD  /  Q  GRENADE TYPE",11,Color("99a68c"))
		for j in range(3):
			var x=1100+j*106
			panel(Rect2(x,692,98,53),Color(0.07,0.09,0.07,0.93),amber if local.grenade_type==j else Color("414a3a"),7)
			Arsenal.grenade(self,j,Transform2D(0,Vector2(x+24,718)).scaled_local(Vector2.ONE*0.82))
			text_at(Vector2(x+48,716),str(local.grenade_ammo[j]),19,Color("e7d9b9"))
			text_at(Vector2(x+42,734),["FRAG","IMPACT","FIRE"][j],9,Color("a9ad94"))
		var nearest: Dictionary={};var distance=78.0
		for j in range(map.loot.size()):
			var item=map.loot[j];var d=local.p.distance_to(item.p)
			if item.kind=="gun" and state.pickups[j]<=0 and d<distance:nearest=item;distance=d
		if not nearest.is_empty() and local.hp>0:
			panel(Rect2(480,700,480,49),Color(0.08,0.11,0.08,0.96),amber,8)
			text_at(Vector2(505,732),"E   PICK UP "+GameSim.WEAPONS[nearest.item],18,Color("f1ddaf"))
		elif time<pickup_until:text_at(Vector2(520,732),"COLLECTED / "+pickup_label,17,amber)
		if local.reload>0:text_at(Vector2(650,534),"RELOADING",16,amber)
		if local.hp<=0:
			panel(Rect2(480,340,480,145),Color(0.07,0.09,0.07,0.97),Color("736349"))
			text_at(Vector2(543,390),"BACK IN THE FIGHT SOON",25,Color("ebc68c"))
			text_at(Vector2(605,430),"Respawning in %.1f s"%maxf(0,local.dead),21)
			text_at(Vector2(576,461),"New drop. New route. Go again.",15,Color("a7b093"))
	if Input.is_physical_key_pressed(KEY_TAB) or state.phase=="results":scoreboard()
	else:text_at(Vector2(320,786),"SPACE JUMP    W JETPACK    S / CTRL CROUCH    E PICK UP    G GRENADE    TAB SCORE",11,Color("b8b99c"))
	for j in range(feed.size()):text_at(Vector2(1140,115+j*24),feed[j].killer+"  >  "+feed[j].victim,13,Color("d8d8bd"))
	var cursor=get_viewport().get_mouse_position()
	if not main.paused:
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:draw_line(cursor+direction*5,cursor+direction*11,Color("efddac"),1.5,true)
	if hurt_flash>0:draw_rect(Rect2(0,0,1440,900),Color(0.8,0.2,0.1,hurt_flash*0.25))
	if Net.reconnect_until>0:
		panel(Rect2(410,145,620,50),Color("493e2b"));text_at(Vector2(435,178),"CONNECTION LOST / Reconnecting to your match...",18,Color("f1d194"))

func scoreboard() -> void:
	panel(Rect2(380,205,680,420),Color(0.07,0.09,0.07,0.98),Color("66624a"))
	text_at(Vector2(412,254),"MATCH RESULTS" if Net.state.phase=="results" else "SCOREBOARD",28,Color("f1dfb7"))
	text_at(Vector2(412,290),"PILOT                                          TEAM          K          D        SCORE",12,Color("a2ad92"))
	var sorted=Net.state.players.values();sorted.sort_custom(func(a,b):return a.score>b.score)
	for j in range(sorted.size()):
		var p=sorted[j];var y=328+j*32
		if p.id==Net.local_id:draw_rect(Rect2(399,y-22,642,31),Color(0.8,0.68,0.4,0.1))
		text_at(Vector2(418,y),p.name+(" / away" if not p.online else ""),16,PilotArt.COLORS[int(p.char)])
		text_at(Vector2(705,y),"AZURE" if p.team==0 else "EMBER",12)
		text_at(Vector2(817,y),str(p.kills),16);text_at(Vector2(886,y),str(p.deaths),16);text_at(Vector2(967,y),str(p.score),16,Color("e6bc75"))
