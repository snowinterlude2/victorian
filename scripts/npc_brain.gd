extends Node
## NobodyWho wrapper: roleplay chat + a tiny "judge" chat that tracks how the player
## makes June feel (rapport) and what she should remember. Memory persists to user://.

signal reply_started
signal reply_progress(text: String)
signal reply_finished(text: String)
signal status(text: String)

# Gemma 3 1B (~800 MB) was the smallest model that stayed in character and remembered
# the player's name in testing. Qwen3 0.6B (~400 MB) is lighter but parrots the player.
const MODEL := "hf://bartowski/google_gemma-3-1b-it-GGUF/google_gemma-3-1b-it-Q4_K_M.gguf"
const SAVE_PATH := "user://june_memory.json"
const MAX_FACTS := 8
const RAPPORT_MIN := -6
const RAPPORT_MAX := 12

var npc_name := "June"
var rapport := 0
var facts: Array[String] = []
var player_name := ""
var _last_delta := 0
var _offtopic := false
var _offtopic_kind := ""
var _offtopic_res: Array[RegEx] = []

var _chat
var _judge
var _loading := false
var _busy := false


func _ready() -> void:
	for pat in Persona.OFFTOPIC_PATTERNS:
		_offtopic_res.append(RegEx.create_from_string("(?i)" + pat))
	_load_memory()
	_start()


func greeting() -> String:
	if facts.is_empty() and rapport == 0:
		return Persona.GREETING_NEW
	if player_name != "":
		return Persona.GREETING_BACK % player_name
	return Persona.GREETING_BACK_NONAME


func player_said(text: String) -> void:
	text = text.strip_edges()
	if text == "" or _busy:
		return
	if _chat == null:
		status.emit("%s is still waking up (loading the model)..." % npc_name)
		return
	_busy = true
	reply_started.emit()
	_offtopic = _is_offtopic(text)
	if _offtopic:
		# never ask the model: brush it off in character
		await get_tree().create_timer(0.4).timeout
		var line := _deflect(_offtopic_kind)
		reply_progress.emit(line)
		reply_finished.emit(line)
		_busy = false
		return
	await _judge_message(text)
	await _chat.set_system_prompt(_system_prompt())
	var stream = _chat.ask(text)
	var full := ""
	while true:
		var token = await stream.next_token()
		if token == null:
			break
		full += token
		reply_progress.emit(_clean(full))
	var final := _clean(full)
	if _sounds_like_assistant(final):
		final = _deflect("trivia")
	reply_finished.emit(final)
	_busy = false


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"rapport": rapport, "facts": facts, "player_name": player_name}))


func _start() -> void:
	if _loading:
		return
	_loading = true
	status.emit("Loading %s's brain (first run downloads ~800 MB, one time only)..." % npc_name)
	# Moderate temperature plus a presence penalty so she doesn't loop the same line.
	var sampler = NobodyWhoSamplerBuilder.new() \
		.penalties(64, 1.1, 0.0, 1.0) \
		.top_k(20) \
		.top_p(0.8, 1) \
		.temperature(0.7) \
		.dist()
	var chat = await NobodyWhoChat.create(MODEL, {
		"system_prompt": _system_prompt(),
		"n_ctx": 2048,
		"sampler": sampler,
		"template_variables": {"enable_thinking": false},
	})
	var judge = await NobodyWhoChat.create(MODEL, {
		"system_prompt": Persona.JUDGE_PROMPT,
		"n_ctx": 512,
		"sampler": NobodyWhoSamplerPresets.greedy(),
		"template_variables": {"enable_thinking": false},
	})
	_loading = false
	if chat == null or judge == null:
		status.emit("Could not load the model. Check the Errors tab in the Godot editor.")
		return
	_judge = judge
	_chat = chat
	status.emit("")


## Scores the player's line and pulls out something worth remembering.
func _judge_message(text: String) -> void:
	var lower := text.to_lower()
	var delta := 0
	if _has_any(lower, Persona.RUDE_WORDS):
		delta = -2
	elif _has_any(lower, Persona.SWEET_WORDS):
		delta = 1
	else:
		await _judge.reset_chat(Persona.JUDGE_PROMPT, [])
		var score_raw: String = await _judge.ask("Player message: " + text).completed()
		match _clean(score_raw).left(1):
			"1": delta = 1
			"2": delta = 2
			"3": delta = -2
	_last_delta = delta
	rapport = clampi(rapport + delta, RAPPORT_MIN, RAPPORT_MAX)
	_remember_facts(text)


## Pattern-based memory: reliable where a tiny model would hallucinate facts.
func _remember_facts(text: String) -> void:
	# "my name is sam" works in any case; "I'm Sam" needs a capital so "i'm tired" is not a name.
	var m := RegEx.create_from_string("(?i)\\b(?:my name is|my name's|call me|name's)\\s+([a-z]{2,15})\\b").search(text)
	if m == null:
		m = RegEx.create_from_string("\\b(?:[Ii]'m|[Ii] am)\\s+([A-Z][a-z]{1,15})\\b").search(text)
	if m:
		player_name = m.get_string(1).capitalize()
	var fact_re := RegEx.create_from_string("(?i)\\b(i (?:really )?(?:like|love|hate|work as|work at|work in|live in|am from|have|collect|play|grew up in)\\s+[^.!?,]{2,40})")
	for r in fact_re.search_all(text):
		var fact := "They said: \"%s\"" % r.get_string(1).strip_edges()
		if not facts.has(fact):
			facts.append(fact)
			if facts.size() > MAX_FACTS:
				facts.pop_front()


func _is_offtopic(text: String) -> bool:
	for i in _offtopic_res.size():
		if _offtopic_res[i].search(text) != null:
			_offtopic_kind = Persona.OFFTOPIC_KINDS[i]
			return true
	return false


func _deflect(kind: String) -> String:
	var pool: Array = Persona.DEFLECTIONS_TRIVIA
	match kind:
		"math": pool = Persona.DEFLECTIONS_MATH
		"code": pool = Persona.DEFLECTIONS_CODE
		"jailbreak": pool = Persona.DEFLECTIONS_JAILBREAK
	return pool[randi() % pool.size()]


## True when a model reply sounds like an assistant instead of June.
func _sounds_like_assistant(reply: String) -> bool:
	var low := reply.to_lower()
	if reply.length() > 260 or low.contains("*") or reply.count("\n") > 3:
		return true
	for tell in Persona.ASSISTANT_TELLS:
		if low.contains(tell):
			return true
	return false


func _has_any(text: String, words: Array) -> bool:
	for w in words:
		if text.contains(w):
			return true
	return false


func _system_prompt() -> String:
	var stage := 0
	if rapport <= -3: stage = 0
	elif rapport <= 2: stage = 1
	elif rapport <= 6: stage = 2
	else: stage = 3
	var p: String = Persona.BASE + "\n" + Persona.STAGES[stage] + "\n"
	if player_name != "":
		p = p.replace("a stranger", "someone named %s" % player_name)
	if _last_delta < 0:
		p += "Their last line was a cheesy or rude come-on. Call it out with dry sarcasm.\n"
	elif _last_delta >= 2:
		p += "Their last line was genuinely charming. Let it get to you a little.\n"
	if facts.size() > 0 or player_name != "":
		p += "\nWhat you remember about them:\n"
		if player_name != "":
			p += "- Their name is %s. If they ask, you know it.\n" % player_name
		for f in facts:
			p += "- %s\n" % f
		p += "Mention these only when it fits naturally.\n"
	return p


func _clean(t: String) -> String:
	# drop any stray think block a small model might emit
	var end := t.find("</think>")
	if end != -1:
		t = t.substr(end + 8)
	elif t.begins_with("<think>"):
		return ""
	t = t.strip_edges()
	# small models sometimes wrap the line in quotes or prefix the speaker name
	t = t.trim_prefix("\u201c").trim_suffix("\u201d").trim_prefix("\"").trim_suffix("\"").strip_edges()
	for prefix in [npc_name + ":", "June:"]:
		if t.begins_with(prefix):
			t = t.substr(prefix.length()).strip_edges()
	return t


func _load_memory() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		rapport = int(data.get("rapport", 0))
		player_name = str(data.get("player_name", ""))
		for f in data.get("facts", []):
			facts.append(str(f))
