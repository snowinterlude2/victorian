extends CanvasLayer
## Esc menu in the same WinXP style: voice mode toggle, resume, quit.

signal mode_changed(mode: String)

const FONT := preload("res://assets/ui/tahoma.ttf")
const SETTINGS_PATH := "user://settings.cfg"
const MODES := [
	["push", "Push to talk (hold V)"],
	["free", "Free talk (always listening)"],
	["off", "Off (type with Enter)"],
]

var mode := "push"
var _buttons := {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mode = cfg.get_value("voice", "mode", "push")

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var win := PanelContainer.new()
	win.theme = _theme()
	win.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win.grow_vertical = Control.GROW_DIRECTION_BOTH
	win.custom_minimum_size = Vector2(340, 0)
	win.add_theme_stylebox_override("panel", _box(Color("0058EE"), 3, Color("0831D9"), 0))
	add_child(win)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	win.add_child(col)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(Color("0058EE"), 0, Color("0058EE"), 5))
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 15)
	bar.add_child(title)
	col.add_child(bar)

	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", _box(Color("ECE9D8"), 0, Color("ECE9D8"), 14))
	col.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	body.add_child(inner)

	var head := Label.new()
	head.text = "Voice chat"
	head.add_theme_color_override("font_color", Color("0A246A"))
	inner.add_child(head)
	var group := ButtonGroup.new()
	for m in MODES:
		var cb := CheckBox.new()
		cb.text = m[1]
		cb.button_group = group
		cb.button_pressed = m[0] == mode
		cb.add_theme_color_override("font_color", Color.BLACK)
		cb.add_theme_color_override("font_pressed_color", Color.BLACK)
		cb.add_theme_color_override("font_hover_color", Color("0A246A"))
		cb.toggled.connect(func(on): if on: _set_mode(m[0]))
		inner.add_child(cb)
		_buttons[m[0]] = cb

	var sep := HSeparator.new()
	inner.add_child(sep)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	inner.add_child(row)
	var resume := Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(80, 0)
	resume.pressed.connect(close)
	row.add_child(resume)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(80, 0)
	quit.pressed.connect(func(): get_tree().quit())
	row.add_child(quit)


func _unhandled_key_input(event: InputEvent) -> void:
	# the rest of the game is paused, so the menu closes itself on Esc
	if visible and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_mode(m: String) -> void:
	mode = m
	var cfg := ConfigFile.new()
	cfg.set_value("voice", "mode", m)
	cfg.save(SETTINGS_PATH)
	mode_changed.emit(m)


func _box(bg: Color, border: int, border_color: Color, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border)
	s.border_color = border_color
	s.set_content_margin_all(pad)
	return s


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 14
	var btn := _box(Color("F4F3EE"), 1, Color("003C74"), 5)
	btn.set_corner_radius_all(3)
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", _box(Color("FFF3D0"), 1, Color("E2A02A"), 5))
	th.set_stylebox("pressed", "Button", _box(Color("D6D2C2"), 1, Color("003C74"), 5))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		th.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color.BLACK)
	th.set_color("font_hover_color", "Button", Color.BLACK)
	return th
