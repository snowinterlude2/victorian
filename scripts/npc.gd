extends StaticBody3D
## The talking NPC: the Mita model with a procedural idle, plus its brain.

const BrainScript := preload("res://scripts/npc_brain.gd")
const MODEL_PATH := "res://assets/character/npc.glb"
const TARGET_HEIGHT := 1.7

var display_name := "June"
var brain: Node
var _visual: Node3D
var _t := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = TARGET_HEIGHT
	col.shape = cap
	col.position.y = TARGET_HEIGHT * 0.5
	add_child(col)

	_visual = Node3D.new()
	add_child(_visual)
	var model: Node3D = (load(MODEL_PATH) as PackedScene).instantiate()
	_visual.add_child(model)
	_fit_model(model)
	# The glb only ships a walk cycle, so make sure it is not playing and use a code idle.
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()

	brain = BrainScript.new()
	brain.npc_name = display_name
	add_child(brain)


func interact(_by: Node) -> void:
	pass  # main.gd reacts to the player's interacted signal


func face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.1:
		look_at(flat, Vector3.UP, true)


func _process(delta: float) -> void:
	_t += delta
	# idle: slow breathing and a tiny weight shift
	_visual.scale = Vector3.ONE * (1.0 + sin(_t * 1.6) * 0.006)
	_visual.rotation.z = sin(_t * 0.7) * 0.012
	_visual.rotation.y = sin(_t * 0.5) * 0.03


## Scale the imported model to a sensible height and stand it on the floor.
func _fit_model(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y < 0.001:
		return
	var s := TARGET_HEIGHT / box.size.y
	model.scale = Vector3.ONE * s
	model.position.y = -box.position.y * s
