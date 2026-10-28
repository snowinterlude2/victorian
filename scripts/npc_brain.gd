extends Node
## NobodyWho wrapper: roleplay chat + a tiny "judge" chat that tracks how the player
## makes June feel (rapport) and what she should remember. Memory persists to user://.

signal reply_started
signal reply_progress(text: String)
signal reply_finished(text: String)
signal status(text: String)

const MODEL := "hf://NobodyWho/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
const SAVE_PATH := "user://june_memory.json"
const MAX_FACTS := 8
const RAPPORT_MIN := -6
const RAPPORT_MAX := 12

var npc_name := "June"
var rapport := 0
var facts: Array[String] = []
var player_name := ""

var _chat
var _judge
var _loading := false
var _busy := false


func _ready() -> void:
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
	reply_finished.emit(_clean(full))
	_busy = false


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"rapport": rapport, "facts": facts, "player_name": player_name}))


func _start() -> void:
	if _loading:
		return
	_loading = true
	status.emit("Loading %s's brain (first run downloads ~400 MB)..." % npc_name)
	var cfg := {
		"system_prompt": _system_prompt(),
		"n_ctx": 2048,
		"template_variables": {"enable_thinking": false},
	}
	_chat = await NobodyWhoChat.create(MODEL, cfg)
	_judge = await NobodyWhoChat.create(MODEL, {
		"system_prompt": Persona.JUDGE_PROMPT,
		"n_ctx": 512,
		"template_variables": {"enable_thinking": false},
	})
	_loading = false
	if _chat == null or _judge == null:
		status.emit("Could not load the model. Check the Errors tab in the Godot editor.")
		_chat = null
		return
	status.emit("")


## Scores the player's line and pulls out something worth remembering.
func _judge_message(text: String) -> void:
	await _judge.reset_chat(Persona.JUDGE_PROMPT, [])
	var score_raw: String = await _judge.ask("Player message: " + text).completed()
	var delta := 0
	match score_raw.strip_edges().left(1):
		"1": delta = 1
		"2": delta = 2
		"3": delta = -2
	rapport = clampi(rapport + delta, RAPPORT_MIN, RAPPORT_MAX)

	await _judge.reset_chat(Persona.FACT_PROMPT, [])
	var fact: String = (await _judge.ask("Player message: " + text).completed()).strip_edges()
	fact = fact.trim_suffix(".")
	if fact != "" and not fact.to_upper().begins_with("NONE") and fact.length() < 80:
		if not facts.has(fact):
			facts.append(fact)
			if facts.size() > MAX_FACTS:
				facts.pop_front()
		var lower := fact.to_lower()
		if lower.begins_with("name is "):
			player_name = fact.substr(8).strip_edges().capitalize()


func _system_prompt() -> String:
	var stage := 0
	if rapport <= -3: stage = 0
	elif rapport <= 2: stage = 1
	elif rapport <= 6: stage = 2
	else: stage = 3
	var p: String = Persona.BASE + "\nFEELINGS (right now)\n" + Persona.STAGES[stage] + "\n"
	if facts.size() > 0 or player_name != "":
		p += "\nTHINGS YOU REMEMBER ABOUT THE PLAYER\n"
		if player_name != "":
			p += "- Their name is %s.\n" % player_name
		for f in facts:
			p += "- %s\n" % f
		p += "Bring these up naturally when it fits. Do not list them.\n"
	return p


func _clean(t: String) -> String:
	# drop any stray think block a small model might emit
	var end := t.find("</think>")
	if end != -1:
		t = t.substr(end + 8)
	elif t.begins_with("<think>"):
		return ""
	return t.strip_edges()


func _load_memory() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		rapport = int(data.get("rapport", 0))
		player_name = str(data.get("player_name", ""))
		for f in data.get("facts", []):
			facts.append(str(f))
