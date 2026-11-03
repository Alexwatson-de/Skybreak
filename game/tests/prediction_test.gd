extends SceneTree
const Sim=preload("res://scripts/sim.gd")
var checks=0
var failures=0
var feedback: Array=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
	else:print("PASS ",message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var net=root.get_node("Net")
	net.stop();net.local_id=1;net.map_id=0
	var pilot=Sim.player(1,"Local",0,0,Vector2(300,310))
	net.state={"players":{1:pilot.duplicate(true)}};net.prediction=pilot.duplicate(true)
	net.effects.connect(func(events):feedback.append_array(events))
	var input=Sim.blank();input.fire=true;input.seq=1
	net._predict_shot(input)
	check(feedback.size()==1 and net.predicted_shots.size()==1,"local firing feedback arrives before a server response")
	check(net.state.players[1].ammo[0]==12 and net.prediction.ammo[0]==12,"visual feedback cannot award or consume authoritative ammo")
	check(net.metrics.shots==0 and net.state.players[1].hp==100,"visual feedback cannot count confirmed shots or damage")
	net._predict_shot(input)
	check(feedback.size()==1,"predicted feedback respects weapon fire rate")
	net.state.players[1].seq=1;net.state.players[1].ammo[0]=11
	net.reconcile_needed=true;net._reconcile_prediction()
	check(net.predicted_shots.is_empty() and net.prediction.ammo[0]==11,"server acknowledgement clears pending cosmetic shots")
	net.next_local_shot=0;net.prediction.ammo[0]=0;net._predict_shot(input)
	check(feedback.size()==1,"empty guns cannot produce predicted firing feedback")
	net.prediction.ammo[0]=12;net.prediction.hp=0;net._predict_shot(input)
	check(feedback.size()==1,"dead players cannot produce predicted firing feedback")
	print("PREDICTION_TESTS checks=",checks," failures=",failures)
	net.stop();quit(1 if failures else 0)
