class_name PilotControls
extends RefCounted
const GameSim = preload("res://scripts/sim.gd")
# UI and mobile adapters can supply the exact same intention schema as desktop.
# No controller ever supplies positions, damage, ammo, kills, or score.
var weapon=-1
var grenade_type=0
var last_q=false
var armed=false
var touch_enabled=false
var touch_intent: Dictionary={}

func read(aim_origin: Vector2, mouse_world: Vector2, blocked: bool=false) -> Dictionary:
	var input=GameSim.blank()
	input.weapon=weapon
	input.grenade_type=grenade_type
	if blocked:
		armed=false
		return input
	if touch_enabled:
		for key in input:
			if touch_intent.has(key): input[key]=touch_intent[key]
		return input
	# A menu click must be released before it can fire in the arena.
	if not armed:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): armed=true
		return input
	for j in range(6):
		if Input.is_physical_key_pressed(KEY_1+j): weapon=j
	var q=Input.is_physical_key_pressed(KEY_Q)
	if q and not last_q: grenade_type=(grenade_type+1)%3
	last_q=q
	input.x=float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	input.jump=Input.is_physical_key_pressed(KEY_SPACE)
	input.jet=Input.is_physical_key_pressed(KEY_W) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_physical_key_pressed(KEY_UP)
	input.fire=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	input.grenade=Input.is_physical_key_pressed(KEY_G)
	input.reload=Input.is_physical_key_pressed(KEY_R)
	input.interact=Input.is_physical_key_pressed(KEY_E)
	input.grenade_type=grenade_type
	input.aim=(mouse_world-aim_origin).angle()
	input.weapon=weapon
	weapon=-1
	return input
