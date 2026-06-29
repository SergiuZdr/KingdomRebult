# res://scenes/dungeon/components/room_medallion.gd
class_name RoomMedallion
extends Control

## Circular room node for the dungeon map, composited from the generated pixel-art
## medallion pieces (ring / disc / check / lock) plus a colour-tinted type rim and a
## pulsing torch glow for the current room.
##
## Call setup() once after instancing, then set_state() whenever map state changes.
## The Hit Button exposes its pressed signal for click handling.

enum State {
	NORMAL,          # visible, not yet accessible
	ACCESSIBLE,      # reachable, can be clicked
	CURRENT,         # player is here — glows + pulses
	CLEARED,         # defeated/completed, no re-entry
	CLEARED_REENTER, # shop or lore — cleared but re-enterable (tinted)
	LOCKED,          # hidden, inaccessible
	REVEALED,        # map-reveal mode — dimly shown but not interactive
}

const DISC_RADIUS: float = 32.0
const ICON_SIZE: float   = 48.0

# ── Pixel-art pieces (80×80 ring, 64×64 disc, 32×32 check/lock) ───────────────
const TEX_RING  := preload("res://assets/ui/dungeon/medalions/ring.png")
const TEX_DISC  := preload("res://assets/ui/dungeon/medalions/disc.png")
const TEX_CHECK := preload("res://assets/ui/dungeon/medalions/check.png")
const TEX_LOCK  := preload("res://assets/ui/dungeon/medalions/lock.png")

# ── Child references ────────────────────────────────────────────────────────
@onready var _icon: TextureRect = $Icon
@onready var _hit: Button       = $Hit

# ── Public state ─────────────────────────────────────────────────────────────
var _icon_tex: Texture2D = null
var _ring_color: Color   = UIPalette.STONE_LIGHT
var _icon_mod: Color     = Color.WHITE  # rgb brightness for the icon (dark icons get lifted)
var _state: State        = State.LOCKED
var _is_current: bool    = false
var _is_cleared: bool    = false

# ── Banner animation phase (per-instance random offset for desync) ────────────
var _banner_phase: float = 0.0

# ── Pulse + hover animation ──────────────────────────────────────────────────
var _glow_alpha: float = 0.0    # drives the current-room ring pulse
var _glow_tween: Tween = null
var _hover_tween: Tween = null

func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	_banner_phase = randf() * TAU   # random offset so each medallion waves differently
	set_process(true)
	# Hit button covers the full control, transparent stylebox
	_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var empty_sb := StyleBoxEmpty.new()
	_hit.add_theme_stylebox_override("normal",   empty_sb)
	_hit.add_theme_stylebox_override("hover",    empty_sb)
	_hit.add_theme_stylebox_override("pressed",  empty_sb)
	_hit.add_theme_stylebox_override("disabled", empty_sb)
	_hit.add_theme_stylebox_override("focus",    empty_sb)
	_hit.flat = true
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP

	# Hover/selection feedback: pop the medallion up from its centre.
	pivot_offset = Vector2(40, 40)
	_hit.mouse_entered.connect(_on_hover_enter)
	_hit.mouse_exited.connect(_on_hover_exit)

	# Icon — centered 48×48
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	if _icon_tex != null:
		_icon.texture = _icon_tex

## Configure icon and rim colour. Call once after instancing.
## icon_modulate lifts dark icon art (rgb only; alpha is driven per-state by _draw).
func setup(icon_tex: Texture2D, ring_color: Color, icon_modulate: Color = Color.WHITE) -> void:
	_icon_tex   = icon_tex
	_ring_color = ring_color
	_icon_mod   = icon_modulate
	if is_node_ready():
		_icon.texture = _icon_tex
	queue_redraw()

## Update visual state. Called by _refresh_room_states each render cycle.
## is_cleared: true if the room's cleared flag is set (draws checkmark even on CURRENT).
func set_state(state: State, is_current: bool, is_cleared: bool = false) -> void:
	_state      = state
	_is_current = is_current
	_is_cleared = is_cleared
	if not is_node_ready():
		return
	_icon.texture = _icon_tex
	_update_hit_button()
	_update_glow_tween()
	queue_redraw()

## Set tooltip text on the Hit button so the OS shows it on hover.
## Pass "???" for fog rooms; pass the full room name for known rooms.
func set_room_name(display_name: String) -> void:
	if is_node_ready():
		_hit.tooltip_text = display_name

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		if _icon_tex != null:
			_icon.texture = _icon_tex
		_update_hit_button()

func _process(delta: float) -> void:
	if _is_current:
		_banner_phase += delta * 3.5
		queue_redraw()

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var center := size * 0.5

	# ── Per-state visual parameters ──────────────────────────────────────────
	var disc_mod:   Color = Color(1, 1, 1, 1)
	var ring_alpha: float = 1.0
	var rim_alpha:  float = 1.0
	var icon_alpha: float = 1.0
	var draw_check: bool  = false

	match _state:
		State.NORMAL:
			disc_mod = Color(0.62, 0.62, 0.66, 1.0)
		State.ACCESSIBLE:
			disc_mod = Color(1, 1, 1, 1)
		State.CURRENT:
			disc_mod = Color(1, 1, 1, 1)
		State.CLEARED:
			disc_mod   = Color(0.55, 0.55, 0.58, 1.0)
			ring_alpha = 0.6
			rim_alpha  = 0.35
			icon_alpha = 0.6
			draw_check = true
		State.CLEARED_REENTER:
			disc_mod   = Color(0.82, 0.82, 0.85, 1.0)
			icon_alpha = 0.9
			draw_check = true
		State.LOCKED:
			# Real medallion, dimmed to read as "sealed/unknown". No type rim or
			# icon — a padlock is drawn in their place further down.
			disc_mod   = Color(0.50, 0.50, 0.56, 1.0)
			ring_alpha = 0.75
			rim_alpha  = 0.0
			icon_alpha = 0.0
		State.REVEALED:
			disc_mod   = Color(0.60, 0.60, 0.62, 1.0)
			ring_alpha = 0.6
			rim_alpha  = 0.5
			icon_alpha = 0.5

	# Also show checkmark when the party is standing on an already-cleared room.
	if _is_cleared:
		draw_check = true

	# ── Drop shadow beneath the disc ─────────────────────────────────────────
	draw_circle(center + Vector2(2, 3), DISC_RADIUS, Color(0, 0, 0, 0.45))

	# ── Disc (64×64 art, centered) ───────────────────────────────────────────
	draw_texture(TEX_DISC, center - TEX_DISC.get_size() * 0.5, disc_mod)

	# ── Colored type rim (room-type indicator) ───────────────────────────────
	if rim_alpha > 0.0:
		draw_arc(center, DISC_RADIUS - 4.0, 0.0, TAU, 48,
			Color(_ring_color.r, _ring_color.g, _ring_color.b, rim_alpha), 4.0, true)

	# ── Ornate gold ring (80×80 art, on top) ─────────────────────────────────
	draw_texture(TEX_RING, center - TEX_RING.get_size() * 0.5,
		Color(1, 1, 1, ring_alpha))

	# ── Locked rooms: padlock centred in place of the hidden type icon ───────
	if _state == State.LOCKED:
		draw_texture(TEX_LOCK, center - TEX_LOCK.get_size() * 0.5,
			Color(0.88, 0.88, 0.92, 0.92))

	# ── Current-room indicator: crisp pulsing bright ring (no fuzzy glow) ─────
	if _is_current:
		var pulse: float = 0.5 + 0.5 * _glow_alpha
		draw_arc(center, DISC_RADIUS + 5.0, 0.0, TAU, 56,
			Color(UIPalette.GOLD_HI.r, UIPalette.GOLD_HI.g, UIPalette.GOLD_HI.b, pulse),
			2.5, true)

		# ── Pennant / planted banner on a short pole ──────────────────────────
		# Pole: thin vertical line rising from the top of the disc.
		var pole_base := center + Vector2(10.0, -DISC_RADIUS + 2.0)
		var pole_top  := pole_base + Vector2(0.0, -22.0)
		draw_line(pole_base, pole_top, Color(0.65, 0.50, 0.25, 0.95), 2.0, true)

		# Pennant: triangle that waves gently using sin on its tip x offset.
		var wave: float = sin(_banner_phase) * 3.0
		var flag_attach := pole_top + Vector2(1.0, 3.0)      # where flag meets pole
		var flag_tip    := flag_attach + Vector2(11.0 + wave, 5.0)  # waving tip
		var flag_tail   := flag_attach + Vector2(0.0, 10.0)  # bottom of hoist edge
		var pts: PackedVector2Array = PackedVector2Array([flag_attach, flag_tip, flag_tail])
		draw_colored_polygon(pts, Color(0.88, 0.20, 0.10, 0.95))
		# Thin gold outline to make it pop against any background.
		draw_polyline(PackedVector2Array([flag_attach, flag_tip, flag_tail, flag_attach]),
			Color(UIPalette.GOLD.r, UIPalette.GOLD.g, UIPalette.GOLD.b, 0.80), 1.0, true)

	# ── Icon brightness + alpha (child TextureRect renders above _draw) ──────
	if is_node_ready():
		_icon.modulate = Color(_icon_mod.r, _icon_mod.g, _icon_mod.b, icon_alpha)

	# ── Cleared checkmark (bottom-right) ─────────────────────────────────────
	if draw_check:
		draw_texture(TEX_CHECK, center + Vector2(6.0, 6.0))

# ── Glow tween management ─────────────────────────────────────────────────────

func _update_glow_tween() -> void:
	if _glow_tween != null and _glow_tween.is_running():
		_glow_tween.kill()
		_glow_tween = null

	if not _is_current:
		_glow_alpha = 0.0
		return

	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.tween_method(_set_glow_alpha, 0.4, 1.0, 0.7)
	_glow_tween.tween_method(_set_glow_alpha, 1.0, 0.4, 0.9)

func _set_glow_alpha(v: float) -> void:
	_glow_alpha = v
	queue_redraw()

# ── Hit button state ──────────────────────────────────────────────────────────

func _update_hit_button() -> void:
	if not is_node_ready():
		return
	match _state:
		State.ACCESSIBLE, State.CURRENT, State.CLEARED_REENTER, State.CLEARED:
			_hit.disabled = false
		_:
			# A non-interactive medallion shouldn't stay popped if it was hovered.
			_hit.disabled = true
			_on_hover_exit()

# ── Hover / selection feedback ────────────────────────────────────────────────

func _on_hover_enter() -> void:
	if not is_node_ready() or _hit.disabled:
		return
	z_index = 1
	_tween_scale(Vector2(1.12, 1.12))

func _on_hover_exit() -> void:
	if not is_node_ready():
		return
	z_index = 0
	_tween_scale(Vector2.ONE)

func _tween_scale(target: Vector2) -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target, 0.09)
