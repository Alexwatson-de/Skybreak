extends Node
const ArenaMaps = preload("res://scripts/maps.gd")
const GameSim = preload("res://scripts/sim.gd")
const SNAPSHOT_KEYS=["id","name","team","char","p","v","hp","fuel","ammo","reserve","weapon","grenades","reload","dead","shield","kills","deaths","score","seq","aim","ground","jet","online","last_jump","owned","grenade_ammo","grenade_type","last_pick"]

signal changed
signal effects(events: Array)
signal notice(message: String)

var state: Dictionary={}
var inputs: Dictionary={}
var peers: Dictionary={}
var tickets: Dictionary={}
var grace: Dictionary={}
var packet_times: Dictionary={}
var history: Array=[]
var bot_routes: Dictionary={}
var snapshots: Array=[]
var pending: Array=[]
var prediction: Dictionary={}
var visual_error=Vector2.ZERO
var transport="enet"
var local_id=0
var sequence=0
var is_host=false
var dedicated=false
var active=false
var status="OFFLINE"
var map_id=0
var mode_id=0
var port=28760
var tick_count=0
var ping_ms=0
var last_snapshot=0.0
var reconnect_at=0.0
var reconnect_until=0.0
var recovering_session=false
var join_info: Dictionary={}
var profile={"name":"Pilot","char":0}
var auth_token=""
var lobby_players: Dictionary={}
var chat: Array=[]
var discovery=PacketPeerUDP.new()
var discovered: Dictionary={}
var announce_clock=0.0
var clock_offset=0.0
var last_ping=0.0
var metrics={"snapshots":0,"shots":0,"hits":0,"kills":0,"rejected":0,"reconnects":0,"max_snapshot_bytes":0}

func _ready() -> void:
	multiplayer.server_relay=false
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_disconnected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.peer_connected.connect(_peer_joined)

func now() -> float: return Time.get_ticks_msec()/1000.0

func fresh_state() -> Dictionary:
	return {"phase":"lobby","map":map_id,"mode":mode_id,"players":{},"grenades":[],"time":0.0,"duration":300.0,"remaining":300.0,"scores":[0,0],"limit":15,"pickups":Array() ,"protocol":2}

func host(p: int=28760, server_only: bool=false, roster: Array=[], wire: String="enet") -> Error:
	stop()
	port=p
	dedicated=server_only
	transport=wire
	var peer: MultiplayerPeer
	var result=OK
	if p==0:
		peer=OfflineMultiplayerPeer.new()
	elif transport=="websocket":
		peer=WebSocketMultiplayerPeer.new()
		peer.handshake_timeout=8
		peer.max_queued_packets=256
		result=peer.create_server(port,"127.0.0.1")
	else:
		if OS.has_feature("web"):
			notice.emit("ENet multiplayer needs the desktop build. Practice is available here.")
			return ERR_UNAVAILABLE
		peer=ENetMultiplayerPeer.new()
		result=peer.create_server(port,8,3)
	if result!=OK:
		status="PORT IN USE · choose another port"
		notice.emit(status)
		return result
	multiplayer.multiplayer_peer=peer
	is_host=true
	active=true
	state=fresh_state()
	state.pickups.resize(ArenaMaps.data(map_id).loot.size())
	state.pickups.fill(0.0)
	status="PRACTICE · LOCAL SIMULATION" if p==0 else ("DEDICATED SERVER" if dedicated else "LAN HOST · UDP %s"%port)
	for entry in roster: tickets[entry.token]=entry
	if not dedicated:
		local_id=1
		_add_player(1,profile.name,0,profile.char)
		lobby_players[1].ready=true
		if p!=0:
			discovery.set_broadcast_enabled(true)
			discovery.bind(28761,"0.0.0.0")
	changed.emit()
	print("SERVER_READY port=",port)
	return OK

func join_game(address: String, p: int, token: String="") -> void:
	stop(false)
	join_info={"host":address,"port":p,"token":token}
	auth_token=token
	reconnect_until=now()+25
	_connect_peer()

func join_websocket(url: String, token: String) -> void:
	stop(false)
	join_info={"host":url,"port":0,"token":token,"transport":"websocket"}
	auth_token=token
	reconnect_until=now()+25
	_connect_peer()

func _connect_peer() -> void:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	var peer: MultiplayerPeer
	var result=OK
	transport=str(join_info.get("transport","enet"))
	if transport=="websocket":
		peer=WebSocketMultiplayerPeer.new()
		peer.handshake_timeout=8
		peer.max_queued_packets=256
		result=peer.create_client(str(join_info.host))
	else:
		peer=ENetMultiplayerPeer.new()
		result=peer.create_client(join_info.host,int(join_info.port),3)
	if result!=OK:
		_failed()
		return
	multiplayer.multiplayer_peer=peer
	active=true
	status="CONNECTING TO MATCH" if transport=="websocket" else "CONNECTING · %s:%s"%[join_info.host,join_info.port]
	changed.emit()

func stop(clear_join: bool=true) -> void:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	discovery.close()
	active=false
	is_host=false
	dedicated=false
	state={}
	inputs.clear()
	peers.clear()
	tickets.clear()
	grace.clear()
	packet_times.clear()
	history.clear()
	bot_routes.clear()
	snapshots.clear()
	pending.clear()
	prediction={}
	visual_error=Vector2.ZERO
	lobby_players.clear()
	chat.clear()
	local_id=0
	sequence=0
	reconnect_at=0
	reconnect_until=0
	recovering_session=false
	status="OFFLINE"
	if clear_join: join_info={}

func _connected() -> void:
	_configure_peer(1)
	status="AUTHENTICATING"
	authenticate.rpc_id(1,"v2:"+auth_token,profile.name,int(profile.char))

func _failed() -> void:
	if reconnect_until>now():
		status=("RECONNECTING" if recovering_session else "CONNECTING")+" · retrying in 2s"
		active=true
		reconnect_at=now()+2
	else:
		status="CONNECTION FAILED · check the server and retry" if transport=="websocket" else "CONNECTION FAILED · check IP, UDP port and firewall"
		active=false
	notice.emit(status)
	changed.emit()

func _disconnected() -> void:
	if join_info.is_empty(): return
	status="CONNECTION LOST · reconnecting"
	recovering_session=local_id>0
	reconnect_until=now()+25
	reconnect_at=now()+1
	changed.emit()

func _peer_joined(id: int) -> void:
	if is_host:
		_configure_peer(id)
		packet_times[id]={"joined":now(),"window":now(),"count":0,"seq":-1}

func _peer_left(id: int) -> void:
	if not is_host: return
	packet_times.erase(id)
	if not peers.has(id): return
	var slot=int(peers[id])
	peers.erase(id)
	if state.players.has(slot): state.players[slot].online=false
	inputs.erase(slot)
	grace[slot]=now()+30
	if lobby_players.has(slot): lobby_players[slot].online=false
	_broadcast_lobby()

func _add_player(id: int, name_tag: String, team: int, character: int) -> void:
	state.players[id]=GameSim.player(id,name_tag,team,character,ArenaMaps.data(map_id).spawns[(id-1)%ArenaMaps.data(map_id).spawns.size()])
	lobby_players[id]={"id":id,"name":name_tag.left(18),"team":team,"char":character,"ready":false,"online":true}

@rpc("any_peer","call_remote","reliable",0)
func authenticate(token: String, name_tag: String, character: int) -> void:
	if not is_host: return
	var sender=multiplayer.get_remote_sender_id()
	if peers.has(sender) or not _live_peer(sender): return
	if not token.begins_with("v2:"):
		denied.rpc_id(sender,"Different game version. Install Skybreak Arena 1.1 on every device.")
		return
	token=token.trim_prefix("v2:")
	var slot=0
	if tickets.has(token):
		var entry=tickets[token]
		slot=int(entry.id)
		if peers.values().has(slot):
			denied.rpc_id(sender,"This player is already connected")
			return
		if not state.players.has(slot): _add_player(slot,entry.name,int(entry.team),int(entry.get("char",0)))
	else:
		if dedicated or state.phase!="lobby" or state.players.size()>=8:
			denied.rpc_id(sender,"Room closed, full, or invalid match ticket")
			return
		slot=2
		while state.players.has(slot): slot+=1
		token=Crypto.new().generate_random_bytes(24).hex_encode()
		tickets[token]={"id":slot}
		_add_player(slot,name_tag.strip_edges() if not name_tag.strip_edges().is_empty() else "Pilot",slot%2,clampi(character,0,3))
	peers[sender]=slot
	state.players[slot].online=true
	lobby_players[slot].online=true
	grace.erase(slot)
	accepted.rpc_id(sender,slot,token,state.duplicate(true))
	_broadcast_lobby()
	print("AUTH_OK slot=",slot," peer=",sender)

@rpc("authority","call_remote","reliable",0)
func denied(reason: String) -> void:
	status=reason
	notice.emit(reason)
	reconnect_until=0
	active=false
	changed.emit()

@rpc("authority","call_remote","reliable",0)
func accepted(slot: int, token: String, initial: Dictionary) -> void:
	if initial.get("protocol",1)!=2:
		denied("Install Skybreak Arena 1.1 on the host and every client.")
		return
	local_id=slot
	auth_token=token
	join_info.token=token
	state=initial
	map_id=int(state.map)
	mode_id=int(state.mode)
	prediction=state.players[slot].duplicate(true)
	pending.clear()
	sequence=int(prediction.seq)
	clock_offset=float(state.time)-now()
	last_snapshot=now()
	if recovering_session: metrics.reconnects+=1
	recovering_session=false
	reconnect_until=0
	reconnect_at=0
	status="CONNECTED · "+("ONLINE" if transport=="websocket" else "ENet")
	changed.emit()

func _broadcast_lobby() -> void:
	if state.get("phase","")!="lobby": return
	var payload={"players":lobby_players,"chat":chat,"map":map_id,"mode":mode_id}
	for peer in peers:
		if _live_peer(peer): lobby_update.rpc_id(peer,payload)
	changed.emit()

@rpc("authority","call_remote","reliable",0)
func lobby_update(payload: Dictionary) -> void:
	lobby_players=payload.players
	chat=payload.chat
	map_id=int(payload.map)
	mode_id=int(payload.mode)
	changed.emit()

func lobby_action(action: String, value: Variant=null) -> void:
	if is_host: _lobby_action(1,action,value)
	elif active: request_lobby.rpc_id(1,action,value)

@rpc("any_peer","call_remote","reliable",0)
func request_lobby(action: String, value: Variant) -> void:
	var sender=multiplayer.get_remote_sender_id()
	if is_host and peers.has(sender): _lobby_action(int(peers[sender]),action,value)

func _lobby_action(slot: int, action: String, value: Variant) -> void:
	if not lobby_players.has(slot) or state.phase!="lobby": return
	match action:
		"ready": lobby_players[slot].ready=bool(value)
		"team":
			lobby_players[slot].team=clampi(int(value),0,1)
			state.players[slot].team=lobby_players[slot].team
			lobby_players[slot].ready=false
		"chat":
			if str(value).length()>160: return
			chat.append(lobby_players[slot].name+": "+str(value).replace("\n"," "))
			if chat.size()>30: chat.pop_front()
		"start":
			if slot!=1: return
			if state.players.size()<2:
				notice.emit("Add a bot or invite another pilot first")
				return
			var teams={}
			for p in lobby_players.values(): teams[p.team]=true
			if mode_id==1 and teams.size()<2:
				notice.emit("Team deathmatch needs pilots on both teams")
				return
			for p in lobby_players.values():
				if not p.ready or not p.online:
					notice.emit("All connected pilots must be ready")
					return
			start_match()
	_broadcast_lobby()

func add_bot() -> void:
	if not is_host or state.players.size()>=8 or state.phase!="lobby": return
	var id=100
	while state.players.has(id): id+=1
	_add_player(id,["Moss","Rivet","Nova","Echo"][id%4],id%2,id%4)
	lobby_players[id].ready=true
	_broadcast_lobby()

func start_match() -> void:
	state.phase="match"
	state.time=0.0
	state.remaining=state.duration
	for peer in peers:
		if _live_peer(peer): match_started.rpc_id(peer,state)
	changed.emit()

@rpc("authority","call_remote","reliable",0)
func match_started(initial: Dictionary) -> void:
	state=initial
	pending.clear()
	if state.players.has(local_id): prediction=state.players[local_id].duplicate(true)
	clock_offset=-now()
	changed.emit()

func send_input(input: Dictionary) -> void:
	if not active or state.get("phase","")!="match" or local_id==0: return
	if not is_host and multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	sequence+=1
	input.seq=sequence
	input.time=state.time if is_host else now()+clock_offset
	if is_host: inputs[local_id]=input
	else:
		submit_input.rpc_id(1,input)
		if not prediction.is_empty():
			GameSim.move(prediction,input,ArenaMaps.data(map_id).platforms,GameSim.DT)
			pending.append(input.duplicate())
			if pending.size()>120: pending.pop_front()

@rpc("any_peer","call_remote","unreliable_ordered",1)
func submit_input(input: Dictionary) -> void:
	if not is_host: return
	var sender=multiplayer.get_remote_sender_id()
	if not peers.has(sender) or not packet_times.has(sender): return
	var rate=packet_times[sender]
	if now()-rate.window>1.0:
		rate.window=now()
		rate.count=0
	rate.count+=1
	var seq=int(input.get("seq",-1))
	var aim=float(input.get("aim",NAN))
	var axis=float(input.get("x",NAN))
	var sent_time=float(input.get("time",NAN))
	if rate.count>100 or input.size()>14 or seq<=rate.seq or not is_finite(aim) or not is_finite(axis) or not is_finite(sent_time) or absf(axis)>1.0:
		metrics.rejected+=1
		return
	rate.seq=seq
	var clean=GameSim.blank()
	for key in ["jump","jet","fire","grenade","reload","interact"]: clean[key]=input.get(key,false)==true
	clean.x=axis
	clean.aim=wrapf(aim,-PI,PI)
	clean.seq=seq
	clean.time=clampf(sent_time,state.time-0.18,state.time)
	clean.weapon=clampi(int(input.get("weapon",-1)),-1,5)
	clean.grenade_type=clampi(int(input.get("grenade_type",0)),0,2)
	inputs[peers[sender]]=clean
	rate.last=now()

@rpc("any_peer","call_remote","unreliable",2)
func ping(client_time: float) -> void:
	if is_host and peers.has(multiplayer.get_remote_sender_id()) and _live_peer(multiplayer.get_remote_sender_id()): pong.rpc_id(multiplayer.get_remote_sender_id(),client_time,float(state.time))

@rpc("authority","call_remote","unreliable",2)
func pong(client_time: float, server_time: float) -> void:
	ping_ms=int((now()-client_time)*1000)
	clock_offset=server_time+(now()-client_time)*0.5-now()

@rpc("authority","call_remote","unreliable_ordered",1)
func snapshot(packed: PackedByteArray, raw_size: int) -> void:
	if local_id==0 or packed.size()>16384 or raw_size<1 or raw_size>65536: return
	var decoded=packed.decompress(raw_size,FileAccess.COMPRESSION_ZSTD)
	var compact=bytes_to_var(decoded)
	if not compact is Array or compact.size()!=11: return
	var data={"phase":compact[0],"map":compact[1],"mode":compact[2],"time":compact[3],"duration":compact[4],"remaining":compact[5],"scores":compact[6],"limit":compact[7],"pickups":compact[8],"grenades":[],"players":{},"protocol":2}
	for g in compact[9]: data.grenades.append({"p":g[0],"v":g[1],"life":g[2],"by":g[3],"type":g[4],"burn":g[5],"pulse":g[6]})
	for packed_player in compact[10]:
		var p={}
		for i in range(SNAPSHOT_KEYS.size()): p[SNAPSHOT_KEYS[i]]=packed_player[i]
		data.players[int(p.id)]=p
	var previous=state.get("phase","")
	state=data
	last_snapshot=now()
	metrics.snapshots+=1
	snapshots.append({"received":now(),"state":data})
	while snapshots.size()>12: snapshots.pop_front()
	if state.players.has(local_id):
		var authoritative=state.players[local_id]
		var previous_position: Vector2=prediction.get("p",authoritative.p)
		prediction=authoritative.duplicate(true)
		pending=pending.filter(func(i): return i.seq>authoritative.seq)
		for input in pending: GameSim.move(prediction,input,ArenaMaps.data(map_id).platforms,GameSim.DT)
		var correction=previous_position-prediction.p
		visual_error=(visual_error+correction).limit_length(80) if correction.length()<160 and authoritative.hp>0 else Vector2.ZERO
	if previous!=state.phase: changed.emit()

@rpc("authority","call_remote","reliable",2)
func game_effects(events: Array) -> void:
	_record_events(events)
	effects.emit(events)

func _record_events(events: Array) -> void:
	for event in events:
		if event.kind=="shot": metrics.shots+=1
		if event.kind=="hit": metrics.hits+=1
		if event.kind=="kill": metrics.kills+=1

func render_players() -> Dictionary:
	if is_host: return state.get("players",{})
	var result=state.get("players",{}).duplicate(true)
	var target=now()-0.10
	if snapshots.size()>=2:
		var a=snapshots[0]
		var b=snapshots[-1]
		for frame in snapshots:
			if frame.received<=target: a=frame
			if frame.received>=target:
				b=frame
				break
		var alpha=clampf((target-a.received)/maxf(0.001,b.received-a.received),0,1)
		for id in result:
			if a.state.players.has(id) and b.state.players.has(id): result[id].p=a.state.players[id].p.lerp(b.state.players[id].p,alpha)
	if result.has(local_id) and not prediction.is_empty():
		result[local_id].p=prediction.p+visual_error
		result[local_id].v=prediction.v
		result[local_id].jet=prediction.jet
		result[local_id].aim=prediction.aim
	return result

func bot_input(id: int) -> Dictionary:
	var p=state.players[id];var target: Dictionary={};var distance=INF
	for other in state.players.values():
		if other.id==id or other.hp<=0 or not other.online or (mode_id==1 and other.team==p.team):continue
		var d=p.p.distance_to(other.p)
		if d<distance:target=other;distance=d
	var input=GameSim.blank()
	if target.is_empty():return input
	var map=ArenaMaps.data(map_id);var goal: Vector2=target.p
	var visible=GameSim.wall_distance(p.p,(goal-p.p).normalized(),distance,map.platforms)>=distance-25
	for j in range(map.loot.size()):
		var item=map.loot[j]
		if item.kind=="gun" and not p.owned[item.item] and state.pickups[j]<=0 and p.p.distance_to(item.p)<190:
			goal=item.p;visible=false;break
	var aim_goal=(target.p-p.p).angle()+sin(state.time*2+id)*0.08
	input.aim=aim_goal
	input.fire=distance<GameSim.RANGE[int(p.weapon)] and visible
	input.jump=p.ground and fmod(state.time+id,1.5)<0.12
	input.grenade=distance<400 and visible and fmod(state.time+id,8)<0.04
	input.interact=fmod(state.time+id*0.1,0.3)<0.1
	input.weapon=-1;input.time=state.time
	if visible and absf(target.p.y-p.p.y)<140:
		input.x=signf(target.p.x-p.p.x) if absf(target.p.x-p.p.x)>220 else 0
		input.jet=target.p.y<p.p.y-60 and p.fuel>12
		return input
	if not bot_routes.has(id) or state.time-bot_routes[id].time>0.4 or bot_routes[id].goal.distance_to(goal)>150:
		var start=ArenaMaps.navigation_cell(map,p.p);var end=ArenaMaps.navigation_cell(map,goal)
		var path: Array=Array(map.nav.get_point_path(start,end))
		bot_routes[id]={"path":path,"time":state.time,"goal":goal}
	var route=bot_routes[id].path
	while route.size()>1 and p.p.distance_to(route[0])<70:route.pop_front()
	var waypoint: Vector2=route[0] if not route.is_empty() else goal
	input.x=signf(waypoint.x-p.p.x) if absf(waypoint.x-p.p.x)>20 else 0
	input.jet=(waypoint.y<p.p.y-25 or (p.v.y>200 and waypoint.y<p.p.y+25)) and p.fuel>10
	return input

func scan_lan() -> void:
	if is_host: return
	discovery.close()
	discovery.bind(0)
	discovery.set_broadcast_enabled(true)
	discovery.set_dest_address("255.255.255.255",28761)
	discovery.put_packet("SKYBREAK_DISCOVER_V1".to_utf8_buffer())
	# Loopback also makes discovery testable with two clients on one computer.
	discovery.set_dest_address("127.0.0.1",28761)
	discovery.put_packet("SKYBREAK_DISCOVER_V1".to_utf8_buffer())

func _process(delta: float) -> void:
	visual_error=visual_error.lerp(Vector2.ZERO,1-exp(-18*delta))
	while discovery.get_available_packet_count()>0:
		var packet=discovery.get_packet().get_string_from_utf8()
		var ip=discovery.get_packet_ip()
		var from_port=discovery.get_packet_port()
		if is_host and packet=="SKYBREAK_DISCOVER_V1" and state.get("phase","")=="lobby":
			discovery.set_dest_address(ip,from_port)
			discovery.put_packet(JSON.stringify({"game":"Skybreak","name":profile.name+"'s room","port":port,"players":state.players.size()}).to_utf8_buffer())
		elif not is_host:
			var found=JSON.parse_string(packet)
			if found is Dictionary and found.get("game","")=="Skybreak":
				found.ip=ip
				discovered[ip+":"+str(found.port)]=found
				changed.emit()
	if reconnect_at>0 and now()>=reconnect_at:
		reconnect_at=0
		if now()<reconnect_until: _connect_peer()
		else:
			status="RECONNECT TIMED OUT · return to lobby"
			active=false
			changed.emit()
	if active and not is_host and local_id>0 and now()-last_ping>1 and multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
		last_ping=now()
		ping.rpc_id(1,now())

func _live_peer(id: int) -> bool:
	if not multiplayer.get_peers().has(id): return false
	var peer=multiplayer.multiplayer_peer.get_peer(id)
	if transport=="websocket":return peer!=null and peer.get_ready_state()==WebSocketPeer.STATE_OPEN
	return peer!=null and peer.is_active() and peer.get_channels()>=3 and peer.get_state()==ENetPacketPeer.STATE_CONNECTED

func _configure_peer(id: int) -> void:
	var peer=multiplayer.multiplayer_peer.get_peer(id)
	if transport=="websocket":
		if not OS.has_feature("web"):peer.set_no_delay(true)
	else:peer.set_timeout(8,1500,5000)

func _can_snapshot(id: int) -> bool:
	if not _live_peer(id):return false
	# Slow clients get the next fresh snapshot instead of an ever-growing TCP queue.
	if transport=="websocket":return multiplayer.multiplayer_peer.get_peer(id).get_current_outbound_buffered_amount()<16384
	return true

func _physics_process(_delta: float) -> void:
	if not active or not is_host: return
	tick_count+=1
	for peer in packet_times.keys():
		var rate=packet_times[peer]
		if not peers.has(peer) and now()-rate.joined>5:
			multiplayer.multiplayer_peer.disconnect_peer(peer)
			packet_times.erase(peer)
		elif peers.has(peer) and now()-rate.get("last",now())>0.25: inputs.erase(peers[peer])
	for id in grace.keys():
		if now()>grace[id]:
			state.players.erase(id)
			lobby_players.erase(id)
			grace.erase(id)
			_broadcast_lobby()
	if state.phase=="match":
		for id in state.players:
			if id>=100: inputs[id]=bot_input(id)
		var before=state.phase
		var events=GameSim.tick(state,inputs,history)
		var positions={}
		for id in state.players: positions[id]=state.players[id].p
		history.append({"time":state.time,"players":positions})
		while history.size()>16: history.pop_front()
		if not events.is_empty():
			_record_events(events)
			effects.emit(events)
			for peer in peers:
				if _live_peer(peer): game_effects.rpc_id(peer,events)
		if before!=state.phase: changed.emit()
	if tick_count%3==0:
		var compact_players: Array=[]
		for p in state.players.values():
			var packed_player: Array=[]
			for key in SNAPSHOT_KEYS: packed_player.append(p[key])
			compact_players.append(packed_player)
		var compact_grenades: Array=[]
		for g in state.grenades: compact_grenades.append([g.p,g.v,g.life,g.by,g.type,g.burn,g.pulse])
		var raw=var_to_bytes([state.phase,state.map,state.mode,state.time,state.duration,state.remaining,state.scores,state.limit,state.pickups,compact_grenades,compact_players])
		var packed=raw.compress(FileAccess.COMPRESSION_ZSTD)
		metrics.max_snapshot_bytes=maxi(metrics.max_snapshot_bytes,packed.size())
		for peer in peers:
			if _can_snapshot(peer): snapshot.rpc_id(peer,packed,raw.size())
