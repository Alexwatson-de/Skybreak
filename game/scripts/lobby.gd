extends Node
# Socket.IO v4 default namespace over Engine.IO v4 WebSocket transport.
# The lobby also advertises the authoritative server's browser-safe WSS gateway.
signal changed
signal error(message: String)
var ws: WebSocketPeer
var endpoint="ws://127.0.0.1:3000"
var session=""
var room: Dictionary={}
var player_id=""
var status="OFFLINE"
var connected=false
var desired=false
var retry_at=0.0
var last_open=0.0
var pending_action: Dictionary={}
var match_info: Dictionary={}
var attempts=0
var give_up_at=0.0

func connect_service(url: String) -> void:
	endpoint=url.trim_suffix("/").replace("https://","wss://").replace("http://","ws://")
	if not endpoint.begins_with("ws://") and not endpoint.begins_with("wss://"):
		error.emit("Use a valid HTTPS lobby address")
		return
	if OS.has_feature("web"):
		session=str(JavaScriptBridge.eval("sessionStorage.getItem("+JSON.stringify("skybreak-session:"+endpoint)+") || ''"))
	desired=true
	attempts=0
	give_up_at=Net.now()+150
	_open()

func _open() -> void:
	ws=WebSocketPeer.new()
	ws.heartbeat_interval=10
	var result=ws.connect_to_url(endpoint+"/socket.io/?EIO=4&transport=websocket")
	status=("WAKING SERVER · first connection can take a minute" if attempts>0 else "CONNECTING") if result==OK else "SERVICE UNREACHABLE"
	attempts+=1
	connected=false
	last_open=Net.now()
	changed.emit()

func disconnect_service() -> void:
	desired=false
	if ws: ws.close()
	connected=false
	room={}
	match_info={}
	session=""
	player_id=""
	status="OFFLINE"

func send_event(event: String, data: Dictionary={}) -> void:
	if connected: ws.send_text("42"+JSON.stringify([event,data]))
	else: error.emit("Connect to the lobby service first")

func _process(_delta: float) -> void:
	if not desired or not ws: return
	ws.poll()
	if ws.get_ready_state()==WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count()>0:
			var packet=ws.get_packet().get_string_from_utf8()
			if packet.begins_with("0"):
				ws.send_text("40"+JSON.stringify({"session":session,"name":Net.profile.name,"char":Net.profile.char,"protocol":3}))
			elif packet=="2": ws.send_text("3")
			elif packet.begins_with("40"):
				connected=true
				attempts=0
				status="CONNECTED · LOBBY"
				changed.emit()
			elif packet.begins_with("42"):
				var data=JSON.parse_string(packet.substr(2))
				if data is Array and data.size()==2: _event(str(data[0]),data[1])
			elif packet.begins_with("44"):
				var reason=JSON.parse_string(packet.substr(2))
				error.emit(str(reason.get("message","Lobby authentication failed")) if reason is Dictionary else "Lobby authentication failed")
	elif ws.get_ready_state()==WebSocketPeer.STATE_CLOSED or Net.now()-last_open>12 and not connected:
		if connected:
			connected=false
			status="LOBBY DISCONNECTED · reconnecting"
			give_up_at=Net.now()+150
			changed.emit()
		if Net.now()>give_up_at:
			desired=false
			status="SERVER UNAVAILABLE · try connecting again"
			error.emit(status)
			changed.emit()
			return
		if retry_at==0: retry_at=Net.now()+minf(8,pow(1.5,attempts))
		if Net.now()>retry_at:
			retry_at=0
			_open()

func _event(event: String, data: Dictionary) -> void:
	match event:
		"session":
			session=data.token
			player_id=data.id
			if OS.has_feature("web"):JavaScriptBridge.eval("sessionStorage.setItem("+JSON.stringify("skybreak-session:"+endpoint)+","+JSON.stringify(session)+")")
			if not pending_action.is_empty():
				send_event(pending_action.event,pending_action.data)
				pending_action={}
		"room":
			room=data
			changed.emit()
		"error_message": error.emit(str(data.message))
		"match":
			match_info=data
			if not (Net.active and Net.auth_token==str(data.token) and Net.local_id>0):
				if data.get("transport","")=="websocket":Net.join_websocket(str(data.websocket),str(data.token))
				else:Net.join_game(str(data.host),int(data.port),str(data.token))
			changed.emit()
		"left":
			room={}
			changed.emit()
