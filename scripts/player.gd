extends CharacterBody3D
## First-person controller. WASD + mouse look, Shift to run, E to interact.

signal target_changed(target: Object)
signal interacted(target: Object)

const WALK_SPEED := 3.5
const RUN_SPEED := 6.0
const MOUSE_SENS := 0.0025
const GRAVITY := 20.0
const REACH := 4.0

var locked := false  # freezes walking (e.g. while typing in the chat box)

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var _target: Object = null


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	camera = Camera3D.new()
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collide_with_areas = false
	camera.add_child(ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# Mouse look lives in _input (not _unhandled_input) so no UI control can swallow it.
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * MOUSE_SENS)
	elif event is InputEventMouseButton and event.pressed:
		_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and _target:
		interacted.emit(_target)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_capture_mouse()


func _capture_mouse() -> void:
	if not get_tree().paused and DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _look(delta: Vector2) -> void:
	rotate_y(-delta.x)
	head.rotation.x = clampf(head.rotation.x - delta.y, -1.4, 1.4)


func _physics_process(delta: float) -> void:
	# self-heal: if the mouse got released for any reason, grab it again
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()
	# arrow keys also look around, in case the mouse misbehaves
	var arrows := Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	if arrows != Vector2.ZERO and not get_tree().paused:
		_look(arrows * 2.0 * delta)
	var dir := Vector2.ZERO
	if not locked:
		if Input.is_physical_key_pressed(KEY_W): dir.y -= 1
		if Input.is_physical_key_pressed(KEY_S): dir.y += 1
		if Input.is_physical_key_pressed(KEY_A): dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D): dir.x += 1
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	var move := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	var hit: Object = null
	if not locked and ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_method("interact"):
			hit = c
	if hit != _target:
		_target = hit
		target_changed.emit(_target)
