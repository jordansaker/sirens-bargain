class_name SplashEffect
extends Control

# Water-splash punctuation overlay — a bright central burst and three cyan
# ripples that expand outward and fade. Used to underline popup-menu
# openings so a new dialog doesn't just appear silently. Draws via _draw so
# ring thickness stays constant regardless of radius (a scaled
# Panel/StyleBox would visually thicken with scale).
#
# Kept intentionally simple: any additional element (droplets, particles)
# is one more thing that can render invisibly on the web build. Original
# ring/stagger/timing preserved so this behaves like the gold version that
# shipped; only the palette + core flash are new.

const RING_COUNT := 3
const BASE_RADIUS := 14.0
const MAX_RADIUS := 120.0
const DURATION := 0.7
const RING_STAGGER := 0.1
const RING_WIDTH := 2.5
const RING_COLOR := Color(0.55, 0.85, 1.0, 0.9)

const CORE_DURATION := 0.32
const CORE_MAX_RADIUS := 34.0
const CORE_COLOR := Color(0.92, 0.98, 1.0, 0.95)

var _time: float = 0.0
var _center: Vector2 = Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

# Spawn at `global_center` in the given parent; the effect frees itself
# after the last ring has fully faded.
static func spawn_at(parent: Control, global_center: Vector2) -> SplashEffect:
	var fx := SplashEffect.new()
	parent.add_child(fx)
	# Local coords for _draw — anchors_preset FULL_RECT means our (0,0) is
	# the parent's top-left, so subtract to convert global → local.
	fx._center = global_center - parent.get_global_rect().position
	fx.set_process(true)
	return fx

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	# Total lifetime = last ring's start + full duration.
	if _time > DURATION + RING_STAGGER * float(RING_COUNT - 1):
		queue_free()

func _draw() -> void:
	_draw_core()
	_draw_ripples()

func _draw_core() -> void:
	var t: float = _time / CORE_DURATION
	if t < 0.0 or t > 1.0:
		return
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var radius: float = lerp(2.0, CORE_MAX_RADIUS, eased)
	var alpha: float = CORE_COLOR.a * (1.0 - t)
	draw_circle(_center, radius, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, alpha))

func _draw_ripples() -> void:
	for i in range(RING_COUNT):
		var t: float = (_time - float(i) * RING_STAGGER) / DURATION
		if t < 0.0 or t > 1.0:
			continue
		# Ease-out expansion so the ring slows as it grows; alpha fades on
		# the same t so leading rings fade first.
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var radius: float = lerp(BASE_RADIUS, MAX_RADIUS, eased)
		var alpha: float = RING_COLOR.a * (1.0 - t)
		var col := Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, alpha)
		draw_arc(_center, radius, 0.0, TAU, 48, col, RING_WIDTH, true)
