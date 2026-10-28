extends Node3D
## June's voice: NobodyWho Kokoro text-to-speech (offline, ~330 MB download on first use),
## played from her position so it sounds like it comes from her.

signal speaking_changed(speaking: bool)

const TTS_MODEL := "hf://NobodyWho/Kokoro-82M"
const VOICE := "af_heart"  # other American women: af_bella, af_sarah, af_nicole, af_sky, af_nova
const SETTINGS_PATH := "user://settings.cfg"

var enabled := true
var volume_db := 0.0
var speaking := false

var _tts
var _player: AudioStreamPlayer3D
var _ticket := 0  # newest request wins, so old replies never talk over new ones


func _ready() -> void:
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


func say(text: String) -> void:
	if not enabled or text.strip_edges() == "" or text == "...":
		return
	_ticket += 1
	var mine := _ticket
	if _tts == null:
		await _load()
		if _tts == null or mine != _ticket:
			return
	var wav: PackedByteArray = await _tts.synthesize(text)
	if mine != _ticket or wav.is_empty():
		return
	_player.stream = AudioStreamWAV.load_from_buffer(wav)
	_player.volume_db = volume_db
	_player.play()
	_set_speaking(true)


func _load() -> void:
	if _tts != null:
		return
	_tts = await NobodyWhoTextToSpeech.create(TTS_MODEL, {"voice": VOICE, "language": "en-us", "speed": 1.0})


func _set_speaking(on: bool) -> void:
	if speaking != on:
		speaking = on
		speaking_changed.emit(on)
