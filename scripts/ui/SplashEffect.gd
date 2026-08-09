class_name SplashEffect
extends Control

# Three concentric ripples that expand outward and fade — used to punctuate
# popup-menu openings so a new dialog doesn't just appear silently. Draws
# arcs directly so the ring thickness stays constant regardless of radius
# (a scaled Panel/StyleBox would visually thicken the border as it grows).

const RING_COUNT := 3
const BASE_RADIUS := 14.0
const MAX_RADIUS := 96.0
const DURATION := 0.65
const RING_STAGGER := 0.09
const RING_COLOR := Color(0.79, 0.63, 0.15, 0.85)

var _time: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full-screen overlay so we can draw wherever the caller centred us.
	set_anchors_preset(Control.PRESET_FULL_RECT)

var _center: Vector2 = Vector2.ZERO

# Spawn at `global_center` in the given parent; the effect frees itself after
# the last ring has fully faded.
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
	# Total lifetime = duration + last ring's stagger delay.
	if _time > DURATION + RING_STAGGER * float(RING_COUNT - 1):
		queue_free()

func _draw() -> void:
	for i in range(RING_COUNT):
		var t: float = (_time - float(i) * RING_STAGGER) / DURATION
		if t < 0.0 or t > 1.0:
			continue
		# Ease-out expansion so the ripple slows as it grows, and a smooth
		# alpha fade tied to the same t.
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var radius: float = lerp(BASE_RADIUS, MAX_RADIUS, eased)
		var alpha: float = RING_COLOR.a * (1.0 - t)
		var col := Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, alpha)
		draw_arc(_center, radius, 0.0, TAU, 48, col, 2.0, true)
