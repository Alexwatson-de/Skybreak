extends Node2D
const ArenaMaps = preload("res://scripts/maps.gd")
const GameSim = preload("res://scripts/sim.gd")
const PilotArt = preload("res://scripts/art.gd")
const PilotControls = preload("res://scripts/controls.gd")

var selected_armory=1
var selected_character=0
var selected_map=0
var selected_mode=0
var screen="menu"
var ui: Control
var content: VBoxContainer
var status_label: Label
var toast_label: Label
var toast_until=0.0
var view: Node2D
var audio: Node
var controls=PilotControls.new()
var settings=ConfigFile.new()
var player_name="Pilot"
var address="127.0.0.1"
var lobby_url="http://127.0.0.1:3000"
var port_value=28760
var room_code=""
var paused=false
var args: Dictionary={}
var auto=false
var started_at=0.0
var report_written=false
var captured=false
var dropped=false
var lobby_dropped=false
var online_start_sent=false
var last_phase=""
var fullscreen=false
var settings_volume=0.55
var discovery_box: VBoxContainer
var closing=false
var browser_report_at=0.0
var chat_draft=""
var chat_entry: LineEdit

func mobile_controls_active() -> bool:
	# --touch is useful for desktop QA, while exported Android builds enable this
	# automatically. The controls still submit the same intent dictionary as a
	# keyboard/mouse player, so the server remains authoritative.
	return OS.has_feature("mobile") or args.has("touch")

func _ready() -> void:
	if DisplayServer.get_name()=="headless":Engine.max_fps=60
	for item in OS.get_cmdline_user_args():
		var part=item.trim_prefix("--").split("=",true,1)
		args[part[0]]=part[1] if part.size()>1 else true
	if settings.load("user://settings.cfg")==OK:
		player_name=str(settings.get_value("pilot","name","Pilot"))
		selected_character=int(settings.get_value("pilot","character",0))
		lobby_url=str(settings.get_value("network","lobby",lobby_url))
		settings_volume=float(settings.get_value("audio","volume",0.55))
	lobby_url=str(args.get("lobby",lobby_url))
	player_name=str(args.get("name",player_name))
	selected_map=clampi(int(args.get("map",0)),0,ArenaMaps.NAMES.size()-1)
	selected_mode=clampi(int(args.get("mode",0)),0,1)
	Net.profile={"name":player_name,"char":selected_character}
	Net.map_id=selected_map
	Net.mode_id=selected_mode
	audio=load("res://scripts/audio.gd").new()
	add_child(audio)
	audio.volume=settings_volume
	view=load("res://scripts/arena_view.gd").new()
	view.main=self
	add_child(view)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	Net.changed.connect(_network_changed)
	Net.notice.connect(toast)
	Lobby.changed.connect(_lobby_changed)
	Lobby.error.connect(toast)
	auto=args.has("auto")
	started_at=Net.now()
	if args.has("server"):
		var roster: Array=[]
		if args.has("roster"):
			var file=FileAccess.open(str(args.roster),FileAccess.READ)
			if file: roster=JSON.parse_string(file.get_as_text())
		var err=Net.host(int(args.get("port",28760)),true,roster,str(args.get("transport","enet")))
		if err!=OK: get_tree().quit(1);return
		Net.state.duration=float(args.get("duration",300))
		Net.state.limit=int(args.get("limit",15))
		Net.start_match()
		screen="game"
	elif args.has("host"):
		Net.host(int(args.get("port",28760)))
		screen="lobby"
		if args.has("bots"):
			for i in range(int(args.bots)): Net.add_bot()
		if args.has("autostart"):
			Net.state.duration=float(args.get("duration",300))
			Net.start_match()
	elif args.has("join"):
		Net.join_game(str(args.join),int(args.get("port",28760)),str(args.get("token","")))
		screen="lobby"
	elif args.has("websocket"):
		Net.join_websocket(str(args.websocket),str(args.get("token","")))
		screen="lobby"
	elif args.has("online"):
		screen="online"
		lobby_url=str(args.online)
		if args.has("create"):
			Lobby.pending_action={"event":"create","data":{"map":selected_map,"mode":selected_mode}}
		elif args.has("room"):
			Lobby.pending_action={"event":"join","data":{"code":str(args.room)}}
		Lobby.connect_service(lobby_url)
	elif args.has("demo"): practice()
	elif args.has("screen"): screen=str(args.screen)
	if args.has("scan"): Net.scan_lan()
	controls.touch_enabled=mobile_controls_active()
	build_ui()

func save_settings() -> void:
	settings.set_value("pilot","name",player_name)
	settings.set_value("pilot","character",selected_character)
	settings.set_value("network","lobby",lobby_url)
	settings.set_value("audio","volume",audio.volume)
	settings.save("user://settings.cfg")

func toast(message: String) -> void:
	toast_until=Net.now()+5
	if is_instance_valid(toast_label): toast_label.text=message
	print("NOTICE ",message)

func _network_changed() -> void:
	if Net.active and Net.state.get("phase","") in ["match","results"]:
		screen="game"
		controls.armed=false
		paused=false
	elif Net.active: screen="online_lobby" if not Lobby.room.is_empty() else "lobby"
	elif screen=="game": screen="connection_lost"
	if is_inside_tree() and ui: build_ui()

func _lobby_changed() -> void:
	if not Lobby.room.is_empty():
		selected_map=clampi(int(Lobby.room.get("map",0)),0,ArenaMaps.NAMES.size()-1)
		selected_mode=clampi(int(Lobby.room.get("mode",0)),0,1)
	if not Lobby.room.is_empty() and Net.state.get("phase","") not in ["match","results"]: screen="online_lobby"
	if auto and not Lobby.room.is_empty() and Lobby.room.get("phase","")=="lobby":
		var everyone_ready=true
		for p in Lobby.room.players:
			if p.id==Lobby.player_id and not p.ready: Lobby.send_event("ready",{"ready":true})
			if not p.ready: everyone_ready=false
		if Lobby.room.host==Lobby.player_id and Lobby.room.players.size()>=2 and everyone_ready and not online_start_sent:
			online_start_sent=true
			Lobby.send_event("start")
	if not Lobby.room.is_empty(): print("ROOM_CODE ",Lobby.room.code)
	if is_inside_tree() and ui: build_ui()

func style(color: Color,border: Color=Color("505a46"),radius: int=9) -> StyleBoxFlat:
	var result=StyleBoxFlat.new()
	result.bg_color=color;result.border_color=border;result.set_corner_radius_all(radius);result.set_border_width_all(1)
	result.content_margin_left=18;result.content_margin_right=18;result.content_margin_top=11;result.content_margin_bottom=11
	return result

func label(text: String, size: int=18, color: Color=Color("e8dfc3"), parent: Node=null) -> Label:
	var l=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	(parent if parent else content).add_child(l)
	return l

func gap(height: int=12, parent: Node=null) -> void:
	var c=Control.new()
	c.custom_minimum_size.y=height
	(parent if parent else content).add_child(c)

func button(text: String,callback: Callable,primary: bool=false,parent: Node=null) -> Button:
	var result=Button.new();result.text=text;result.custom_minimum_size=Vector2(0,49)
	result.alignment=HORIZONTAL_ALIGNMENT_LEFT;result.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS;result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	result.add_theme_font_size_override("font_size",16)
	result.add_theme_stylebox_override("normal",style(Color("e5bb76") if primary else Color("293425"),Color("e5bb76") if primary else Color("515d46")))
	result.add_theme_stylebox_override("hover",style(Color("f1d399") if primary else Color("3a4931"),Color("debd7d")))
	result.add_theme_stylebox_override("pressed",style(Color("bd985b") if primary else Color("465638")))
	result.add_theme_stylebox_override("focus",style(Color(0,0,0,0),Color("d0b476")))
	result.add_theme_color_override("font_color",Color("292b1e") if primary else Color("d7dec5"))
	result.add_theme_color_override("font_hover_color",Color("292b1e") if primary else Color("f2e4c5"))
	result.pressed.connect(callback);(parent if parent else content).add_child(result)
	return result

func field(placeholder: String, value: String, callback: Callable, parent: Node=null) -> LineEdit:
	var e=LineEdit.new()
	e.placeholder_text=placeholder
	e.text=value
	e.custom_minimum_size.y=48
	e.add_theme_stylebox_override("normal",style(Color("1d281b")))
	e.add_theme_stylebox_override("focus",style(Color("2a3724"),Color("d2b477")))
	e.add_theme_font_size_override("font_size",17)
	e.text_changed.connect(callback)
	(parent if parent else content).add_child(e)
	return e

func choices(items: Array,selected: int,callback: Callable,parent: Node=null) -> OptionButton:
	var result=OptionButton.new()
	for item in items:result.add_item(str(item))
	result.selected=selected;result.custom_minimum_size.y=46
	result.add_theme_font_size_override("font_size",15)
	result.add_theme_stylebox_override("normal",style(Color("263021")))
	result.add_theme_stylebox_override("hover",style(Color("35422d"),Color("bfa66c")))
	result.add_theme_color_override("font_color",Color("dae0c7"))
	result.item_selected.connect(callback);(parent if parent else content).add_child(result)
	return result

func navigate(destination: String) -> void:
	if OS.has_feature("web") and destination=="lan":
		toast("Use online rooms to play with friends in your browser")
		return
	screen=destination
	if destination=="online" and not Lobby.desired:
		sync_profile()
		Lobby.connect_service(lobby_url)
	build_ui()

func build_ui() -> void:
	if closing or DisplayServer.get_name()=="headless":return
	var restore_chat=is_instance_valid(chat_entry) and chat_entry.has_focus()
	var chat_caret=chat_entry.caret_column if is_instance_valid(chat_entry) else 0
	chat_entry=null
	for child in ui.get_children():ui.remove_child(child);child.queue_free()
	var playing=screen=="game"
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN if playing and not paused and Net.state.get("phase","")!="results" else Input.MOUSE_MODE_VISIBLE
	if not playing:
		var top=Panel.new();top.position=Vector2(34,24);top.size=Vector2(1372,72)
		top.add_theme_stylebox_override("panel",style(Color(0.09,0.12,0.085,0.97),Color("4c583f"),12));ui.add_child(top)
		var brand=label("SKYBREAK",27,Color("ead39c"),ui);brand.position=Vector2(59,35)
		var sub=label("A R E N A",12,Color("aab59a"),ui);sub.position=Vector2(232,49)
		for j in range(4):
			var destinations=["menu","character","armory","settings"]
			var nav=button(["PLAY","OPERATOR","ARMORY","SETTINGS"][j],func():navigate(destinations[j]),screen==destinations[j],ui)
			nav.position=Vector2(664+j*156,36);nav.size=Vector2(145,48);nav.custom_minimum_size.y=48
		var wide=screen in ["lobby","online_lobby"]
		var base=Panel.new();base.position=Vector2(52,136);base.size=Vector2(732 if wide else 488,622)
		base.add_theme_stylebox_override("panel",style(Color(0.085,0.11,0.078,0.97),Color("4b573f"),12));ui.add_child(base)
		var version=label("FIELD UPDATE 1.3  /  ORIGINAL WORLDS. SHARED SKIES.",11,Color("879675"),ui);version.position=Vector2(58,849)
	content=VBoxContainer.new();content.add_theme_constant_override("separation",10)
	if not playing:
		var scroll=ScrollContainer.new();scroll.position=Vector2(76,160);scroll.size=Vector2(684 if screen in ["lobby","online_lobby"] else 438,574)
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;ui.add_child(scroll)
		content.custom_minimum_size.x=672 if screen in ["lobby","online_lobby"] else 426;content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	else:content.position=Vector2(490,270);content.size=Vector2(460,600);ui.add_child(content)
	match screen:
		"menu":menu_ui()
		"character":character_ui()
		"armory":armory_ui()
		"lan":lan_ui()
		"online":online_ui()
		"lobby":lan_lobby_ui()
		"online_lobby":online_lobby_ui()
		"settings":settings_ui()
		"connection_lost":
			title("CONNECTION LOST","Signal interrupted.","The host could not be reached. Try connecting again, or return to the main menu.")
			button("RECONNECT",retry_connection,true);button("RETURN TO MENU",leave_game)
		"game":
			if Net.state.get("phase","")=="results":content.position=Vector2(490,665);button("RETURN TO MENU",leave_game,true)
			elif paused:
				var base=Panel.new();base.position=Vector2(460,235);base.size=Vector2(522,330)
				base.add_theme_stylebox_override("panel",style(Color("202a1d")));ui.add_child(base);ui.move_child(base,0)
				label("TAKE A BREATHER",29,Color("efdfb8"));label("The match continues while this menu is open.",14,Color("a8b694"))
				button("RESUME",func():paused=false;build_ui(),true)
				button("SOUND: "+("ON" if audio.enabled else "OFF"),func():audio.enabled=not audio.enabled;build_ui())
				button("LEAVE MATCH",leave_game)
	status_label=Label.new();status_label.position=Vector2(76,802) if not playing else Vector2(28,78)
	status_label.visible=not playing
	status_label.add_theme_font_size_override("font_size",12);status_label.add_theme_color_override("font_color",Color("a9b992"));ui.add_child(status_label)
	if restore_chat and is_instance_valid(chat_entry):
		chat_entry.grab_focus.call_deferred()
		chat_entry.set_caret_column.call_deferred(mini(chat_caret,chat_entry.text.length()))
	toast_label=Label.new();toast_label.position=Vector2(76,773) if not playing else Vector2(425,125)
	toast_label.add_theme_font_size_override("font_size",14);toast_label.add_theme_color_override("font_color",Color("ebc37e"));ui.add_child(toast_label)

func title(eyebrow: String,heading: String,body: String) -> void:
	label(eyebrow,11,Color("c2ad79"));label(heading,37,Color("f0e1bd"))
	var description=label(body,15,Color("abb79a"));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	gap(9)

func menu_ui() -> void:
	title("ENTER THE UNDERGROUND","Outfly. Outfight.","Jetpack combat through sprawling catacombs. Find your weapon. Own your route.")
	label("MATCH TYPE",11,Color("91a37e"))
	choices(["Deathmatch","Team deathmatch"],selected_mode,func(index):selected_mode=index)
	if OS.has_feature("web"):
		field("Pilot name",player_name,func(v):player_name=v.left(18);Net.profile.name=player_name;save_settings()).max_length=18
		button("PLAY ONLINE",func():navigate("online"),true)
	button("PRACTICE / VS BOTS" if OS.has_feature("web") else "QUICK PLAY",practice,not OS.has_feature("web"))
	label("Solo warm-up / 3 bots / instant deployment",12,Color("a4b18e"))
	gap(3)
	if not OS.has_feature("web"):
		button("PLAY WITH FRIENDS / LOCAL",func():navigate("lan"))
		button("ONLINE ROOMS",func():navigate("online"))
	gap(3)
	label("FIELD NOTES",11,Color("c1ab75"))
	var notes=label("E  Pick up a weapon
Q  Select grenade type    /    G  Throw
1 - 6  Switch collected weapons",14,Color("aab897"))
	for j in range(ArenaMaps.NAMES.size()):
		var card=load("res://scripts/map_card.gd").new();card.map_id=j;card.selected=selected_map==j
		card.position=Vector2(594+(j%3)*266,484+(j/3)*150);card.size=Vector2(252,140);card.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		card.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS;card.pressed.connect(func():selected_map=j;build_ui());ui.add_child(card)

func select_operator(index: int) -> void:
	selected_character=index;Net.profile.char=index;save_settings()
	if Lobby.connected:Lobby.send_event("profile",{"name":player_name,"char":index})
	build_ui()

func character_ui() -> void:
	title("YOUR OPERATOR","Choose your pilot.","A pathfinder, an automaton, a shadow runner and an aviator. Pick your silhouette.")
	field("Pilot name",player_name,func(value):player_name=value.left(18);Net.profile.name=player_name;save_settings()).max_length=18
	for j in range(4):button(PilotArt.NAMES[j]+" / "+PilotArt.ROLES[j],func():select_operator(j),j==selected_character)
	gap(7);label("Identity is saved on this device.",13,Color("a8b594"))
	button("BACK TO PLAY",func():navigate("menu"))

func map_mode_ui() -> void:
	choices(ArenaMaps.NAMES,selected_map,func(i): selected_map=i)
	choices(["DEATHMATCH / Every pilot for themselves","TEAM DEATHMATCH / Azure vs Ember"],selected_mode,func(i): selected_mode=i)

func lan_ui() -> void:
	title("CONNECT / LOCAL", "Same Wi-Fi.\nSame battlefield.", "Host a room or connect by IP on Wi-Fi or a mobile hotspot.")
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	content.add_child(row)
	var hostfield=field("Host IP address",address,func(v): address=v,row)
	hostfield.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var portfield=field("Port",str(port_value),func(v): port_value=clampi(int(v),1024,65535),row)
	portfield.custom_minimum_size.x=100
	button("JOIN BY IP   >",func(): sync_profile();Net.join_game(address.strip_edges(),port_value);screen="lobby";build_ui(),true)
	button("DISCOVER NEARBY ROOMS",func(): Net.scan_lan();toast("Scanning local network…"))
	for found in Net.discovered.values():
		button("> "+found.name+"  /  "+found.ip,func(): sync_profile();Net.join_game(found.ip,int(found.port));screen="lobby";build_ui())
	map_mode_ui()
	button("+   HOST A LOCAL ROOM",func(): sync_profile();Net.map_id=selected_map;Net.mode_id=selected_mode;if_host())
	button("<   BACK",func(): navigate("menu"))

func if_host() -> void:
	if Net.host(port_value)==OK:
		screen="lobby"
		build_ui()

func online_ui() -> void:
	title("PLAY TOGETHER", "Build your squad.", "Create a room or join a friend. Your operator travels with you.")
	var operator_row=HBoxContainer.new();content.add_child(operator_row)
	var portrait=load("res://scripts/portrait.gd").new();portrait.character=selected_character;portrait.custom_minimum_size=Vector2(76,82);operator_row.add_child(portrait)
	var identity=VBoxContainer.new();operator_row.add_child(identity)
	label(PilotArt.NAMES[selected_character],22,PilotArt.COLORS[selected_character],identity)
	label(PilotArt.ROLES[selected_character],11,Color("aebaa0"),identity)
	button("CHANGE OPERATOR",func():navigate("character"),false,identity)
	map_mode_ui()
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);content.add_child(row)
	var code=field("Room code or invite link",room_code,func(v):room_code=v,row);code.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("JOIN",join_online,false,row)
	button("CREATE ROOM",func():sync_profile();Lobby.send_event("profile",{"name":player_name,"char":selected_character});Lobby.send_event("create",{"map":selected_map,"mode":selected_mode}),true)
	button("FIND A MATCH",func():Lobby.send_event("matchmake",{"map":selected_map,"mode":selected_mode}))
	label("CONNECTION",11,Color("95a78b"))
	field("Lobby server URL",lobby_url,func(v):lobby_url=v;save_settings())
	button("RECONNECT" if Lobby.connected else "CONNECT",func():sync_profile();Lobby.connect_service(lobby_url))
	button("BACK TO PLAY",func():navigate("menu"))

func join_online() -> void:
	var code=room_code.strip_edges().to_upper()
	if "ROOM=" in code: code=code.split("ROOM=")[1].split("&")[0]
	Lobby.send_event("join",{"code":code})

func lan_lobby_ui() -> void:
	title("SQUAD / LOCAL", "Ready for takeoff?", "LAN room • "+ArenaMaps.NAMES[Net.map_id])
	if Net.is_host:
		var ips: Array=[]
		for ip in IP.get_local_addresses():
			if "." in ip and ip!="127.0.0.1": ips.append(ip)
		label("HOST: "+(", ".join(ips) if not ips.is_empty() else "127.0.0.1")+":"+str(Net.port),13,Color("b8ef70"))
	for p in Net.lobby_players.values():
		label(("READY / " if p.ready else "-  ")+p.name+"   /   "+("AZURE" if p.team==0 else "EMBER")+(" · offline" if not p.online else ""),17,PilotArt.COLORS[int(p.char)])
	var self_p=Net.lobby_players.get(Net.local_id,{})
	if not self_p.is_empty():
		choices(["AZURE TEAM","EMBER TEAM"],int(self_p.team),func(i): Net.lobby_action("team",i))
		button("UNREADY" if self_p.ready else "READY UP",func(): Net.lobby_action("ready",not self_p.ready),not self_p.ready)
	if Net.is_host:
		button("+  ADD PRACTICE BOT",func(): Net.add_bot())
		button("START MATCH   >",func(): Net.lobby_action("start"),true)
	chat_ui(Net.chat,func(text): Net.lobby_action("chat",text))
	button("<   LEAVE ROOM",leave_game)

func pilot_cards(players: Array) -> void:
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.y=224;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(grid)
	for p in players:
		var card=PanelContainer.new();card.custom_minimum_size=Vector2(326,102);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",style(Color("202d21"),Color("84ac72") if p.ready else Color("455446"),8));grid.add_child(card)
		var row=HBoxContainer.new();card.add_child(row)
		var portrait=load("res://scripts/portrait.gd").new();portrait.character=int(p.char);portrait.custom_minimum_size=Vector2(78,92);row.add_child(portrait)
		var details=VBoxContainer.new();details.add_theme_constant_override("separation",5);row.add_child(details)
		label(str(p.name),18,Color("f1e4c7"),details)
		label(PilotArt.NAMES[int(p.char)],12,PilotArt.COLORS[int(p.char)],details)
		label(("READY" if p.ready else "NOT READY")+" / "+("AZURE" if p.team==0 else "EMBER") if p.online else "RECONNECTING",11,Color("b5ca9d") if p.ready else Color("94a18b"),details)

func copy_invite(value: String,description: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.Skybreak.copyInvite("+JSON.stringify(value)+")")
	else:DisplayServer.clipboard_set(value)
	toast(description+" copied")

func online_lobby_ui() -> void:
	var room=Lobby.room
	title("SQUAD / "+str(room.get("players",[]).size())+" OF 8", "ROOM "+str(room.get("code","")),ArenaMaps.NAMES[int(room.get("map",0))]+" / "+("TEAM DEATHMATCH" if int(room.get("mode",0))==1 else "DEATHMATCH"))
	if not OS.has_feature("web"):
		var sharing=HBoxContainer.new();sharing.add_theme_constant_override("separation",10);content.add_child(sharing)
		button("COPY ROOM CODE",func():copy_invite(str(room.get("code","")),"Room code"),false,sharing).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button("COPY INVITE LINK",func():copy_invite(str(room.get("invite","")),"Invite link"),false,sharing).size_flags_horizontal=Control.SIZE_EXPAND_FILL

	var own: Dictionary={}
	for p in room.get("players",[]):
		if p.id==Lobby.player_id:own=p
	if not own.is_empty():
		var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",10);content.add_child(actions)
		choices(["AZURE TEAM","EMBER TEAM"],int(own.team),func(i):Lobby.send_event("team",{"team":i}),actions).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button("UNREADY" if own.ready else "READY UP",func():Lobby.send_event("ready",{"ready":not own.ready}),not own.ready,actions).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if room.get("host","")==Lobby.player_id:button("START MATCH",func():Lobby.send_event("start"),true)
	label("PILOTS / "+str(room.get("phase","lobby")).to_upper(),12,Color("a1c9ac"))
	pilot_cards(room.get("players",[]))
	var lines: Array=[]
	for line in room.get("chat",[]):lines.append(str(line.name)+": "+str(line.text))
	chat_ui(lines,func(text):Lobby.send_event("chat",{"text":text}))
	button("LEAVE ROOM",leave_game)

func chat_ui(lines: Array,send: Callable) -> void:
	var base=Panel.new();base.position=Vector2(812,270);base.size=Vector2(568,488)
	base.add_theme_stylebox_override("panel",style(Color(0.09,0.12,0.08,0.97)));ui.add_child(base)
	var chat_box=VBoxContainer.new();chat_box.position=Vector2(834,292);chat_box.size=Vector2(523,442);chat_box.add_theme_constant_override("separation",12);ui.add_child(chat_box)
	label("SQUAD CHAT",17,Color("ddc795"),chat_box)
	var scroll=ScrollContainer.new();scroll.custom_minimum_size.y=314;chat_box.add_child(scroll)
	var messages=VBoxContainer.new();messages.size_flags_horizontal=Control.SIZE_EXPAND_FILL;messages.add_theme_constant_override("separation",9);scroll.add_child(messages)
	if lines.is_empty():label("Say hello before you drop in.",14,Color("849776"),messages)
	for line in lines.slice(maxi(0,lines.size()-12)):
		var item=label(str(line),14,Color("b8c6a5"),messages);item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);chat_box.add_child(row)
	var edit=field("Message your squad...",chat_draft,func(value):chat_draft=value,row);chat_entry=edit;edit.max_length=160;edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var submit=func():
		if not edit.text.strip_edges().is_empty():send.call(edit.text);chat_draft="";edit.text=""
	edit.text_submitted.connect(func(_value):submit.call());button("SEND",submit,false,row)

func settings_ui() -> void:
	title("FLIGHT SYSTEMS", "Your setup.", "Settings are saved on this device.")
	label("MASTER VOLUME",13,Color("8fa9b7"))
	var slider=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=0.01
	slider.value=audio.volume
	slider.value_changed.connect(func(v): audio.volume=v;save_settings())
	content.add_child(slider)
	button("TOGGLE FULLSCREEN",func(): fullscreen=not fullscreen;DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED))
	gap()
	label("FLIGHT MANUAL",14,Color("b8ef70"))
	label("A / D or ← / →     Move\nSpace                      Jump\nW / ↑ or right mouse    Jetpack\nMouse / left mouse      Aim / shoot\n1 - 6                         Switch weapon\nR                              Reload\nE                              Pick up weapon\nQ                              Change grenade\nS / ↓ / Ctrl                 Crouch / crawl\nG                              Throw grenade\nTab                           Scoreboard\nEscape                      Match menu",17,Color("a1b7c3"))
	gap()
	button("<   BACK",func(): navigate("menu"))

func sync_profile() -> void:
	player_name=player_name.strip_edges().left(18)
	if player_name.is_empty(): player_name="Pilot"
	Net.profile={"name":player_name,"char":selected_character}
	save_settings()

func practice() -> void:
	sync_profile()
	controls.weapon=-1
	controls.grenade_type=0
	Net.map_id=selected_map
	Net.mode_id=selected_mode
	# Practice uses the same authoritative tick without a network socket.
	if Net.host(0)!=OK: return
	for i in range(3): Net.add_bot()
	Net.state.duration=float(args.get("duration",300))
	Net.start_match()
	screen="game"
	if ui: build_ui()

func retry_connection() -> void:
	var target=Net.join_info.duplicate()
	if not target.is_empty():
		if target.get("transport","")=="websocket":Net.join_websocket(str(target.host),str(target.get("token","")))
		else:Net.join_game(target.host,int(target.port),str(target.get("token","")))
	else: leave_game()

func leave_game() -> void:
	chat_draft=""
	Net.stop()
	if not Lobby.room.is_empty(): Lobby.send_event("leave")
	Lobby.disconnect_service()
	paused=false
	audio.set_jet(false)
	screen="menu"
	build_ui()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if screen=="game": paused=not paused;build_ui()
		else: navigate("menu")

func _physics_process(_delta: float) -> void:
	if Net.state.get("phase","")!="match" or Net.local_id==0: return
	var player=Net.prediction if not Net.is_host else Net.state.players.get(Net.local_id,{})
	if player.is_empty(): return
	var input: Dictionary
	if auto:
		input=Net.bot_input(Net.local_id)
		# Test clients jump and fly even when their target is behind cover.
		input.jet=input.jet or fmod(Net.now()-started_at,4)<0.7
		input.jump=input.jump or fmod(Net.now()-started_at,2)<0.1
		input.fire=true
	elif DisplayServer.get_name()=="headless":
		input=GameSim.blank()
	else:
		var mouse_world=(get_viewport().get_mouse_position()-view.origin)/view.zoom
		input=controls.read(player.p,mouse_world,paused or Net.reconnect_until>0)
	Net.send_input(input)
	if args.has("adversarial") and Net.sequence%60==0 and not Net.is_host:
		var bad=GameSim.blank()
		bad.x=999.0
		bad.seq=Net.sequence+1
		bad.aim=NAN
		Net.submit_input.rpc_id(1,bad)
	if auto and not Net.is_host and args.has("ready") and Net.state.phase=="lobby": Net.lobby_action("ready",true)

func _process(_delta: float) -> void:
	if OS.has_feature("web") and Net.now()>browser_report_at:
		browser_report_at=Net.now()+1
		view.detail_scale=clampf(float(JavaScriptBridge.eval("window.Skybreak.detail()")),0.6,1.0)
		var report=connection_report()
		report["fps"]=Engine.get_frames_per_second()
		JavaScriptBridge.eval("window.Skybreak.update("+JSON.stringify(report)+")")
	if is_instance_valid(status_label):
		status_label.text=("Lobby connected" if Lobby.connected else Lobby.status) if screen in ["online","online_lobby"] else Net.status.replace(" · ENet","")
	if is_instance_valid(toast_label) and Net.now()>toast_until: toast_label.text=""
	var elapsed=Net.now()-started_at
	if args.has("start-after") and elapsed>float(args["start-after"]) and Net.is_host and Net.state.get("phase","")=="lobby":
		Net.lobby_action("start")
	if args.has("drop-lobby-at") and elapsed>float(args["drop-lobby-at"]) and not lobby_dropped and Lobby.connected:
		lobby_dropped=true
		Lobby.ws.close()
	if args.has("drop-at") and elapsed>float(args["drop-at"]) and not dropped and Net.local_id>0 and not Net.is_host:
		dropped=true
		multiplayer.multiplayer_peer.close()
		Net._disconnected()
	if auto and Net.state.get("phase","")=="lobby" and not Net.is_host and Net.local_id>0:
		var p=Net.lobby_players.get(Net.local_id,{})
		if not p.is_empty() and not p.ready: Net.lobby_action("ready",true)
	if args.has("screenshot") and elapsed>float(args.get("capture-at",3)) and not captured:
		captured=true
		capture.call_deferred(str(args.screenshot))
	if args.has("seconds") and elapsed>=float(args.seconds) and not report_written:
		report_written=true
		write_report()
		closing=true
		audio.shutdown()
		Lobby.disconnect_service()
		Net.stop()
		get_tree().quit()

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img=get_viewport().get_texture().get_image()
	img.save_png(path)

func connection_report() -> Dictionary:
	var players: Array=[]
	for p in Net.state.get("players",{}).values(): players.append({"id":p.id,"name":p.name,"character":p.char,"position":[p.p.x,p.p.y],"hp":p.hp,"ammo":p.ammo,"kills":p.kills,"deaths":p.deaths,"seq":p.seq,"online":p.online,"crouched":p.get("crouched",false)})
	var report={"local_id":Net.local_id,"phase":Net.state.get("phase",""),"metrics":Net.metrics,"players":players,"ping_ms":Net.ping_ms,"status":Net.status,"time":Net.state.get("time",0),"discovered":Net.discovered,"lobby_status":Lobby.status,"room":Lobby.room.get("code",""),"invite_url":Lobby.room.get("invite",""),"room_players":Lobby.room.get("players",[]),"screen":screen,"transport":Net.transport,"map":Net.map_id}
	return report

func write_report() -> void:
	var report=connection_report()
	if args.has("report"):
		var file=FileAccess.open(str(args.report),FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"  "))
	print("TEST_REPORT ",JSON.stringify(report))

func armory_ui() -> void:
	title("SCAVENGE TO SURVIVE","Field armory.","Six guns. Three grenade types. Supplies are scattered throughout each battlefield.")
	for j in range(6):
		button(str(j+1)+"  "+GameSim.WEAPONS[j],func():selected_armory=j;build_ui(),selected_armory==j)
	gap(2)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);content.add_child(row)
	for j in range(3):
		var item=button(["FRAG","IMPACT","FIRE"][j],func():selected_armory=6+j;build_ui(),selected_armory==6+j,row)
		item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
