extends Node3D
## XP-style tooltip balloon that floats above the NPC's head and fades out on its own.

const FONT := preload("res://assets/ui/tahoma.ttf")
const MAX_WIDTH := 380.0
const FONT_SIZE := 24

var _viewport: SubViewport
var _panel: PanelContainer
var _label: Label
var _sprite: Sprite3D
var _tween: Tween
var _reveal: Tween
var _hide_timer: SceneTreeTimer


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("FFFFE1")
	box.border_color = Color.BLACK
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", box)
	_viewport.add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.BLACK)
	_panel.add_child(_label)

	_sprite = Sprite3D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.pixel_size = 0.0022
	_sprite.offset = Vector2(0, 0)
	_sprite.centered = true
	_sprite.render_priority = 10
	_sprite.modulate.a = 0.0
	add_child(_sprite)


## Shows or updates the balloon. hold=true keeps it up (while she is still "typing").
func say(text: String, hold := false) -> void:
	_show(text, hold, 0.0)


## Shows the whole balloon at once but reveals the words over `seconds`, in sync with her voice.
func say_timed(text: String, seconds: float) -> void:
	_show(text, true, seconds)


func _show(text: String, hold: bool, reveal_seconds: float) -> void:
	if text == "":
		text = "..."
	_label.text = text
	# size the balloon by measuring the text ourselves (a wrapped Label reports a bogus
	# minimum height until it has been laid out once)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var text_size := Vector2(width, FONT.get_height(FONT_SIZE))
	if width > MAX_WIDTH:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_size = FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, MAX_WIDTH, FONT_SIZE)
		text_size.x = MAX_WIDTH
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size = text_size.ceil()
	var size := text_size.ceil() + Vector2(28, 18)
	_panel.size = size
	_viewport.size = Vector2i(size)
	# grow upwards from the anchor point so long replies don't cover her face
	_sprite.offset = Vector2(0, size.y * 0.5)
	_fade_to(1.0, 0.15)
	_hide_timer = null
	if _reveal:
		_reveal.kill()
	if reveal_seconds > 0.0:
		_label.visible_ratio = 0.0
		_reveal = create_tween()
		_reveal.tween_property(_label, "visible_ratio", 1.0, reveal_seconds * 0.9)
		var t2 := get_tree().create_timer(reveal_seconds + 2.5)
		_hide_timer = t2
		t2.timeout.connect(func(): if _hide_timer == t2: _fade_to(0.0, 0.6))
	else:
		_label.visible_ratio = 1.0
	if not hold:
		var t := get_tree().create_timer(3.0 + text.length() * 0.06)
		_hide_timer = t
		t.timeout.connect(func(): if _hide_timer == t: _fade_to(0.0, 0.6))


func clear() -> void:
	_hide_timer = null
	_fade_to(0.0, 0.3)


func _fade_to(alpha: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_sprite, "modulate:a", alpha, time)
