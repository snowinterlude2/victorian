extends Node
## Microphone -> Whisper (NobodyWho speech-to-text), offline.
## mode "push": record while V is held. mode "free": record when you start speaking and
## send after a short silence. mode "off": typing only.

signal heard(text: String)
signal listening_changed(listening: bool)
signal status(text: String)

const STT_MODEL := "hf://onnx-community/whisper-base"
const PUSH_KEY := KEY_V
const SPEECH_RMS := 0.02      # free talk: louder than this counts as speech
const SILENCE_END := 0.9      # seconds of quiet that ends a free-talk sentence
const MIN_SPEECH := 0.35      # ignore blips shorter than this
const PREROLL := 0.3          # keep a bit of audio from before speech started
# Whisper likes to "hear" these in silence or noise.
const JUNK := ["", "you", "thank you.", "thanks for watching!", "[blank_audio]", "(silence)", "bye.", "."]

var mode := "push"
var active := false:  # true while a conversation is going
	set(v):
		active = v
		if not v:
			_stop(false)

var _stt
var _capture: AudioEffectCapture
var _rate := 44100.0
var _samples := PackedFloat32Array()
var _preroll := PackedFloat32Array()
var _recording := false
var _speech_time := 0.0
var _silence := 0.0
var _busy := false


func _ready() -> void:
	_rate = AudioServer.get_mix_rate()
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Mic")
	AudioServer.set_bus_mute(bus, true)  # don't play your own voice back
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, _capture)
	var mic := AudioStreamPlayer.new()
	mic.stream = AudioStreamMicrophone.new()
	mic.bus = "Mic"
	add_child(mic)
	mic.play()
	_load_model()


func is_ready() -> bool:
	return _stt != null


func _load_model() -> void:
	status.emit("Loading speech recognition...")
	_stt = await NobodyWhoSpeechToText.create(STT_MODEL, {"language": "en"})
	status.emit("" if _stt else "Speech recognition failed to load. Typing still works.")


func _process(delta: float) -> void:
	var frames := _capture.get_frames_available()
	if frames == 0:
		return
	var buf := _capture.get_buffer(frames)
	if not active or mode == "off" or _busy or _stt == null:
		return
	var mono := PackedFloat32Array()
	mono.resize(buf.size())
	var energy := 0.0
	for i in buf.size():
		var s := (buf[i].x + buf[i].y) * 0.5
		mono[i] = s
		energy += s * s
	var rms := sqrt(energy / max(1, buf.size()))
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
	if not _recording:
		_preroll.append_array(mono)
		var keep := int(PREROLL * _rate)
		if _preroll.size() > keep:
			_preroll = _preroll.slice(_preroll.size() - keep)
		if rms > SPEECH_RMS:
			_start()
			_samples.append_array(_preroll)
		return
	_samples.append_array(mono)
	if rms > SPEECH_RMS:
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
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size():
		pcm.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var text: String = await _stt.transcribe_pcm(pcm, int(_rate))
	text = text.strip_edges()
	_busy = false
	status.emit("")
	if not text.to_lower() in JUNK:
		heard.emit(text)
