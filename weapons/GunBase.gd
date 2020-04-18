extends Node2D
class_name GunBase

var rng = RandomNumberGenerator.new()

# Stats
var gun_name: String

var damage: float

var mag_size: int
var reload_time: float         # Seconds

var fire_range: float
var spread: float
var bullet_velocity: float

var auto: bool
var burst_size: int

var fire_rate: float = 1.0          # Rounds Per Second
var bullets_per_shot: int

# Assets
onready var bullet_prefab
onready var bullet_node: Node

onready var fire_sound: AudioStreamPlayer2D
onready var reload_start_sound: AudioStreamPlayer2D
onready var reload_end_sound: AudioStreamPlayer2D

onready var tween: Tween
onready var muzzle_flash: Light2D
onready var muzzle_ambient: Light2D

# Getters
onready var ammo_count: FuncRef
onready var  update_ammo_count: FuncRef

signal reload
signal ammo_change

# Internal values
var current_mag: int
var is_reloading: bool
var time_since_reload: float

var is_trigger_held: bool
onready var time_per_shot: float
onready var burst_bullets_left: int
var time_since_fire: float

func _ready():
	rng.randomize()
	is_trigger_held = false
	is_reloading = false
	
	time_since_reload = 0.0
	current_mag = mag_size

	time_per_shot = 1.0/fire_rate
	burst_bullets_left = burst_size
	time_since_fire = 0.0

# Interface(only the following functions should be called)
# - press_trigger
# - release_trigger
# - reload
# - make_active
# - process <- should be called by weapon user in _process

func press_trigger():
	is_trigger_held = true
	time_since_fire = time_per_shot
	if burst_bullets_left == 0:
		burst_bullets_left = burst_size

func release_trigger():
	is_trigger_held = false

func reload():
	if !is_reloading:
		if current_mag != mag_size and ammo_count.call_func() > 0:
			is_reloading = true
			time_since_reload = 0.0

			reload_start_sound.play()
			emit_signal("reload", is_reloading)


func make_active():
	print(gun_name + " Equiped")
	emit_signal("reload", is_reloading)
	emit_signal("ammo_change", current_mag, ammo_count.call_func())
	
func process(delta, position, direction):
	time_since_fire += delta
	process_reload(delta)

	if is_reloading:
		return

	process_fire(position, direction)

func valid_shot():
	if is_reloading:
		return false

	if current_mag == 0:
		return false

	if !auto and burst_bullets_left == 0:			# burst and single fire
		return false

	if !auto and burst_bullets_left != burst_size:	# burst
		return true

	if !is_trigger_held:
		return false

	return true 									# full auto

func process_fire(position, direction):
	if !valid_shot():
		return

	if time_since_fire < time_per_shot:
		return
	
	time_since_fire -= time_per_shot
	create_bullets(time_since_fire, position, direction)

	while time_since_fire >= time_per_shot and valid_shot():
		time_since_fire -= time_per_shot
		create_bullets(time_since_fire, position, direction)


func create_bullets(backdate_time, position, direction):
	current_mag -= 1
	if !auto:
		burst_bullets_left -= 1

	for i in range(bullets_per_shot):
		var random_spread = rng.randf_range(-1.0, 1.0)
		var direction_with_spread = direction.rotated(random_spread*spread/100.0)
		
		var b = bullet_prefab.instance()
		b.setup(direction_with_spread, bullet_velocity, fire_range)
		bullet_node.add_child(b)
		b.set_position(position)

	toggle_muzzle_flash()
	tween.interpolate_callback(self, 0.05, "toggle_muzzle_flash")
	tween.start()
	emit_signal("ammo_change", current_mag, ammo_count.call_func())
	fire_sound.play()

func process_reload(delta):
	if !is_reloading:
		return

	time_since_reload += delta
	var reserve_count = ammo_count.call_func()
	var original_reserve_count = reserve_count

	if time_since_reload >= reload_time:
		is_reloading = false
		time_since_reload = 0.0
		burst_bullets_left = burst_size
		is_trigger_held = false

		if reserve_count + current_mag >= mag_size:
			reserve_count -= (mag_size - current_mag)
			current_mag = mag_size
		else:
			current_mag += reserve_count
			reserve_count = 0

		reload_end_sound.play()
		update_ammo_count.call_func(reserve_count - original_reserve_count)
		emit_signal("reload", is_reloading)
		emit_signal("ammo_change", current_mag, reserve_count)

func toggle_muzzle_flash():
	muzzle_flash.set_visible(!muzzle_flash.is_visible())
	muzzle_ambient.set_visible(!muzzle_ambient.is_visible())