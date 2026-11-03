extends Node
var enabled=true
var volume=0.55
var pool: Array=[]
var clips: Dictionary={}
var jet: AudioStreamPlayer

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		enabled=false
		return
	clips.shot=make_sound(0.13,0)
	clips.scatter=make_sound(0.24,1)
	clips.volt=make_sound(0.22,2)
	for weapon in range(6):clips["gun_"+str(weapon)]=load("res://assets/audio/weapon_"+str(weapon)+".wav")
	clips.boom=make_sound(0.7,3)
	clips.hit=make_sound(0.07,4)
	for i in range(14):
		var p=AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	jet=AudioStreamPlayer.new()
	var sound=make_sound(1.0,5)
	sound.loop_mode=AudioStreamWAV.LOOP_FORWARD
	sound.loop_end=22050
	jet.stream=sound
	add_child(jet)

func make_sound(duration: float, kind: int) -> AudioStreamWAV:
	var rate=22050
	var samples=int(duration*rate)
	var bytes=PackedByteArray()
	bytes.resize(samples*2)
	var rng=RandomNumberGenerator.new()
	rng.seed=kind+117
	var filtered=0.0
	for i in range(samples):
		var t=float(i)/rate
		var envelope=pow(1-float(i)/samples,2)
		var noise=rng.randf_range(-1,1)
		filtered=lerpf(filtered,noise,0.12 if kind==3 else 0.35)
		var sample=0.0
		match kind:
			0: sample=(noise*0.45+sin(t*(210-t*900)*TAU)*0.3)*envelope
			1: sample=(filtered*0.9+sin(t*90*TAU)*0.25)*envelope
			2: sample=sin(t*(680-t*1600)*TAU)*envelope*0.5+noise*0.1*envelope
			3: sample=(filtered+sin(t*(48-t*25)*TAU)*0.5)*envelope
			4: sample=sin(t*1200*TAU)*envelope*0.3
			5: sample=filtered*0.3+sin(t*80*TAU)*0.04
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*22000))
	var wav=AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=rate
	wav.data=bytes
	return wav

func play(kind: String, weight: float=1.0) -> void:
	if not enabled or volume<=0 or weight<=0.01 or not clips.has(kind): return
	for p in pool:
		if not p.playing:
			p.stream=clips[kind]
			p.volume_db=linear_to_db(maxf(0.001,volume*weight))
			p.pitch_scale=randf_range(0.95,1.05)
			p.play()
			return

func set_jet(on: bool) -> void:
	if not is_instance_valid(jet): return
	jet.volume_db=linear_to_db(maxf(0.001,volume*0.5))
	if on and enabled and volume>0:
		if not jet.playing: jet.play()
	else: jet.stop()

func shutdown() -> void:
	for p in pool:
		p.stop()
		p.stream=null
	if is_instance_valid(jet):
		jet.stop()
		jet.stream=null
	clips.clear()

func _exit_tree() -> void:
	shutdown()
