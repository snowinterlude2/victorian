extends Node3D
## Builds the room and runs the conversation flow:
## walk into June's zone, look at her (her name shows under the crosshair), press E,
## then talk by voice (push-to-talk or free talk, set in the Esc menu) or press Enter to type.
## Her replies float above her head; you can keep moving the whole time.

const PlayerScript := preload("res://scripts/player.gd")
const NpcScript := preload("res://scripts/npc.gd")
const VoiceScript := preload("res://scripts/voice_input.gd")
const PauseScript := preload("res://scripts/pause_menu.gd")
const FONT := preload("res://assets/ui/tahoma.ttf")

var player: CharacterBody3D
var npc: StaticBody3D
var voice: Node
var pause: CanvasLayer

var in_zone := false
var talking := false
var looking_at_npc := false

var _name_label: Label
var _hint_label: Label
var _mic_label: Label
var _subtitle: Label
var _input: LineEdit
var _subtitle_timer: SceneTreeTimer


func _ready() -> void:
	_build_room()

	player = PlayerScript.new()
	player.position = Vector3(0, 0.1, 4)
	add_child(player)

	npc = NpcScript.new()
	npc.position = Vector3(0, 0, -2.5)
	add_child(npc)

	voice = VoiceScript.new()
	add_child(voice)

	pause = PauseScript.new()
	pause.voice = voice
	add_child(pause)
	voice.mode = pause.mode

	_build_hud()

	player.target_changed.connect(func(t): looking_at_npc = t == npc; _refresh_hud())
	player.interacted.connect(_on_interacted)
	npc.player_entered_zone.connect(func(): in_zone = true; _refresh_hud())
	npc.player_left_zone.connect(_on_left_zone)
	npc.brain.reply_started.connect(func(): npc.bubble.say("...", true))
	npc.brain.reply_progress.connect(func(t): npc.bubble.say(t, true))
	npc.brain.reply_finished.connect(func(t): npc.bubble.say(t))
	npc.brain.status.connect(_show_status)
	voice.heard.connect(_send)
	voice.listening_changed.connect(func(on): _mic_label.text = "● Listening" if on else ""; _refresh_hud())
	voice.status.connect(_show_status)
	pause.mode_changed.connect(func(m): voice.mode = m; _refresh_hud())


func _process(_delta: float) -> void:
	# safety net: if the typing box lost focus for any reason, give the controls back
	if _input.visible and not _input.has_focus():
		_close_input()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_ESCAPE:
		if _input.visible:
			_close_input()
		else:
			pause.open()
		get_viewport().set_input_as_handled()
	elif talking and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not _input.visible:
		_input.visible = true
		_input.clear()
		_input.grab_focus()
		player.locked = true
		get_viewport().set_input_as_handled()


func _on_interacted(target: Object) -> void:
	if target != npc or not in_zone or talking:
		return
	talking = true
	voice.active = true
	npc.face(player.global_position)
	npc.bubble.say(npc.brain.greeting())
	_refresh_hud()


func _on_left_zone() -> void:
	in_zone = false
	if talking:
		talking = false
		voice.active = false
		_close_input()
		npc.brain.save()
	_refresh_hud()


func _send(text: String) -> void:
	text = text.strip_edges()
	if text == "" or not talking:
		return
	_show_subtitle("You: " + text)
	npc.face(player.global_position)
	npc.brain.player_said(text)


func _close_input() -> void:
	_input.visible = false
	_input.release_focus()
	player.locked = false


func _refresh_hud() -> void:
	var show_name := in_zone and (looking_at_npc or talking)
	_name_label.text = npc.display_name if show_name else ""
	if not in_zone:
		_hint_label.text = ""
	elif not talking:
		_hint_label.text = "[E] Talk" if looking_at_npc else ""
	else:
		match voice.mode:
			"push": _hint_label.text = "Hold [V] to speak  ·  [Enter] to type"
			"free": _hint_label.text = "Just talk  ·  [Enter] to type"
			_: _hint_label.text = "[Enter] to type"


func _show_subtitle(text: String) -> void:
	_subtitle.text = text
	var t := get_tree().create_timer(4.0)
	_subtitle_timer = t
	t.timeout.connect(func(): if _subtitle_timer == t: _subtitle.text = "")


func _show_status(text: String) -> void:
	if text != "" and text != "...":
		_show_subtitle(text)


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = FONT
	root.theme = th
	ui.add_child(root)

	var dot := ColorRect.new()  # crosshair
	dot.color = Color(1, 1, 1, 0.85)
	dot.size = Vector2(4, 4)
	dot.position = -dot.size * 0.5
	dot.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(dot)

	_name_label = _hud_label(root, 20, Color.WHITE, 16)
	_hint_label = _hud_label(root, 14, Color(1, 1, 1, 0.75), 44)
	_mic_label = _hud_label(root, 14, Color("FF5A5A"), 66)

	_subtitle = _hud_label(root, 18, Color.WHITE, 0)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_top = -110
	_subtitle.offset_bottom = -80
	_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_input = LineEdit.new()
	_input.visible = false
	_input.placeholder_text = "Say something to %s...  (Enter to send, Esc to cancel)" % npc.display_name
	_input.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_input.offset_left = -260
	_input.offset_right = 260
	_input.offset_top = -64
	_input.offset_bottom = -34
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.92)
	box.border_color = Color("7F9DB9")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(6)
	_input.add_theme_stylebox_override("normal", box)
	_input.add_theme_stylebox_override("focus", box)
	_input.add_theme_color_override("font_color", Color.BLACK)
	_input.add_theme_font_size_override("font_size", 15)
	_input.text_submitted.connect(func(t): _close_input(); _send(t))
	root.add_child(_input)


## A centered label sitting `below` pixels under the crosshair.
func _hud_label(parent: Control, size: int, color: Color, below: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -300
	l.offset_right = 300
	l.offset_top = below
	l.offset_bottom = below + size + 8
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


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
