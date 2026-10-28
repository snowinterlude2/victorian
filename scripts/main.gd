extends Node3D
## Builds the room, wires player <-> NPC <-> chat window together.

const PlayerScript := preload("res://scripts/player.gd")
const NpcScript := preload("res://scripts/npc.gd")
const ChatWindowScript := preload("res://scripts/chat_window.gd")

var player: CharacterBody3D
var npc: StaticBody3D
var chat_window: Control
var prompt_label: Label


func _ready() -> void:
	_build_room()

	player = PlayerScript.new()
	player.position = Vector3(0, 0.1, 4)
	add_child(player)

	npc = NpcScript.new()
	npc.position = Vector3(0, 0, -2.5)
	add_child(npc)

	var ui := CanvasLayer.new()
	add_child(ui)

	var dot := ColorRect.new()  # crosshair
	dot.color = Color(1, 1, 1, 0.8)
	dot.size = Vector2(4, 4)
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui.add_child(dot)

	prompt_label = Label.new()
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position.y -= 120
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(prompt_label)

	chat_window = ChatWindowScript.new()
	chat_window.visible = false
	ui.add_child(chat_window)

	player.target_changed.connect(_on_target_changed)
	player.interacted.connect(_on_interacted)
	chat_window.message_sent.connect(npc.brain.player_said)
	chat_window.closed.connect(_on_chat_closed)
	npc.brain.reply_started.connect(chat_window.begin_reply)
	npc.brain.reply_progress.connect(chat_window.update_reply)
	npc.brain.reply_finished.connect(chat_window.end_reply)
	npc.brain.status.connect(chat_window.set_status)


func _on_target_changed(target: Object) -> void:
	prompt_label.text = ("[E]  Talk to %s" % target.display_name) if target else ""


func _on_interacted(target: Object) -> void:
	if target != npc or chat_window.visible:
		return
	player.locked = true
	npc.face(player.global_position)
	prompt_label.text = ""
	chat_window.open(npc.display_name, npc.brain.greeting())


func _on_chat_closed() -> void:
	player.locked = false
	npc.brain.save()


func _build_room() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.environment.ambient_light_energy = 0.5
	add_child(env)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.2, 0)
	lamp.omni_range = 14.0
	lamp.light_energy = 2.0
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.shadow_enabled = true
	add_child(lamp)

	_box(Vector3(12, 0.2, 12), Vector3(0, -0.1, 0), Color(0.35, 0.22, 0.14))   # floor
	_box(Vector3(12, 0.2, 12), Vector3(0, 3.6, 0), Color(0.8, 0.77, 0.7))      # ceiling
	var wall := Color(0.55, 0.2, 0.22)
	_box(Vector3(12, 3.6, 0.2), Vector3(0, 1.8, -6), wall)
	_box(Vector3(12, 3.6, 0.2), Vector3(0, 1.8, 6), wall)
	_box(Vector3(0.2, 3.6, 12), Vector3(-6, 1.8, 0), wall)
	_box(Vector3(0.2, 3.6, 12), Vector3(6, 1.8, 0), wall)
	_box(Vector3(2.2, 0.8, 1.0), Vector3(-3.5, 0.4, -4.5), Color(0.25, 0.15, 0.1))  # a table
	_box(Vector3(0.9, 0.9, 0.9), Vector3(3.5, 0.45, -4.0), Color(0.3, 0.3, 0.38))   # a crate


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
