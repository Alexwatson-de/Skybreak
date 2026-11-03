extends SceneTree
const Maps=preload("res://scripts/maps.gd")
const Sim=preload("res://scripts/sim.gd")
var checks=0
var failures=0
var floor_shape=Rect2(0,1000,3200,300)

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAILED: "+message)
	else:print("PASS ",message)

func arena() -> Dictionary:
	return {"platforms":[floor_shape],"spawns":[Vector2(300,975),Vector2(900,975)],"loot":[{"kind":"gun","item":1,"p":Vector2(340,975)},{"kind":"grenade","item":1,"p":Vector2(500,975)},{"kind":"health","item":0,"p":Vector2(650,975)}]}

func state() -> Dictionary:
	var result={"phase":"match","map":0,"mode":0,"players":{},"grenades":[],"time":0.0,"duration":300.0,"remaining":300.0,"scores":[0,0],"limit":15,"pickups":[0.0,0.0,0.0]}
	result.players[1]=Sim.player(1,"One",0,0,Vector2(300,975));result.players[2]=Sim.player(2,"Two",1,1,Vector2(900,975))
	result.players[1].shield=0;result.players[2].shield=0
	return result

func step(s: Dictionary,inputs: Dictionary={},count: int=1) -> Array:
	var events: Array=[]
	for j in range(count):events.append_array(Sim.tick(s,inputs,[],arena()))
	return events

func _initialize() -> void:
	var p=Sim.player(1,"One",0,0,Vector2(100,100));var input=Sim.blank();input.x=1.0
	for j in range(120):Sim.move(p,input,[floor_shape],Sim.DT)
	check(p.p.x>400 and absf(p.v.x)<=Sim.SPEED,"movement accelerates without exceeding speed limit")
	p=Sim.player(1,"One",0,0,Vector2(200,975));Sim.move(p,Sim.blank(),[floor_shape],Sim.DT)
	check(p.ground,"solid ground collision resolves")
	input=Sim.blank();input.jump=true;Sim.move(p,input,[floor_shape],Sim.DT)
	check(p.v.y<0,"jump leaves ground")
	p=Sim.player(1,"One",0,0,Vector2(900,500));input=Sim.blank();input.jet=true
	for j in range(120):Sim.move(p,input,[floor_shape],Sim.DT)
	check(p.fuel<50 and p.v.y>=-420,"jetpack consumes fuel with bounded thrust")
	p.fuel=0;Sim.move(p,input,[floor_shape],Sim.DT);check(not p.jet,"empty jetpack cannot thrust")
	var ramp=Maps.shape(PackedVector2Array([Vector2(0,500),Vector2(600,200),Vector2(600,700),Vector2(0,700)]))
	p=Sim.player(1,"One",0,0,Vector2(120,250));input=Sim.blank();input.x=1.0
	for j in range(95):Sim.move(p,input,[ramp],Sim.DT)
	check(p.p.x>240 and p.p.y<380,"sloped polygon terrain can be traversed")
	for index in range(3):
		var map=Maps.data(index)
		check(map.terrain.size()>=15 and map.platforms.size()>=map.terrain.size(),"arena "+str(index)+" has compiled irregular terrain")
		var free=true
		for spawn in map.spawns:
			for shape in map.platforms:
				if Sim.penetration(spawn,Vector2(15,25),shape).length()>0.1:free=false
		check(free,"arena "+str(index)+" spawn points are clear")
		var settled=true
		for spawn in map.spawns:
			var pilot=Sim.player(1,"Test",0,0,spawn)
			for j in range(150):Sim.move(pilot,Sim.blank(),map.platforms,Sim.DT)
			if pilot.p.y>Maps.HEIGHT:settled=false
		check(settled,"arena "+str(index)+" supports every spawn above the bottom boundary")
		var guns={};var grenades={}
		for item in map.loot:
			if item.kind=="gun":guns[item.item]=true
			if item.kind=="grenade":grenades[item.item]=true
		check(guns.size()==5 and grenades.size()==3,"arena "+str(index)+" contains five guns and three grenade supplies")
		var reachable=true
		for item in map.loot:
			for shape in map.platforms:
				if Sim.penetration(item.p,Vector2(9,12),shape).length()>0.1:reachable=false
		check(reachable,"arena "+str(index)+" loot is outside solid terrain")
	var hollow=Maps.data(0)
	check(Sim.wall_distance(Vector2(1510,600),Vector2.RIGHT,140,hollow.platforms)==140,"catacomb arch opening is passable to weapon rays")
	check(Sim.wall_distance(Vector2(1590,600),Vector2.UP,150,hollow.platforms)<150,"arch masonry blocks weapon rays")
	var s=state();input=Sim.blank();input.fire=true
	step(s,{1:input})
	check(s.players[1].ammo[0]==11 and s.players[2].hp==76,"starter pistol consumes ammo and applies server damage")
	step(s,{1:input});check(s.players[1].ammo[0]==11,"fire cadence prevents duplicate shots")
	s.players[1].cool=0;s.players[1].ammo[0]=0;s.players[1].reserve[0]=0;step(s,{1:input})
	check(s.players[2].hp==76,"empty weapon cannot deal damage")
	s=state();input=Sim.blank();input.weapon=4;step(s,{1:input})
	check(s.players[1].weapon==0 and not s.players[1].owned[4],"uncollected gun selection is rejected")
	input=Sim.blank();input.interact=true;var events=step(s,{1:input})
	check(s.players[1].owned[1] and s.players[1].weapon==1 and s.players[1].ammo[1]==30,"E collects and equips an available nearby gun")
	check(s.pickups[0]>17 and events.any(func(e):return e.kind=="pickup"),"weapon pickup has a server-owned respawn timer and event")
	s=state();s.players[1].p=Vector2(1000,975);input=Sim.blank();input.interact=true;step(s,{1:input})
	check(not s.players[1].owned[1],"remote weapon pickups are rejected")
	s=state();s.players[2].p=Vector2(350,975);input=Sim.blank();input.interact=true;step(s,{1:input,2:input})
	check(s.players[1].owned[1] and not s.players[2].owned[1],"two players cannot claim one rack at the same time")
	s=state();s.players[1].p=Vector2(500,975);step(s)
	check(s.players[1].grenade_ammo[1]==2 and s.pickups[1]>0,"walking over impact supplies grants that grenade type")
	s=state();s.players[1].p=Vector2(650,975);s.players[1].hp=55;step(s)
	check(s.players[1].hp==100 and not s.players[1].owned[1] and s.players[1].reserve[1]==0,"health supplies restore health without granting hidden guns")
	s=state();s.players[1].ammo[0]=3;input=Sim.blank();input.reload=true;step(s,{1:input});step(s,{},70)
	check(s.players[1].ammo[0]==12 and s.players[1].reserve[0]==63,"reload conserves total ammunition")
	s=state();s.players[2].team=0;s.mode=1;Sim.hurt(s,2,1,100,[])
	check(s.players[2].hp==100,"friendly fire is blocked")
	s.players[2].team=1;Sim.hurt(s,2,1,100,[]);Sim.hurt(s,2,1,100,[])
	check(s.players[2].hp==0 and s.players[1].kills==1 and s.scores[0]==1,"kills and scores cannot be awarded twice")
	var dead_pos=s.players[2].p;input=Sim.blank();input.x=1;input.seq=400;step(s,{2:input})
	check(s.players[2].p==dead_pos and s.players[2].seq==400,"dead players acknowledge input without moving")
	step(s,{},183);check(s.players[2].hp==100 and s.players[2].owned==[true,false,false,false,false,false],"respawn restores health and starter inventory")
	s=state();s.players[1].p=Vector2(300,600);input=Sim.blank();input.grenade=true;step(s,{1:input});step(s,{1:input})
	check(s.players[1].grenade_ammo[0]==1 and s.grenades.size()==1,"frag count and held-input gate are authoritative")
	step(s,{},115);check(s.grenades.is_empty(),"frag fuse detonates and removes the projectile")
	s=state();s.players[1].p=Vector2(300,700);s.players[1].grenade_ammo[1]=1;input=Sim.blank();input.grenade_type=1;input.grenade=true;input.aim=PI/2
	events=step(s,{1:input});events.append_array(step(s,{},65))
	check(s.grenades.is_empty() and events.any(func(e):return e.kind=="boom" and e.type==1),"impact grenade explodes on terrain before its maximum fuse")
	s=state();s.players[1].p=Vector2(300,700);s.players[1].grenade_ammo[2]=1;s.players[2].p=Vector2(340,975)
	input=Sim.blank();input.grenade_type=2;input.grenade=true;input.aim=PI/2;step(s,{1:input});step(s,{},65)
	check(s.grenades.any(func(g):return g.burn) and s.players[2].hp<100,"incendiary leaves a damaging server-simulated fire field")
	step(s,{},300);check(s.grenades.is_empty(),"incendiary field expires")
	s=state();input=Sim.blank();input.grenade_type=2;input.grenade=true;step(s,{1:input})
	check(s.grenades.is_empty(),"unowned grenade type cannot be thrown")
	s=state();s.duration=0.02;step(s,{},2);check(s.phase=="results","match timer produces results")
	print("SIMULATION_TESTS checks=",checks," failures=",failures);quit(1 if failures else 0)
