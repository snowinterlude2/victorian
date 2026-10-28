extends Node
## Microphone -> Whisper (NobodyWho speech-to-text), offline.
## mode "push": record while V is held. mode "free": record when you start speaking and
## send after a short silence. mode "off": typing only.
## The mic is always metered (see `level`) so the pause menu can show whether it hears you.

signal heard(text: String)
signal listening_changed(listening: bool)
signal status(text: String)

const STT_MODEL := "hf://onnx-community/whisper-base"
const PUSH_KEY := KEY_V
const BASE_THRESHOLD := 0.02  # free talk: RMS louder than this counts as speech (divided by sensitivity)
const SILENCE_END := 0.9      # seconds of quiet that ends a free-talk sentence
const MIN_SPEECH := 0.35      # ignore blips shorter than this
const PREROLL := 0.3          # keep a bit of audio from before speech started
const TARGET_PEAK := 0.9      # recordings are normalised to this before Whisper hears them
const SETTINGS_PATH := "user://settings.cfg"
# Whisper likes to "hear" these in silence or noise.
const JUNK := ["", "you", "thank you.", "thanks for watching!", "[blank_audio]", "(silence)", "bye.", "."]

var mode := "push"
var sensitivity := 1.0
var suppressed := false  # true while June is speaking, so she does not hear herself
var level := 0.0  # smoothed mic loudness 0..1 (for the meter)
var device := "Default"
var active := false:  # true while a conversation is going
	set(v):
		active = v
		if not v:
			_stop(false)

var _stt
var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
var _rate := 44100.0
var _samples := PackedFloat32Array()
var _preroll := PackedFloat32Array()
var _recording := false
var _speech_time := 0.0
var _silence := 0.0
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep metering while the pause menu is open
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sensitivity = cfg.get_value("voice", "sensitivity", 1.0)
		device = cfg.get_value("voice", "device", "Default")
	_rate = AudioServer.get_mix_rate()
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Mic")
	AudioServer.set_bus_mute(bus, true)  # don't play your own voice back
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, _capture)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "Mic"
	add_child(_mic)
	if device in devices():
		AudioServer.input_device = device
	_mic.play()
	_load_model()


func devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func set_device(name: String) -> void:
	device = name
	AudioServer.input_device = name
	_mic.stop()
	_mic.play()
	_save()


func set_sensitivity(value: float) -> void:
	sensitivity = value
	_save()


func is_ready() -> bool:
	return _stt != null


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("voice", "sensitivity", sensitivity)
	cfg.set_value("voice", "device", device)
	cfg.save(SETTINGS_PATH)


func _load_model() -> void:
	status.emit("Loading speech recognition...")
	_stt = await NobodyWhoSpeechToText.create(STT_MODEL, {"language": "en"})
	status.emit("" if _stt else "Speech recognition failed to load. Typing still works.")


func _process(delta: float) -> void:
	var frames := _capture.get_frames_available()
	if frames == 0:
		level = move_toward(level, 0.0, delta * 2.0)
		return
	var buf := _capture.get_buffer(frames)
	var mono := PackedFloat32Array()
	mono.resize(buf.size())
	var energy := 0.0
	for i in buf.size():
		var s := (buf[i].x + buf[i].y) * 0.5
		mono[i] = s
		energy += s * s
	var rms := sqrt(energy / max(1, buf.size()))
	level = lerpf(level, clampf(rms * 8.0, 0.0, 1.0), 0.4)

	if not active or mode == "off" or _busy or _stt == null or suppressed or get_tree().paused:
		return
	var chunk_time := buf.size() / _rate

	if mode == "push":
		var held := Input.is_physical_key_pressed(PUSH_KEY)
		if held and not _recording:
			_start()
		if _recording:
			_samples.append_array(mono)
			_speech_time += chunk_time
			if not held:
				_stop(true)
		return

	# free talk
	var threshold := BASE_THRESHOLD / maxf(sensitivity, 0.1)
	if not _recording:
		_preroll.append_array(mono)
		var keep := int(PREROLL * _rate)
		if _preroll.size() > keep:
			_preroll = _preroll.slice(_preroll.size() - keep)
		if rms > threshold:
			_start()
			_samples.append_array(_preroll)
		return
	_samples.append_array(mono)
	if rms > threshold:
		_speech_time += chunk_time
		_silence = 0.0
	else:
		_silence += chunk_time
		if _silence >= SILENCE_END:
			_stop(true)


func _start() -> void:
	_recording = true
	_samples.clear()
	_speech_time = 0.0
	_silence = 0.0
	listening_changed.emit(true)


func _stop(send: bool) -> void:
	if not _recording:
		return
	_recording = false
	listening_changed.emit(false)
	if send and _speech_time >= MIN_SPEECH:
		_transcribe(_samples.duplicate())
	_samples.clear()
	_preroll.clear()


func _transcribe(samples: PackedFloat32Array) -> void:
	_busy = true
	status.emit("...")
	# Quiet mics are the usual reason Whisper mishears: normalise the whole clip to a good volume.
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 1.0
	if peak > 0.001:
		gain = minf(TARGET_PEAK / peak, 30.0)
	# Whisper works at 16 kHz anyway, so average every 3 samples to keep the buffer small.
	var step := 3
	var out_rate := int(_rate / step)
	var pcm := PackedByteArray()
	pcm.resize((samples.size() / step) * 2)
	for i in samples.size() / step:
		var v := (samples[i * step] + samples[i * step + 1] + samples[i * step + 2]) / 3.0 * gain
		pcm.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var text: String = await _stt.transcribe_pcm(pcm, out_rate)
	text = text.strip_edges()
	_busy = false
	status.emit("")
	if not text.to_lower() in JUNK:
		heard.emit(text)
