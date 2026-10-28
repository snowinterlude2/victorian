extends Control
## Windows XP (Luna) styled chat window. Text only.

signal message_sent(text: String)
signal closed

const FONT := preload("res://assets/ui/tahoma.ttf")
const DING := preload("res://assets/ui/ding.wav")
const LOGO := preload("res://assets/ui/logo.png")

const BLUE := Color("0A246A")
const TITLE_A := Color("0058EE")
const FACE := Color("ECE9D8")

var _title: Label
var _log: RichTextLabel
var _input: LineEdit
var _send: Button
var _status: Label
var _sfx: AudioStreamPlayer
var _npc_name := ""
var _lines: Array[String] = []
var _reply_index := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()

	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(560, 400)
	win.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win.grow_vertical = Control.GROW_DIRECTION_BOTH
	win.add_theme_stylebox_override("panel", _box(TITLE_A, 3, Color("0831D9")))
	add_child(win)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	win.add_child(col)

	# title bar
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(TITLE_A, 0, TITLE_A, 4))
	col.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	var icon := TextureRect.new()
	icon.texture = LOGO
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar_row.add_child(icon)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_font_size_override("font_size", 14)
	bar_row.add_child(_title)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(24, 22)
	var red := _box(Color("D8522B"), 1, Color.WHITE, 0)
	close.add_theme_stylebox_override("normal", red)
	close.add_theme_stylebox_override("hover", _box(Color("EE7048"), 1, Color.WHITE, 0))
	close.add_theme_stylebox_override("pressed", _box(Color("B03A18"), 1, Color.WHITE, 0))
	close.add_theme_color_override("font_color", Color.WHITE)
	close.pressed.connect(close_window)
	bar_row.add_child(close)

	# body
	var body := PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", _box(FACE, 0, FACE, 8))
	col.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	body.add_child(inner)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_stylebox_override("normal", _box(Color.WHITE, 2, Color("7F9DB9"), 6))
	_log.add_theme_color_override("default_color", Color.BLACK)
	inner.add_child(_log)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("6B6B6B"))
	inner.add_child(_status)

	var row := HBoxContainer.new()
	inner.add_child(row)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.placeholder_text = "Type a message..."
	_input.text_submitted.connect(func(_t): _submit())
	row.add_child(_input)
	_send = Button.new()
	_send.text = "Send"
	_send.custom_minimum_size = Vector2(70, 0)
	_send.pressed.connect(_submit)
	row.add_child(_send)

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = DING
	add_child(_sfx)


func open(npc_name: String, first_line: String) -> void:
	_npc_name = npc_name
	_title.text = "%s - Instant Messenger" % npc_name
	_lines.clear()
	_reply_index = -1
	_say(npc_name, first_line)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_input.grab_focus()


func close_window() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_window()
		get_viewport().set_input_as_handled()


func set_status(text: String) -> void:
	if _status:
		_status.text = text


func begin_reply() -> void:
	_send.disabled = true
	_input.editable = false
	_status.text = "%s is typing..." % _npc_name
	_lines.append("[b][color=#B3261E]%s:[/color][/b] " % _npc_name)
	_reply_index = _lines.size() - 1
	_render()


func update_reply(text: String) -> void:
	if _reply_index >= 0:
		_lines[_reply_index] = "[b][color=#B3261E]%s:[/color][/b] %s" % [_npc_name, _esc(text)]
		_render()


func end_reply(text: String) -> void:
	update_reply(text)
	_reply_index = -1
	_status.text = ""
	_send.disabled = false
	_input.editable = true
	_input.grab_focus()
	_sfx.play()


func _submit() -> void:
	var t := _input.text.strip_edges()
	if t == "" or _send.disabled:
		return
	_input.clear()
	_lines.append("[b][color=#0A246A]You:[/color][/b] %s" % _esc(t))
	_render()
	message_sent.emit(t)


func _say(who: String, text: String) -> void:
	_lines.append("[b][color=#B3261E]%s:[/color][/b] %s" % [who, _esc(text)])
	_render()


func _render() -> void:
	_log.text = "\n".join(_lines)


func _esc(t: String) -> String:
	return t.replace("[", "[lb]")


func _box(bg: Color, border: int, border_color: Color, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border)
	s.border_color = border_color
	s.set_content_margin_all(pad)
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 13
	var btn := _box(Color("F4F3EE"), 1, Color("003C74"), 4)
	btn.set_corner_radius_all(3)
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", _box(Color("FFF3D0"), 1, Color("E2A02A"), 4))
	th.set_stylebox("pressed", "Button", _box(Color("D6D2C2"), 1, Color("003C74"), 4))
	th.set_stylebox("disabled", "Button", _box(Color("E0DFD8"), 1, Color("A0A0A0"), 4))
	th.set_color("font_color", "Button", Color.BLACK)
	th.set_stylebox("normal", "LineEdit", _box(Color.WHITE, 1, Color("7F9DB9"), 4))
	th.set_color("font_color", "LineEdit", Color.BLACK)
	return th
