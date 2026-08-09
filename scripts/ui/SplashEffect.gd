class_name SplashEffect
extends Control

# Bucket-of-water splash — heavy central impact blob spreading outward,
# chunky irregular arms of water shooting to the corners, drips running
# down the screen, and a subtle blue tint across everything. Used to
# underline popup-menu openings so a new dialog doesn't just appear
# silently. Reads as somebody hurling a full bucket at the camera:
# translucent cyan water, splatters and runs, total lifetime ~1.5s.
#
# All primitives are draw_circle / draw_line / draw_rect so this renders
# identically on the web build without any shader dependency.

const CORE_START := 22.0
const CORE_END := 260.0
const CORE_DURATION := 0.42
const CORE_WATER := Color(0.55, 0.85, 1.0, 0.7)
const CORE_HIGHLIGHT := Color(0.9, 0.98, 1.0, 0.9)
# Number of overlapping blobs around the core for irregular splat edge.
const CORE_BLOBS := 7

const ARM_COUNT := 12
const ARM_SEGMENTS := 6
const ARM_MAX_LENGTH := 520.0
const ARM_BASE_RADIUS := 42.0
const ARM_TIP_RADIUS := 6.0
const ARM_DURATION := 0.62
const ARM_WATER := Color(0.55, 0.85, 1.0, 0.7)

const DRIP_COUNT := 18
const DRIP_SPREAD := 260.0    # horizontal range around impact where drips originate
const DRIP_HEAD_RADIUS := 9.0
const DRIP_STREAM_WIDTH := 5.0
const DRIP_DURATION := 1.5
const DRIP_WATER := Color(0.55, 0.85, 1.0, 0.85)

const TINT_DURATION := 1.4
const TINT_COLOR := Color(0.55, 0.85, 1.0, 0.18)

var _time: float = 0.0
var _center: Vector2 = Vector2.ZERO
var _viewport_size: Vector2 = Vector2.ZERO
# Per-arm spec: {angle: rad, length_mult: 0.7..1.15}. Randomised once.
var _arms: Array = []
# Per-drip spec: {x_offset, fall_speed, delay, head_r_mult}. Randomised once.
var _drips: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(ARM_COUNT):
		# Even angular distribution + small jitter so the splat doesn't look
		# like a perfect starburst.
		var base_a: float = TAU * float(i) / float(ARM_COUNT)
		var a: float = base_a + rng.randf_range(-0.18, 0.18)
		var length_mult: float = rng.randf_range(0.7, 1.15)
		_arms.append({"angle": a, "length_mult": length_mult})
	for i in range(DRIP_COUNT):
		_drips.append({
			"x_offset": rng.randf_range(-DRIP_SPREAD, DRIP_SPREAD),
			"fall_speed": rng.randf_range(0.7, 1.2),
			"delay": rng.randf_range(0.05, 0.4),
			"head_r_mult": rng.randf_range(0.65, 1.3),
		})

# Spawn at `global_center` in the given parent; the effect frees itself
# once every element has finished.
static func spawn_at(parent: Control, global_center: Vector2) -> SplashEffect:
	var fx := SplashEffect.new()
	parent.add_child(fx)
	# Local coords for _draw — anchors_preset FULL_RECT means our (0,0) is
	# the parent's top-left, so subtract to convert global → local.
	var rect := parent.get_global_rect()
	fx._center = global_center - rect.position
	fx._viewport_size = rect.size
	fx.set_process(true)
	return fx

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	var total: float = max(
		max(CORE_DURATION, ARM_DURATION),
		max(DRIP_DURATION, TINT_DURATION)
	)
	if _time > total:
		queue_free()

func _draw() -> void:
	_draw_tint()
	_draw_core()
	_draw_arms()
	_draw_drips()

func _draw_tint() -> void:
	# Full-screen faint blue wash — the "water film on the camera" moment.
	# Ramps up fast (impact) then fades slowly with the drips.
	var t: float = _time / TINT_DURATION
	if t < 0.0 or t > 1.0:
		return
	var ramp: float = min(t * 4.0, 1.0)   # 0→1 over first 25% of lifetime
	var fade: float = 1.0 - t
	var alpha: float = TINT_COLOR.a * ramp * fade
	if alpha <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, _viewport_size),
		Color(TINT_COLOR.r, TINT_COLOR.g, TINT_COLOR.b, alpha))

func _draw_core() -> void:
	var t: float = _time / CORE_DURATION
	if t < 0.0 or t > 1.0:
		return
	# Fast ease-out expansion — the impact happens in the first ~200ms and
	# then the water sits and fades.
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var r: float = lerp(CORE_START, CORE_END, eased)
	var fade: float = 1.0 - t
	var body_alpha: float = CORE_WATER.a * fade
	var body_col := Color(CORE_WATER.r, CORE_WATER.g, CORE_WATER.b, body_alpha)
	# Main body
	draw_circle(_center, r, body_col)
	# Overlapping blobs at the perimeter for an irregular splat edge instead
	# of a perfect circle. Each blob sits at ~35% of radius outward, sized
	# ~55% of radius, so they slightly protrude past the main body.
	var blob_alpha: float = body_alpha * 0.65
	var blob_col := Color(CORE_WATER.r, CORE_WATER.g, CORE_WATER.b, blob_alpha)
	for i in range(CORE_BLOBS):
		var a: float = TAU * float(i) / float(CORE_BLOBS)
		var off := Vector2.RIGHT.rotated(a) * r * 0.55
		draw_circle(_center + off, r * 0.5, blob_col)
	# Bright specular highlight at the impact point — sells the "wet"
	# quality: light bouncing off water.
	var hi_alpha: float = CORE_HIGHLIGHT.a * fade
	draw_circle(_center, r * 0.22,
		Color(CORE_HIGHLIGHT.r, CORE_HIGHLIGHT.g, CORE_HIGHLIGHT.b, hi_alpha))

func _draw_arms() -> void:
	var t: float = _time / ARM_DURATION
	if t < 0.0 or t > 1.0:
		return
	var eased: float = 1.0 - pow(1.0 - t, 2.5)
	var fade: float = 1.0 - t
	var alpha: float = ARM_WATER.a * fade
	var col := Color(ARM_WATER.r, ARM_WATER.g, ARM_WATER.b, alpha)
	for a in _arms:
		var angle: float = float(a["angle"])
		var length_mult: float = float(a["length_mult"])
		var max_len: float = ARM_MAX_LENGTH * length_mult
		var dir := Vector2.RIGHT.rotated(angle)
		# Chain of shrinking circles from base to tip — bold near the impact,
		# breaks into smaller droplets as it flies out.
		for seg in range(ARM_SEGMENTS):
			var seg_t: float = float(seg + 1) / float(ARM_SEGMENTS)
			var dist: float = max_len * seg_t * eased
			var pos: Vector2 = _center + dir * dist
			var r: float = lerp(ARM_BASE_RADIUS, ARM_TIP_RADIUS, seg_t)
			draw_circle(pos, r, col)

func _draw_drips() -> void:
	# Drips fall from various horizontal offsets around the impact point,
	# each with its own delay + fall speed so they don't move in lockstep.
	# Fall distance is capped by the visible parent height so drips reach
	# the bottom of the screen no matter where the impact landed.
	var max_fall_available: float = max(200.0, _viewport_size.y - _center.y + 40.0)
	for d in _drips:
		var delay: float = float(d["delay"])
		var local_t: float = (_time - delay) / DRIP_DURATION
		if local_t < 0.0 or local_t > 1.0:
			continue
		var x_offset: float = float(d["x_offset"])
		var fall_speed: float = float(d["fall_speed"])
		var head_r_mult: float = float(d["head_r_mult"])
		# Accelerating fall — gravity feel. Slight quadratic ease.
		var eased_fall: float = pow(local_t, 1.4)
		var fall: float = max_fall_available * fall_speed * eased_fall
		var head_pos: Vector2 = _center + Vector2(x_offset, fall)
		var start_pos: Vector2 = _center + Vector2(x_offset, 0.0)
		# Long fade — the water on the screen slowly evaporates.
		var fade: float = 1.0 - pow(local_t, 2.5)
		var alpha: float = DRIP_WATER.a * fade
		if alpha <= 0.0:
			continue
		var stream_col := Color(DRIP_WATER.r, DRIP_WATER.g, DRIP_WATER.b, alpha * 0.6)
		var head_col := Color(DRIP_WATER.r, DRIP_WATER.g, DRIP_WATER.b, alpha)
		# Vertical stream from origin down to the head — the trail of water
		# running down the screen.
		draw_line(start_pos, head_pos, stream_col, DRIP_STREAM_WIDTH, true)
		# Larger blob at the leading edge — the drop's head as it falls.
		draw_circle(head_pos, DRIP_HEAD_RADIUS * head_r_mult, head_col)
