extends Node3D
## June's voice: NobodyWho Kokoro text-to-speech (offline, ~330 MB download on first use),
## played from her position so it sounds like it comes from her.

signal speaking_changed(speaking: bool)
signal status(text: String)

const TTS_MODEL := "hf://NobodyWho/Kokoro-82M"
const VOICE := "af_heart"  # other American women: af_bella, af_sarah, af_nicole, af_sky, af_nova
const SETTINGS_PATH := "user://settings.cfg"

var enabled := true
var volume_db := 0.0
var speaking := false

var _tts
var _loading := false
var _player: AudioStreamPlayer3D
var _ticket := 0  # newest request wins, so old replies never talk over new ones


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the Test button works while the pause menu is open
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		enabled = cfg.get_value("npc_voice", "enabled", true)
	_player = AudioStreamPlayer3D.new()
	_player.position = Vector3(0, 1.5, 0)
	_player.unit_size = 6.0
	_player.max_distance = 30.0
	_player.finished.connect(func(): _set_speaking(false))
	add_child(_player)
	if enabled:
		_load()


func set_enabled(on: bool) -> void:
	enabled = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("npc_voice", "enabled", on)
	cfg.save(SETTINGS_PATH)
	if on and _tts == null:
		_load()
	if not on:
		stop()


func stop() -> void:
	_ticket += 1
	_player.stop()
	_set_speaking(false)


func is_ready() -> bool:
	return _tts != null


## Synthesises and plays `text`. Returns how many seconds the audio lasts once it has started
## playing (so the caller can sync the balloon), or -1.0 if nothing was played.
func say(text: String) -> float:
	if not enabled or _tts == null or text.strip_edges() == "" or text == "...":
		return -1.0
	_ticket += 1
	var mine := _ticket
	var wav: PackedByteArray = await _tts.synthesize(text)
	if mine != _ticket or wav.is_empty():
		return -1.0
	var stream := AudioStreamWAV.load_from_buffer(wav)
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()
	_set_speaking(true)
	return stream.get_length()


func _load() -> void:
	if _tts != null or _loading:
		return
	_loading = true
	status.emit("Loading June's voice (first time downloads ~330 MB)...")
	_tts = await NobodyWhoTextToSpeech.create(TTS_MODEL, {"voice": VOICE, "language": "en-us", "speed": 1.0})
	_loading = false
	status.emit("June's voice is ready." if _tts else "June's voice failed to load, so she will only show text. Check the Errors tab in Godot.")


func _set_speaking(on: bool) -> void:
	if speaking != on:
		speaking = on
		speaking_changed.emit(on)
