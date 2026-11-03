class_name GameSim
extends RefCounted
const ArenaMaps=preload("res://scripts/maps.gd")
const DT=1.0/60.0
const SPEED=315.0
const GRAVITY=1180.0
const JUMP=-505.0
const WEAPONS=["SABLE PISTOL","KESTREL AR","BREACH SHOTGUN","NEEDLE SMG","LONGSHOT DMR","VOLT CARBINE"]
const CLIP=[12,30,6,36,5,12]
const DAMAGE=[24,22,11,13,72,39]
const COOLDOWN=[0.25,0.125,0.72,0.078,0.9,0.40]
const RANGE=[900.0,1100.0,650.0,850.0,1800.0,1400.0]
const RELOAD=[1.1,1.5,2.0,1.35,2.2,1.8]
const STOCK=[72,120,36,144,25,60]
const GRENADE_NAMES=["FRAG","IMPACT","INCENDIARY"]
const GRENADE_FUSE=[1.8,2.4,2.0]

static func player(id: int,name_tag: String,team: int,character: int,spawn: Vector2) -> Dictionary:
	return {"id":id,"name":name_tag.left(18),"team":team,"char":character,"p":spawn,"v":Vector2.ZERO,"hp":100,"fuel":100.0,"ammo":[12,0,0,0,0,0],"reserve":[72,0,0,0,0,0],"owned":[true,false,false,false,false,false],"weapon":0,"grenade_ammo":[2,0,0],"grenade_type":0,"grenades":2,"cool":0.0,"reload":0.0,"dead":0.0,"shield":2.2,"kills":0,"deaths":0,"score":0,"seq":0,"aim":0.0,"ground":false,"jet":false,"online":true,"last_g":false,"last_jump":false,"last_pick":false,"grenade_cd":0.0}

static func blank() -> Dictionary:
	return {"x":0.0,"jump":false,"jet":false,"fire":false,"grenade":false,"reload":false,"interact":false,"aim":0.0,"weapon":-1,"grenade_type":0,"seq":0,"time":0.0}

static func collision_shape(value: Variant) -> Dictionary:
	if value is Dictionary:return value
	var r: Rect2=value
	return ArenaMaps.shape(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]))

static func penetration(center: Vector2,half: Vector2,value: Variant) -> Vector2:
	var shape=collision_shape(value)
	if not Rect2(center-half,half*2).intersects(shape.bounds):return Vector2.ZERO
	var distance=INF;var correction=Vector2.ZERO
	for j in range(0,shape.slabs.size(),2):
		var slab: Vector3=shape.slabs[j]
		var axis=Vector2(slab.x,slab.y)
		var extent=half.x*absf(axis.x)+half.y*absf(axis.y)
		var projection=center.dot(axis)
		var positive=shape.slabs[j+1].z-(projection-extent)
		var negative=(projection+extent)-slab.z
		if positive<=0 or negative<=0:return Vector2.ZERO
		if minf(positive,negative)<distance:
			distance=minf(positive,negative)
			correction=axis*positive if positive<negative else -axis*negative
	return correction

static func move(p: Dictionary,input: Dictionary,platforms: Array,dt: float) -> void:
	if p.hp<=0:return
	var v: Vector2=p.v;var pos: Vector2=p.p
	v.x=move_toward(v.x,float(input.get("x",0))*SPEED,(2200.0 if p.ground else 1350.0)*dt)
	var jump=bool(input.get("jump",false))
	if jump and not p.last_jump and p.ground:v.y=JUMP
	p.last_jump=jump
	p.jet=bool(input.get("jet",false)) and p.fuel>0
	if p.jet:
		v.y=maxf(v.y-1900.0*dt,-420.0);p.fuel=maxf(0,p.fuel-29*dt)
	else:p.fuel=minf(100,p.fuel+(22 if p.ground else 10)*dt)
	v.y=minf(760,v.y+GRAVITY*dt)
	p.ground=false
	for substep in range(2):
		pos+=v*dt*0.5
		for iteration in range(3):
			var moved=false
			for shape in platforms:
				var correction=penetration(pos,Vector2(15,25),shape)
				if correction.length_squared()<0.000001:continue
				var normal=correction.normalized()
				pos+=correction+normal*0.002
				if normal.y< -0.55:p.ground=true
				if v.dot(normal)<0:v-=normal*v.dot(normal)
				moved=true
			if not moved:break
	pos.x=clampf(pos.x,20,ArenaMaps.WIDTH-20);pos.y=maxf(28,pos.y)
	p.p=pos;p.v=v;p.aim=float(input.get("aim",p.aim))

static func wall_distance(origin: Vector2,direction: Vector2,distance: float,platforms: Array) -> float:
	var best=distance
	for value in platforms:
		var shape=collision_shape(value)
		var lo=0.0;var hi=distance
		for j in range(0,shape.slabs.size(),2):
			var slab: Vector3=shape.slabs[j];var axis=Vector2(slab.x,slab.y)
			var o=origin.dot(axis);var d=direction.dot(axis)
			if absf(d)<0.000001:
				if o<slab.z or o>shape.slabs[j+1].z:hi=-1.0;break
			else:
				var a=(slab.z-o)/d;var b=(shape.slabs[j+1].z-o)/d
				lo=maxf(lo,minf(a,b));hi=minf(hi,maxf(a,b))
				if hi<lo:break
		if hi>=lo and hi>=0:best=minf(best,lo)
	return best

static func ray_player(origin: Vector2,direction: Vector2,center: Vector2) -> float:
	var delta=center-origin;var along=delta.dot(direction)
	var d=delta.length_squared()-along*along
	if d>26*26:return INF
	var hit=along-sqrt(maxf(0,26*26-d))
	return hit if hit>=0 else INF

static func hurt(state: Dictionary,victim: int,attacker: int,amount: int,events: Array) -> void:
	if not state.players.has(victim):return
	var target=state.players[victim]
	if target.hp<=0 or target.shield>0 or not target.online:return
	if attacker!=victim and state.players.has(attacker) and state.mode==1 and target.team==state.players[attacker].team:return
	target.hp=maxi(0,target.hp-amount)
	events.append({"kind":"hit","p":target.p,"id":victim,"by":attacker})
	if target.hp==0:
		target.deaths+=1;target.dead=3.0
		if state.players.has(attacker) and attacker!=victim:
			var killer=state.players[attacker];killer.kills+=1;killer.score+=1;state.scores[killer.team]+=1
		events.append({"kind":"kill","victim":target.name,"killer":state.players[attacker].name if state.players.has(attacker) else "Arena","p":target.p})

static func blast(state: Dictionary,g: Dictionary,map: Dictionary,events: Array) -> void:
	var kind=int(g.get("type",0))
	var radius=[170.0,135.0,100.0][kind];var damage=[110,98,30][kind]
	events.append({"kind":"boom","p":g.p,"type":kind})
	for id in state.players:
		var delta=state.players[id].p-g.p;var distance=delta.length()
		if distance<radius and wall_distance(g.p,delta.normalized(),distance,map.platforms)>=distance-3:
			hurt(state,id,int(g.by),maxi(4,int(damage*(1-distance/(radius+35)))),events)

static func tick(state: Dictionary,inputs: Dictionary,history: Array,arena_override: Dictionary={}) -> Array:
	var events: Array=[]
	if state.phase!="match":return events
	state.time+=DT;state.remaining=maxf(0,state.duration-state.time)
	var map=ArenaMaps.data(state.map) if arena_override.is_empty() else arena_override
	for id in state.players:
		var p=state.players[id];var input=inputs.get(id,blank()) if p.online else blank()
		p.seq=maxi(p.seq,int(input.get("seq",p.seq)))
		if p.hp<=0:
			p.dead-=DT
			if p.dead<=0 and p.online:
				var spawn=map.spawns[(int(id)+int(state.time))%map.spawns.size()]
				var fresh=player(id,p.name,p.team,p.char,spawn)
				for key in ["kills","deaths","score","seq"]:fresh[key]=p[key]
				state.players[id]=fresh
			continue
		p.shield=maxf(0,p.shield-DT);p.cool=maxf(0,p.cool-DT);p.grenade_cd=maxf(0,p.grenade_cd-DT)
		move(p,input,map.platforms,DT)
		var requested=clampi(int(input.get("weapon",-1)),-1,WEAPONS.size()-1)
		if requested>=0 and p.owned[requested] and requested!=p.weapon:p.weapon=requested;p.reload=0.0
		var weapon=int(p.weapon)
		p.grenade_type=clampi(int(input.get("grenade_type",p.grenade_type)),0,2)
		p.grenades=p.grenade_ammo[p.grenade_type]
		if p.reload>0:
			p.reload=maxf(0,p.reload-DT)
			if p.reload==0:
				var take=mini(CLIP[weapon]-p.ammo[weapon],p.reserve[weapon]);p.ammo[weapon]+=take;p.reserve[weapon]-=take
		elif (input.get("reload",false) or p.ammo[weapon]==0) and p.ammo[weapon]<CLIP[weapon] and p.reserve[weapon]>0:p.reload=RELOAD[weapon]
		if input.get("fire",false) and p.cool<=0 and p.reload<=0 and p.ammo[weapon]>0:
			p.ammo[weapon]-=1;p.cool=COOLDOWN[weapon];p.shield=0.0
			var origin=p.p+Vector2(0,-5)
			var lag=clampf(state.time-float(input.get("time",state.time)),0,0.18)
			var rewind: Dictionary={}
			for frame in history:
				if frame.time<=state.time-lag:rewind=frame.players
			for pellet in range(7 if weapon==2 else 1):
				var spread=(float(pellet)-3)*0.052 if weapon==2 else 0.0
				var direction=Vector2.from_angle(p.aim+spread)
				var length=wall_distance(origin,direction,RANGE[weapon],map.platforms);var target_id=-1
				for other_id in state.players:
					var other=state.players[other_id]
					if other_id==id or other.hp<=0 or not other.online or (state.mode==1 and other.team==p.team):continue
					var hit=ray_player(origin,direction,rewind.get(other_id,other.p))
					if hit<length:length=hit;target_id=other_id
				if target_id!=-1:hurt(state,target_id,id,DAMAGE[weapon],events)
				events.append({"kind":"shot","from":origin,"to":origin+direction*length,"by":id,"weapon":weapon})
		var g=bool(input.get("grenade",false))
		if g and not p.last_g and p.grenades>0 and p.grenade_cd<=0 and state.grenades.size()<32:
			p.grenade_ammo[p.grenade_type]-=1;p.grenades=p.grenade_ammo[p.grenade_type];p.grenade_cd=0.6
			state.grenades.append({"p":p.p+Vector2(0,-30),"v":Vector2.from_angle(p.aim)*630+Vector2(0,-120),"life":GRENADE_FUSE[p.grenade_type],"by":id,"type":p.grenade_type,"burn":false,"pulse":0.0})
		p.last_g=g
		# E is an intention; the authority checks actual distance, availability and cover.
		var pick=bool(input.get("interact",false))
		if pick and not p.last_pick:
			for j in range(map.loot.size()):
				var item=map.loot[j]
				if item.kind!="gun" or state.pickups[j]>0 or p.p.distance_to(item.p)>78:continue
				var delta=item.p-p.p
				if wall_distance(p.p,delta.normalized(),delta.length(),map.platforms)<delta.length()-4:continue
				var gun=int(item.item);p.owned[gun]=true;p.weapon=gun;p.ammo[gun]=CLIP[gun];p.reserve[gun]=STOCK[gun];p.reload=0.0
				state.pickups[j]=18.0
				events.append({"kind":"pickup","id":id,"p":item.p,"label":WEAPONS[gun]})
				break
		p.last_pick=pick
	for j in range(state.grenades.size()-1,-1,-1):
		var grenade=state.grenades[j];grenade.life-=DT
		if grenade.get("burn",false):
			grenade.pulse-=DT
			if grenade.pulse<=0:
				grenade.pulse=0.35
				for id in state.players:
					var delta=state.players[id].p-grenade.p
					if delta.length()<110 and wall_distance(grenade.p,delta.normalized(),delta.length(),map.platforms)>=delta.length()-3:hurt(state,id,int(grenade.by),8,events)
			if grenade.life<=0:state.grenades.remove_at(j)
			continue
		grenade.v.y+=850*DT
		var next=grenade.p+grenade.v*DT;var touched=false
		for shape in map.platforms:
			var correction=penetration(next,Vector2(6,7),shape)
			if correction.length_squared()<0.001:continue
			var normal=correction.normalized();next+=correction+normal*0.2
			grenade.v=grenade.v.bounce(normal)*0.55;touched=true
		grenade.p=next
		if grenade.p.x<15 or grenade.p.x>ArenaMaps.WIDTH-15:grenade.v.x*=-0.6
		if grenade.life<=0 or (touched and grenade.type>0):
			blast(state,grenade,map,events)
			if grenade.type==2:grenade.burn=true;grenade.life=4.5;grenade.pulse=0.0;grenade.v=Vector2.ZERO;grenade.p.y-=8
			else:state.grenades.remove_at(j)
	for j in range(state.pickups.size()):
		state.pickups[j]=maxf(0,state.pickups[j]-DT)
		if state.pickups[j]>0 or j>=map.loot.size() or map.loot[j].kind=="gun":continue
		var item=map.loot[j]
		for p in state.players.values():
			if p.hp<=0 or not p.online or p.p.distance_to(item.p)>45:continue
			if item.kind=="health":
				if p.hp==100:continue
				p.hp=mini(100,p.hp+45)
				for gun in range(WEAPONS.size()):
					if p.owned[gun]:p.reserve[gun]=mini(STOCK[gun],p.reserve[gun]+CLIP[gun]*2)
			else:
				var kind=int(item.item)
				if p.grenade_ammo[kind]>=4:continue
				p.grenade_ammo[kind]=mini(4,p.grenade_ammo[kind]+2);p.grenades=p.grenade_ammo[p.grenade_type]
			state.pickups[j]=14.0
			events.append({"kind":"pickup","id":p.id,"p":item.p,"label":"FIELD SUPPLIES" if item.kind=="health" else GRENADE_NAMES[item.item]+" GRENADES"})
			break
	var limit=false
	if state.mode==1:limit=maxi(state.scores[0],state.scores[1])>=state.limit
	else:
		for p in state.players.values():
			if p.kills>=state.limit:limit=true
	if state.remaining<=0 or limit:state.phase="results"
	return events
