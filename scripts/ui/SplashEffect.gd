class_name SplashEffect
extends Control

# Water-splash punctuation overlay — a bright central burst, a spray of
# droplets that shoot outward and decelerate, and concentric ripples that
# expand from the impact point. Used to underline popup-menu openings so a
# new dialog doesn't just appear silently. Drawn via _draw so ring
# thickness stays constant as radius grows (a scaled Panel/StyleBox would
# visually thicken with scale).

const RIPPLE_COUNT := 3
const RIPPLE_START_RADIUS := 12.0
const RIPPLE_END_RADIUS := 110.0
const RIPPLE_DURATION := 0.72
const RIPPLE_STAGGER := 0.11
const RIPPLE_WIDTH := 2.2
const RIPPLE_COLOR := Color(0.55, 0.85, 1.0, 0.85)

const CORE_DURATION := 0.28
const CORE_MAX_RADIUS := 28.0
const CORE_COLOR := Color(0.92, 0.98, 1.0, 0.9)

const DROPLET_COUNT := 14
const DROPLET_DURATION := 0.6
const DROPLET_SPEED_MIN := 180.0
const DROPLET_SPEED_MAX := 320.0
const DROPLET_RADIUS_MIN := 2.0
const DROPLET_RADIUS_MAX := 4.5
const DROPLET_COLOR := Color(0.78, 0.92, 1.0, 0.95)

var _time: float = 0.0
var _center: Vector2 = Vector2.ZERO
# Per-droplet spec: {angle: rad, speed: px/s, radius: px}. Randomised once
# in _init so the crown pattern is stable across frames.
var _droplets: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(DROPLET_COUNT):
		# Uniform angular spread with per-droplet jitter so the crown reads
		# as organic spray rather than a mechanical starburst.
		var base_a: float = TAU * float(i) / float(DROPLET_COUNT)
		var a: float = base_a + rng.randf_range(-0.18, 0.18)
		var speed: float = rng.randf_range(DROPLET_SPEED_MIN, DROPLET_SPEED_MAX)
		var r: float = rng.randf_range(DROPLET_RADIUS_MIN, DROPLET_RADIUS_MAX)
		_droplets.append({"angle": a, "speed": speed, "radius": r})

# Spawn at `global_center` in the given parent; the effect frees itself after
# every element has finished.
static func spawn_at(parent: Control, global_center: Vector2) -> SplashEffect:
	var fx := SplashEffect.new()
	parent.add_child(fx)
	# Local coords for _draw — anchors_preset FULL_RECT means our (0,0) is the
	# parent's top-left, so subtract to convert global → local.
	fx._center = global_center - parent.get_global_rect().position
	fx.set_process(true)
	return fx

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	var total: float = max(
		RIPPLE_DURATION + RIPPLE_STAGGER * float(RIPPLE_COUNT - 1),
		max(CORE_DURATION, DROPLET_DURATION)
	)
	if _time > total:
		queue_free()

func _draw() -> void:
	_draw_core()
	_draw_ripples()
	_draw_droplets()

func _draw_core() -> void:
	var t: float = _time / CORE_DURATION
	if t < 0.0 or t > 1.0:
		return
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var radius: float = lerp(2.0, CORE_MAX_RADIUS, eased)
	var alpha: float = CORE_COLOR.a * (1.0 - t)
	draw_circle(_center, radius, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, alpha))

func _draw_ripples() -> void:
	for i in range(RIPPLE_COUNT):
		var t: float = (_time - float(i) * RIPPLE_STAGGER) / RIPPLE_DURATION
		if t < 0.0 or t > 1.0:
			continue
		# Ease-out expansion so the ring slows as it grows; alpha fades on the
		# same t so leading rings fade first.
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var radius: float = lerp(RIPPLE_START_RADIUS, RIPPLE_END_RADIUS, eased)
		var alpha: float = RIPPLE_COLOR.a * (1.0 - t)
		var col := Color(RIPPLE_COLOR.r, RIPPLE_COLOR.g, RIPPLE_COLOR.b, alpha)
		draw_arc(_center, radius, 0.0, TAU, 48, col, RIPPLE_WIDTH, true)

func _draw_droplets() -> void:
	var t: float = _time / DROPLET_DURATION
	if t < 0.0 or t > 1.0:
		return
	# Ease-out radial travel: fast initial burst, decelerates as it flies.
	var eased: float = 1.0 - pow(1.0 - t, 2.5)
	var fade: float = 1.0 - t
	for d in _droplets:
		var dir := Vector2.RIGHT.rotated(float(d["angle"]))
		var distance: float = float(d["speed"]) * DROPLET_DURATION * eased
		var pos: Vector2 = _center + dir * distance
		# Droplets shrink slightly as they spread — sells "spray dispersing"
		# instead of "particles drifting outward at full size".
		var r: float = float(d["radius"]) * (0.7 + 0.3 * (1.0 - t))
		var alpha: float = DROPLET_COLOR.a * fade
		draw_circle(pos, r, Color(DROPLET_COLOR.r, DROPLET_COLOR.g, DROPLET_COLOR.b, alpha))
