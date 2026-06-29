# res://scripts/ui/intro_cinematic.gd
# Animated opening cinematic — a lore prologue told over bespoke painted
# backdrops (assets/cinematic/beatN.png), one per beat, with a PER-BEAT Ken-Burns
# move on the art (push / pull / drift / pan), parallaxed atmosphere
# (embers/smoke/dust/fog), a softened film grade + grain for cohesion, a cyan
# "hero" glow on the listening beat, and the narration in a FIXED full-width bar
# across the bottom (the image is cropped to the space above it). Pixel font.
# Skippable. (The old procedural silhouette builders are kept below, unused.)
extends Control

const HUB_SCENE: String = "res://scenes/management/hub_screen.tscn"
const BEAT_SECONDS: float = 9.0
const CINE_DIR: String = "res://assets/cinematic/"   # drop beat1.png..beat9.png here to override
const FIRE_PATH: String = "res://Downloaded Game Assets/Terrain/Hell Pack/Fire sheet.png"
const SHADOW_PATH: String = "res://assets/enemies/shadow_king/idle.png"
const FIGURE_PATH: String = "res://assets/soldiers/warrior/idle.png"
const FIRE_FRAMES: int = 6

# Narration text box. Drop a 9-slice frame at assets/cinematic/ui/textbox.png to
# skin it; TEXTBOX_SLICE must match that frame's border thickness in pixels.
# Without a frame, a hewn dark-stone / aged-gold panel is drawn procedurally.
const TEXTBOX_PATH: String = "res://assets/cinematic/ui/textbox_frame.png"
const TEXTBOX_SLICE: int = 54   # large enough to keep the corner brackets intact
const GRADE_SCALE: float = 0.55   # soften the film grade so painted art reads clean

# Narration bar: a FIXED full-width strip across the bottom (left edge to right
# edge). The beat image fills the space above it, cropped top/bottom to fit.
const BAR_H: float = 168.0
const FONT_PATH: String = "res://assets/ui/dungeon/fonts/body.ttf"
const FONT_SIZE: int = 20

const MUSIC_PATHS: Array = [
	"res://assets/audio/music/intro_theme.ogg",
	"res://assets/audio/music/intro_theme.mp3",
	"res://assets/audio/music/intro_theme.wav",
]
const MUSIC_VOLUME_DB: float = -6.0

# --- Ashen Kingdom palette ---
const C_CHARCOAL := Color("2B2A2E")
const C_ASH := Color("5C4A3D")
const C_BONE := Color("C9B79C")
const C_MOSS := Color("4A5D43")
const C_CRIMSON := Color("8B2C2C")
const C_FORGE := Color("D67D3E")
const C_GOLD := Color("B8893C")
const C_VIOLET := Color("3D2A4E")
const C_CYAN := Color("5A8B8B")
const C_BLOOD := Color("5C1818")
const C_NIGHT := Color("17151C")
const SILHOUETTE := Color(0.05, 0.045, 0.065)   # near-black with a violet cast

# Each beat: narration + palette grade + a Ken-Burns move (cam) + atmosphere
# amounts. hero: "" | "chasm_pulse".
var _beats: Array = [
	{
		"text": "Soon you will be sent to raise a dead city from its ashes.\nLong ago, an order called the Veiled sealed something terrible beneath the stone,\nthen went into the dark to keep watch over it.",
		"grade": Color(C_VIOLET.r, C_VIOLET.g, C_VIOLET.b, 0.16),
		"cam": "push", "dust": 0.5, "fog": 0.3,
	},
	{
		"text": "Ages later, people built a city over that grave and called it Ostrava.\nA jewel of the kingdom, raised on a secret it had already forgotten.",
		"grade": Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.12),
		"cam": "driftup", "dust": 0.3, "fog": 0.2, "embers": 0.12,
	},
	{
		"text": "Twenty years ago, three armies marched on Ostrava at once.\nA kingdom, a cult, and the wild folk of the woods, each sure the city was theirs.\nNone of them would leave it standing.",
		"grade": Color(C_BLOOD.r, C_BLOOD.g, C_BLOOD.b, 0.18),
		"cam": "panright", "dust": 0.5, "fog": 0.25,
	},
	{
		"text": "In the fighting, none of them could hold it.\nThe city burned, and far below, the Seal cracked.",
		"grade": Color(C_FORGE.r, C_FORGE.g, C_FORGE.b, 0.20),
		"cam": "pushhard", "embers": 1.0, "smoke": 1.0,
	},
	{
		"text": "For twenty years only ruins remained, walls of ash and silent streets.\nAnd far beneath them, something began to wake, and to listen.",
		"grade": Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.12),
		"cam": "pull", "hero": "chasm_pulse", "fog": 0.7, "embers": 0.15,
	},
	{
		"text": "Far away in the capital, an old king sits with a book he keeps hidden.\nHe reads it once more by candlelight, then closes it.\nThen he sends his son to rebuild a city, and says nothing of what lies beneath it.",
		"grade": Color(C_CRIMSON.r, C_CRIMSON.g, C_CRIMSON.b, 0.12),
		"cam": "push", "dust": 0.4,
	},
	{
		"text": "He chooses his second son for the task.\n\"Go to Ostrava,\" he says before the court.\n\"Make it stand again.\"",
		"grade": Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.13),
		"cam": "driftdown", "lightray": 0.5, "dust": 0.3,
	},
	{
		"text": "Now you stand at the broken gate, your father's seal in hand,\na handful of loyal soldiers behind you, and a dead city to raise.\nThis is where your story begins.",
		"grade": Color(C_FORGE.r, C_FORGE.g, C_FORGE.b, 0.14),
		"cam": "push", "embers": 0.3, "lightray": 0.6,
	},
]

var _index: int = 0
var _finished: bool = false
var _transitioning: bool = false
var _screen: Vector2 = Vector2(1200, 720)

# Layers
var _sky: TextureRect
var _grade: ColorRect
var _world: Node2D            # camera-moved silhouette world
var _skyline: Node2D
var _skyline_ruined: Node2D
var _fire_root: Node2D
var _fires: Array = []
var _fire_time: float = 0.0
var _banners: Node2D
var _seal: Node2D
var _seal_circle: Line2D
var _seal_inner: Line2D
var _seal_crack: Line2D
var _seal_spokes: Array = []
var _shadow: Sprite2D
var _figure: Sprite2D
var _candle: Sprite2D
var _embers: CPUParticles2D
var _smoke: CPUParticles2D
var _fog: ColorRect
var _dust: CPUParticles2D
var _lightray: Polygon2D
var _vignette: TextureRect
var _grain: TextureRect
var _atmo: Node2D            # particle layer, parallaxed against the camera
var _hero_glow: TextureRect  # cyan additive glow for the listening beat
var _hero_tween: Tween
var _swell_tween: Tween
var _text_lbl: Label
var _text_panel: PanelContainer
var _text_bg: PanelContainer
var _fade: ColorRect
var _auto_timer: Timer
var _kenburns: Tween
var _cam_tween: Tween
var _music: AudioStreamPlayer
var _grain_time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen = get_viewport().get_visible_rect().size
	theme = GameTheme.get_theme()
	_build_ui()

	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.timeout.connect(_advance)
	add_child(_auto_timer)

	_start_music()

	_fade.color = Color(0, 0, 0, 1)
	_show_beat(0)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.6)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Backdrop — geometry (size / position / zoom) is set per beat in _run_camera,
	# bottom-aligned in the space above the bar so the crop is taken from the TOP
	# (the important content sits low in these images).
	_sky = TextureRect.new()
	_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)

	# Camera-moved silhouette world
	_world = Node2D.new()
	add_child(_world)

	# Silhouette builders retired — each beat now has finished painted art.
	# (_build_skylines/_build_fire/_build_banners/_build_seal/_build_shadow/
	#  _build_candle/_build_figure remain defined below but are not called.)

	# Atmosphere (screen-space, above world but under grade/text). The particle
	# layers live in _atmo so they can be parallaxed against the Ken-Burns move.
	_build_fog()
	_atmo = Node2D.new()
	add_child(_atmo)
	_build_smoke()
	_build_embers()
	_build_dust()
	_build_lightray()

	# Palette grade wash
	_grade = ColorRect.new()
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade.color = Color(0, 0, 0, 0)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grade)

	# Vignette + film grain (cohesion) + the cyan hero glow (beat 5).
	_build_vignette()
	_build_grain()
	_build_hero_glow()

	# Narration — a FIXED full-width bar across the bottom (left edge to right
	# edge). The authored stone frame skins it; a sharp dark fill behind it, sized
	# exactly to the bar, gives legibility with no grey showing past the border.
	_text_bg = PanelContainer.new()
	_text_bg.add_theme_stylebox_override("panel", _make_fill_style())
	_text_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_bg.anchor_left = 0.0
	_text_bg.anchor_right = 1.0
	_text_bg.anchor_top = 1.0
	_text_bg.anchor_bottom = 1.0
	_text_bg.offset_left = 0.0
	_text_bg.offset_right = 0.0
	_text_bg.offset_top = -BAR_H
	_text_bg.offset_bottom = 0.0
	add_child(_text_bg)

	_text_panel = PanelContainer.new()
	_text_panel.add_theme_stylebox_override("panel", _make_frame_style())
	_text_panel.self_modulate = Color(0.82, 0.80, 0.82)   # darken frame into the grade (self_modulate spares the text)
	_text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_bg.add_child(_text_panel)

	_text_lbl = Label.new()
	_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel glyphs
	var pix := _load_pixel_font()
	if pix != null:
		_text_lbl.add_theme_font_override("font", pix)
	_text_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	_text_lbl.add_theme_color_override("font_color", C_BONE)
	_text_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_text_lbl.add_theme_constant_override("shadow_offset_x", 1)
	_text_lbl.add_theme_constant_override("shadow_offset_y", 1)
	_text_lbl.add_theme_constant_override("line_spacing", 8)
	_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_panel.add_child(_text_lbl)

	# Black transition overlay
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	# Controls
	var skip_btn := Button.new()
	skip_btn.text = "Skip  ⏭"
	skip_btn.custom_minimum_size = Vector2(110, 40)
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.position = Vector2(-130, 20)
	skip_btn.pressed.connect(_finish)
	add_child(skip_btn)
	var next_btn := Button.new()
	next_btn.text = "Next  ▶"
	next_btn.custom_minimum_size = Vector2(96, 34)
	next_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	# Tucked INSIDE the bar's bottom-right, clear of the corner bracket.
	next_btn.offset_right = -58.0
	next_btn.offset_bottom = -54.0
	next_btn.offset_left = -58.0 - 96.0
	next_btn.offset_top = -54.0 - 34.0
	next_btn.pressed.connect(_advance)
	add_child(next_btn)
	var hint := Label.new()
	hint.text = "Space or click to continue      Esc to skip"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.63, 0.6))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20, -26 - BAR_H)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _build_skylines() -> void:
	_skyline = _make_city(false)
	_skyline.modulate.a = 0.0
	_world.add_child(_skyline)
	_skyline_ruined = _make_city(true)
	_skyline_ruined.modulate.a = 0.0
	_world.add_child(_skyline_ruined)


# Draws the city as one black silhouette: towers, battlements, pitched roofs and
# a central gated keep. ruined => broken tops and gaps between buildings.
func _make_city(ruined: bool) -> Node2D:
	var root := Node2D.new()
	var baseline := _screen.y * 0.80
	var bottom := _screen.y + 8.0
	var rng := RandomNumberGenerator.new()
	rng.seed = (13 if ruined else 7)
	var x := -14.0
	while x < _screen.x + 14.0:
		var w := rng.randf_range(46.0, 92.0)
		# keep the centre clear for the keep
		if absf((x + w * 0.5) - _screen.x * 0.5) < 100.0:
			x += w
			continue
		var h := rng.randf_range(72.0, 188.0)
		if ruined:
			h *= rng.randf_range(0.45, 0.8)
		var poly := Polygon2D.new()
		poly.color = SILHOUETTE
		poly.polygon = _building_poly(x, w, h, baseline, bottom, rng.randi() % 4, ruined, rng)
		root.add_child(poly)
		x += w + (rng.randf_range(10.0, 28.0) if ruined else -rng.randf_range(2.0, 10.0))
	var keep := Polygon2D.new()
	keep.color = SILHOUETTE
	keep.polygon = _keep_poly(_screen.x * 0.5, baseline, bottom, ruined)
	root.add_child(keep)
	return root


func _building_poly(x: float, w: float, h: float, baseline: float, bottom: float, kind: int, ruined: bool, rng: RandomNumberGenerator) -> PackedVector2Array:
	var top := baseline - h
	var pts := PackedVector2Array([Vector2(x, bottom), Vector2(x, top)])
	if ruined:
		for i in range(1, 5):
			pts.append(Vector2(x + w * float(i) / 5.0, top + rng.randf_range(-4.0, 32.0)))
		pts.append(Vector2(x + w, top + rng.randf_range(0.0, 22.0)))
	else:
		match kind:
			1:  # battlements
				var merlons := 4
				var sw := w / float(merlons * 2)
				for j in range(merlons * 2 + 1):
					pts.append(Vector2(x + sw * j, top + (0.0 if j % 2 == 0 else 11.0)))
			2:  # pitched roof
				pts.append(Vector2(x + w * 0.5, top - 26.0))
				pts.append(Vector2(x + w, top))
			3:  # spired tower
				pts.append(Vector2(x + w * 0.42, top))
				pts.append(Vector2(x + w * 0.5, top - 42.0))
				pts.append(Vector2(x + w * 0.58, top))
				pts.append(Vector2(x + w, top))
			_:  # flat roof
				pts.append(Vector2(x + w, top))
	pts.append(Vector2(x + w, bottom))
	return pts


func _keep_poly(cx: float, baseline: float, bottom: float, ruined: bool) -> PackedVector2Array:
	var w := 176.0
	var h := (160.0 if ruined else 252.0)
	var x := cx - w * 0.5
	var top := baseline - h
	var gw := 44.0
	var gy := baseline - 98.0   # top of the gate arch
	var pts := PackedVector2Array()
	pts.append(Vector2(x, bottom))
	# left tower
	pts.append(Vector2(x, top + 28.0))
	pts.append(Vector2(x + 24.0, top + 28.0))
	pts.append(Vector2(x + 24.0, top))
	pts.append(Vector2(x + 44.0, top))
	pts.append(Vector2(x + 44.0, top + 28.0))
	# centre wall — battlements, or broken if ruined
	if ruined:
		pts.append(Vector2(cx - 34.0, top + 44.0))
		pts.append(Vector2(cx - 6.0, top + 10.0))
		pts.append(Vector2(cx + 22.0, top + 52.0))
	else:
		pts.append(Vector2(cx - 26.0, top + 28.0))
		pts.append(Vector2(cx - 26.0, top + 8.0))
		pts.append(Vector2(cx, top + 8.0))
		pts.append(Vector2(cx, top + 28.0))
		pts.append(Vector2(cx + 20.0, top + 28.0))
	# right tower
	pts.append(Vector2(x + w - 44.0, top + 28.0))
	pts.append(Vector2(x + w - 44.0, top))
	pts.append(Vector2(x + w - 24.0, top))
	pts.append(Vector2(x + w - 24.0, top + 28.0))
	pts.append(Vector2(x + w, top + 28.0))
	pts.append(Vector2(x + w, bottom))
	# gate: a doorway notched up from the base centre
	pts.append(Vector2(cx + gw * 0.5, bottom))
	pts.append(Vector2(cx + gw * 0.5, gy + 20.0))
	pts.append(Vector2(cx + gw * 0.25, gy))
	pts.append(Vector2(cx, gy - 8.0))
	pts.append(Vector2(cx - gw * 0.25, gy))
	pts.append(Vector2(cx - gw * 0.5, gy + 20.0))
	pts.append(Vector2(cx - gw * 0.5, bottom))
	return pts


func _build_fire() -> void:
	_fire_root = Node2D.new()
	_fire_root.modulate.a = 0.0
	_world.add_child(_fire_root)
	if not ResourceLoader.exists(FIRE_PATH):
		return
	var tex := load(FIRE_PATH)
	var count := 9
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = FIRE_FRAMES
		s.frame = randi() % FIRE_FRAMES
		var sc := randf_range(2.6, 4.4)
		s.scale = Vector2(sc, sc)
		var x := lerpf(_screen.x * 0.05, _screen.x * 0.95, float(i) / float(count - 1)) + randf_range(-16, 16)
		s.position = Vector2(x, _screen.y * 0.8 + randf_range(-10, 22))
		s.modulate = Color(1.0, 0.92, 0.8, randf_range(0.8, 1.0))
		_fire_root.add_child(s)
		_fires.append(s)


func _build_banners() -> void:
	_banners = Node2D.new()
	_banners.modulate.a = 0.0
	_world.add_child(_banners)
	var cols := [C_GOLD.darkened(0.2), C_VIOLET.lightened(0.1), C_MOSS]   # Legion / Court / Thorns
	var horizon := _screen.y * 0.78
	for i in 3:
		var bx := _screen.x * (0.3 + 0.2 * i)
		# pole
		var pole := Line2D.new()
		pole.add_point(Vector2(bx, horizon))
		pole.add_point(Vector2(bx, horizon - 150))
		pole.width = 3.0
		pole.default_color = SILHOUETTE
		_banners.add_child(pole)
		# flag (rectangle with notched bottom)
		var flag := Polygon2D.new()
		flag.polygon = PackedVector2Array([
			Vector2(bx, horizon - 150), Vector2(bx + 46, horizon - 150),
			Vector2(bx + 46, horizon - 96), Vector2(bx + 23, horizon - 110),
			Vector2(bx, horizon - 96),
		])
		flag.color = cols[i]
		_banners.add_child(flag)


func _build_seal() -> void:
	_seal = Node2D.new()
	_seal.position = Vector2(_screen.x * 0.5, _screen.y * 0.40)
	_seal.modulate.a = 0.0
	_world.add_child(_seal)
	var R := 110.0
	# glow ring (thick, low alpha) + crisp ring
	var glow := _ring(R, 12.0, 0.25)
	_seal.add_child(glow)
	_seal_circle = _ring(R, 3.0, 1.0)
	_seal.add_child(_seal_circle)
	_seal_inner = _ring(R * 0.62, 2.0, 0.9)
	_seal.add_child(_seal_inner)
	# runic spokes
	for i in 8:
		var a := TAU * float(i) / 8.0
		var sp := Line2D.new()
		sp.add_point(Vector2(cos(a), sin(a)) * (R * 0.62))
		sp.add_point(Vector2(cos(a), sin(a)) * R)
		sp.width = 2.0
		sp.default_color = C_CYAN
		_seal.add_child(sp)
		_seal_spokes.append(sp)
	# crack (hidden until cracked)
	_seal_crack = Line2D.new()
	_seal_crack.points = PackedVector2Array([
		Vector2(-R, -18), Vector2(-30, 6), Vector2(8, -24), Vector2(46, 14), Vector2(R, -6),
	])
	_seal_crack.width = 3.0
	_seal_crack.default_color = C_FORGE
	_seal_crack.visible = false
	_seal.add_child(_seal_crack)


func _ring(radius: float, width: float, alpha: float) -> Line2D:
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i) / 48.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	l.points = pts
	l.width = width
	l.default_color = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, alpha)
	return l


func _build_shadow() -> void:
	if not ResourceLoader.exists(SHADOW_PATH):
		return
	_shadow = Sprite2D.new()
	_shadow.texture = load(SHADOW_PATH)
	_shadow.position = Vector2(_screen.x * 0.5, _screen.y * 0.38)
	_shadow.scale = Vector2(2.6, 2.6)
	_shadow.modulate = Color(0.1, 0.09, 0.16, 0.0)
	_world.add_child(_shadow)


func _build_candle() -> void:
	# A single warm flame for the king's chamber (reuses the fire sheet).
	if not ResourceLoader.exists(FIRE_PATH):
		return
	_candle = Sprite2D.new()
	_candle.texture = load(FIRE_PATH)
	_candle.hframes = FIRE_FRAMES
	_candle.frame = 0
	_candle.scale = Vector2(2.2, 2.6)
	_candle.position = Vector2(_screen.x * 0.5, _screen.y * 0.42)
	_candle.modulate = Color(1.0, 0.85, 0.6, 0.0)
	_world.add_child(_candle)


func _build_figure() -> void:
	if not ResourceLoader.exists(FIGURE_PATH):
		return
	_figure = Sprite2D.new()
	_figure.texture = load(FIGURE_PATH)
	_figure.position = Vector2(_screen.x * 0.30, _screen.y * 0.62)
	_figure.scale = Vector2(1.9, 1.9)
	_figure.modulate = Color(SILHOUETTE.r, SILHOUETTE.g, SILHOUETTE.b, 0.0)
	_world.add_child(_figure)


func _build_fog() -> void:
	_fog = ColorRect.new()
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.color = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.0)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fog)


func _build_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.amount = 28
	_smoke.lifetime = 6.0
	_smoke.position = Vector2(_screen.x * 0.5, _screen.y * 0.82)
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_smoke.emission_rect_extents = Vector2(_screen.x * 0.5, 12)
	_smoke.direction = Vector2(0, -1)
	_smoke.spread = 18.0
	_smoke.gravity = Vector2(8, -10)
	_smoke.initial_velocity_min = 8.0
	_smoke.initial_velocity_max = 26.0
	_smoke.scale_amount_min = 26.0
	_smoke.scale_amount_max = 60.0
	_smoke.color = Color(0.12, 0.11, 0.13, 0.5)
	_smoke.modulate.a = 0.0
	_smoke.emitting = true
	_atmo.add_child(_smoke)


func _build_embers() -> void:
	_embers = CPUParticles2D.new()
	_embers.amount = 80
	_embers.lifetime = 3.4
	_embers.position = Vector2(_screen.x * 0.5, _screen.y * 0.84)
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(_screen.x * 0.5, 8)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 24.0
	_embers.gravity = Vector2(6, -18)
	_embers.initial_velocity_min = 18.0
	_embers.initial_velocity_max = 66.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.6
	_embers.color = C_FORGE
	_embers.modulate.a = 0.0
	_embers.emitting = true
	_atmo.add_child(_embers)


func _build_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.amount = 40
	_dust.lifetime = 7.0
	_dust.position = Vector2(_screen.x * 0.5, _screen.y * 0.4)
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(_screen.x * 0.5, _screen.y * 0.4)
	_dust.direction = Vector2(0.4, -0.2)
	_dust.spread = 40.0
	_dust.gravity = Vector2(2, -3)
	_dust.initial_velocity_min = 4.0
	_dust.initial_velocity_max = 14.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.2
	_dust.color = Color(C_BONE.r, C_BONE.g, C_BONE.b, 0.35)
	_dust.modulate.a = 0.0
	_dust.emitting = true
	_atmo.add_child(_dust)


func _build_lightray() -> void:
	_lightray = Polygon2D.new()
	_lightray.polygon = PackedVector2Array([
		Vector2(_screen.x * 0.34, 0), Vector2(_screen.x * 0.5, 0),
		Vector2(_screen.x * 0.7, _screen.y), Vector2(_screen.x * 0.4, _screen.y),
	])
	_lightray.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.0)
	add_child(_lightray)


func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.7))
	grad.set_offset(0, 0.45)
	grad.set_offset(1, 1.0)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = gt
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)


func _build_grain() -> void:
	var n := FastNoiseLite.new()
	n.frequency = 0.5
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.noise = n
	_grain = TextureRect.new()
	_grain.texture = nt
	_grain.stretch_mode = TextureRect.STRETCH_TILE
	# oversize so we can jitter it without showing edges
	_grain.size = _screen + Vector2(40, 40)
	_grain.position = Vector2(-20, -20)
	_grain.modulate = Color(1, 1, 1, 0.05)
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grain)


# Frame skin for the narration box: a dropped-in 9-slice frame if present, else
# a procedurally-drawn hewn dark-stone panel with an aged-gold edge. Content
# margins keep the text inside the frame's window (clear of the thick border).
func _make_frame_style() -> StyleBox:
	if ResourceLoader.exists(TEXTBOX_PATH):
		var st := StyleBoxTexture.new()
		st.texture = load(TEXTBOX_PATH)
		st.texture_margin_left = TEXTBOX_SLICE
		st.texture_margin_right = TEXTBOX_SLICE
		st.texture_margin_top = TEXTBOX_SLICE
		st.texture_margin_bottom = TEXTBOX_SLICE
		st.content_margin_left = 60
		st.content_margin_right = 60
		st.content_margin_top = 28
		st.content_margin_bottom = 28
		return st
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color(0.07, 0.062, 0.085, 0.86)
	sf.border_width_left = 2
	sf.border_width_right = 2
	sf.border_width_top = 2
	sf.border_width_bottom = 2
	sf.border_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.8)
	sf.corner_radius_top_left = 3
	sf.corner_radius_top_right = 3
	sf.corner_radius_bottom_left = 3
	sf.corner_radius_bottom_right = 3
	sf.content_margin_left = 46
	sf.content_margin_right = 46
	sf.content_margin_top = 28
	sf.content_margin_bottom = 28
	sf.shadow_color = Color(0, 0, 0, 0.55)
	sf.shadow_size = 12
	return sf


# Dark backing drawn behind the frame so the narration never fights the art.
# Only relevant when a frame texture is present (its center is transparent);
# without one, the frame style above is already opaque, so this stays empty.
func _make_fill_style() -> StyleBox:
	if not ResourceLoader.exists(TEXTBOX_PATH):
		return StyleBoxEmpty.new()
	# Sharp corners, sized exactly to the bar — so no grey shows past the stone.
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color(0.05, 0.045, 0.065, 0.9)
	return sf


# Load the dungeon pixel font for the narration, with antialiasing/hinting off so
# the glyphs stay crisp and pixelated. Falls back to the default font if missing.
func _load_pixel_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return null
	var f: Resource = load(FONT_PATH)
	if f is FontFile:
		var ff := (f as FontFile).duplicate() as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.force_autohinter = false
		return ff
	return f as Font


# A soft cyan radial glow, additively blended, centred over the chasm. Hidden by
# default; pulsed up on the "listening" beat. Sits above the grade, below text.
func _build_hero_glow() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 1.0))
	g.set_color(1, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 256
	gt.height = 256
	_hero_glow = TextureRect.new()
	_hero_glow.texture = gt
	_hero_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_hero_glow.anchor_left = 0.5
	_hero_glow.anchor_right = 0.5
	_hero_glow.anchor_top = 0.0
	_hero_glow.anchor_bottom = 0.0
	_hero_glow.offset_left = -340.0
	_hero_glow.offset_right = 340.0
	_hero_glow.offset_top = 150.0
	_hero_glow.offset_bottom = 560.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_hero_glow.material = mat
	_hero_glow.modulate.a = 0.0
	_hero_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero_glow)


# ---------------------------------------------------------------------------
# Beat playback
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _finished:
		return
	_fire_time += delta
	if _fire_time >= 0.09:
		_fire_time = 0.0
		for s in _fires:
			s.frame = (s.frame + 1) % FIRE_FRAMES
		if _candle != null:
			_candle.frame = (_candle.frame + 1) % FIRE_FRAMES
	# film-grain jitter
	_grain_time += delta
	if _grain_time >= 0.05:
		_grain_time = 0.0
		if _grain != null:
			_grain.position = Vector2(-20 + randf_range(-12, 12), -20 + randf_range(-12, 12))


func _show_beat(i: int) -> void:
	var b: Dictionary = _beats[i]
	var dur := 1.1

	# --- Sky: bespoke backdrop if provided, else palette gradient ---
	var custom := CINE_DIR + "beat%d.png" % (i + 1)
	if ResourceLoader.exists(custom):
		_sky.texture = load(custom)
		_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		_sky.texture = _make_sky(b.get("sky_top", C_CHARCOAL), b.get("sky_bot", C_NIGHT))
		_sky.stretch_mode = TextureRect.STRETCH_SCALE

	# --- Palette grade wash (softened so the painted art stays readable) ---
	var grade_col: Color = b.get("grade", Color(0, 0, 0, 0))
	grade_col.a *= GRADE_SCALE
	create_tween().tween_property(_grade, "color", grade_col, dur)

	# --- Silhouette elements ---
	var sky_a := float(b.get("skyline", 0.0))
	var is_ruined: bool = b.get("ruined", false)
	_tween_a(_skyline, 0.0 if is_ruined else sky_a, dur)
	_tween_a(_skyline_ruined, sky_a if is_ruined else 0.0, dur)
	_tween_a(_fire_root, b.get("fire", 0.0), dur)
	_tween_a(_banners, 1.0 if b.get("banners", false) else 0.0, dur)
	_tween_a(_candle, 1.0 if b.get("candle", false) else 0.0, dur)

	# Seal
	_apply_seal(b.get("seal", 0.0), b.get("seal_state", ""), dur)

	# Shadow
	if _shadow != null:
		create_tween().tween_property(_shadow, "modulate:a", float(b.get("shadow", 0.0)), 1.2)

	# Figure (walk in)
	if _figure != null:
		if b.get("figure", false):
			_figure.position = Vector2(_screen.x * 0.30 + 220.0, _screen.y * 0.62)
			var ft := create_tween().set_parallel(true)
			ft.tween_property(_figure, "modulate:a", 1.0, 1.6)
			ft.tween_property(_figure, "position:x", _screen.x * 0.30, 3.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		else:
			create_tween().tween_property(_figure, "modulate:a", 0.0, 0.6)

	# --- Atmosphere ---
	_tween_a(_embers, b.get("embers", 0.0), dur)
	_tween_a(_smoke, b.get("smoke", 0.0), dur)
	_tween_a(_dust, b.get("dust", 0.0), dur)
	create_tween().tween_property(_fog, "color:a", float(b.get("fog", 0.0)) * 0.28, dur)
	if _lightray != null:
		create_tween().tween_property(_lightray, "color:a", float(b.get("lightray", 0.0)) * 0.22, dur)

	# --- Camera: a distinct Ken-Burns move per beat (+ parallaxed atmosphere) ---
	_run_camera(b.get("cam", "push"))

	# --- Hero beat: cyan chasm pulse + audio swell on the key word ---
	_reset_hero(i)
	if b.get("hero", "") == "chasm_pulse":
		_trigger_chasm(b.get("text", ""))

	_typewriter(b.get("text", ""))
	_auto_timer.start(BEAT_SECONDS)


func _make_sky(top: Color, bot: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bot)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	return gt


func _tween_a(node: CanvasItem, a: float, dur: float) -> void:
	if node != null:
		create_tween().tween_property(node, "modulate:a", a, dur)


func _apply_seal(alpha: float, state: String, dur: float) -> void:
	if _seal == null:
		return
	create_tween().tween_property(_seal, "modulate:a", alpha, dur)
	_seal_crack.visible = (state == "crack" or state == "veined")
	var col := C_CYAN
	match state:
		"royal": col = C_GOLD
		"veined": col = C_CRIMSON
		"crack": col = C_FORGE
		_: col = C_CYAN
	_seal_circle.default_color = col
	_seal_inner.default_color = col.darkened(0.1)
	for sp in _seal_spokes:
		sp.default_color = col
	if state == "veined":
		_seal_crack.default_color = C_BLOOD.lightened(0.2)
	elif state == "crack":
		_seal_crack.default_color = C_FORGE
	# gentle pulse
	if _seal.has_meta("pulse"):
		var old: Tween = _seal.get_meta("pulse")
		if old != null and old.is_valid():
			old.kill()
	if alpha > 0.05:
		var p := create_tween().set_loops()
		p.tween_property(_seal, "scale", Vector2(1.05, 1.05), 1.8).set_trans(Tween.TRANS_SINE)
		p.tween_property(_seal, "scale", Vector2(1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
		_seal.set_meta("pulse", p)


# A named Ken-Burns move per beat. Control.scale pivots on pivot_offset so the
# zoom stays centred; start scale is always >1 and pan stays within the scale
# margin, so the painted image never reveals an edge. The atmosphere layer pans
# the opposite way at half speed for a parallax sense of depth.
func _run_camera(cam: String) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	if _sky == null:
		return
	# Pans are horizontal only (pan.y = 0): the zoom pivots on the bottom edge, so
	# the lower part of the image stays anchored at the bar and only the TOP is
	# ever cropped or revealed.
	var from_s := 1.05
	var to_s := 1.11
	var pan := Vector2(-8, 0)
	match cam:
		"push":      from_s = 1.04; to_s = 1.12; pan = Vector2(-8, 0)
		"pushhard":  from_s = 1.06; to_s = 1.16; pan = Vector2(0, 0)
		"pull":      from_s = 1.14; to_s = 1.05; pan = Vector2(0, 0)
		"driftup":   from_s = 1.05; to_s = 1.13; pan = Vector2(-6, 0)
		"driftdown": from_s = 1.13; to_s = 1.05; pan = Vector2(6, 0)
		"panright":  from_s = 1.07; to_s = 1.12; pan = Vector2(24, 0)
		"panleft":   from_s = 1.07; to_s = 1.12; pan = Vector2(-24, 0)
		_:           from_s = 1.05; to_s = 1.11; pan = Vector2(-8, 0)

	# Bottom-align the backdrop in the area above the bar.
	var vis_h := _screen.y - BAR_H
	var sky_h := _screen.x * 9.0 / 16.0
	if sky_h < vis_h:
		sky_h = vis_h
	_sky.size = Vector2(_screen.x, sky_h)
	_sky.pivot_offset = Vector2(_screen.x * 0.5, sky_h)   # bottom-centre pivot
	var base := Vector2(0.0, vis_h - sky_h)               # image bottom at the bar top
	_sky.position = base
	_sky.scale = Vector2(from_s, from_s)
	var dur := BEAT_SECONDS + 2.0
	_cam_tween = create_tween().set_parallel(true)
	_cam_tween.tween_property(_sky, "scale", Vector2(to_s, to_s), dur).set_trans(Tween.TRANS_SINE)
	_cam_tween.tween_property(_sky, "position", base + pan, dur).set_trans(Tween.TRANS_SINE)
	if _atmo != null:
		_atmo.position = Vector2.ZERO
		_cam_tween.tween_property(_atmo, "position", -pan * 0.5, dur).set_trans(Tween.TRANS_SINE)


# Reset the hero glow / music swell between beats (so a stray pulse from the
# previous beat can't leak into the next one).
func _reset_hero(i: int) -> void:
	if _hero_tween != null and _hero_tween.is_valid():
		_hero_tween.kill()
	if _swell_tween != null and _swell_tween.is_valid():
		_swell_tween.kill()
	if _hero_glow != null:
		_hero_glow.modulate.a = 0.0
	if i > 0 and _music != null and _music.playing:
		_music.volume_db = MUSIC_VOLUME_DB


# Fire the cyan chasm pulse + music swell as the typewriter reaches the last word.
func _trigger_chasm(text: String) -> void:
	if _hero_glow == null:
		return
	var delay := maxf(clampf(float(text.length()) * 0.032, 1.0, 3.2) * 0.88, 0.4)
	_hero_tween = create_tween()
	_hero_tween.tween_interval(delay)
	_hero_tween.tween_callback(_swell_music)
	_hero_tween.tween_property(_hero_glow, "modulate:a", 0.75, 0.45).set_trans(Tween.TRANS_SINE)
	_hero_tween.tween_property(_hero_glow, "modulate:a", 0.30, 1.3).set_trans(Tween.TRANS_SINE)


func _swell_music() -> void:
	if _music == null or not _music.playing:
		return
	_swell_tween = create_tween()
	_swell_tween.tween_property(_music, "volume_db", MUSIC_VOLUME_DB + 4.0, 0.4).set_trans(Tween.TRANS_SINE)
	_swell_tween.tween_property(_music, "volume_db", MUSIC_VOLUME_DB, 1.8).set_trans(Tween.TRANS_SINE)


func _typewriter(text: String) -> void:
	_text_lbl.text = text
	_text_lbl.modulate.a = 1.0
	_text_lbl.visible_characters = 0
	var d := clampf(float(text.length()) * 0.032, 1.0, 3.2)
	create_tween().tween_property(_text_lbl, "visible_characters", text.length(), d)


func _advance() -> void:
	if _transitioning or _finished:
		return
	if _index >= _beats.size() - 1:
		_finish()
		return
	_transitioning = true
	_auto_timer.stop()
	_index += 1
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.45)
	t.tween_callback(func():
		_show_beat(_index)
		_transitioning = false
	)
	t.tween_property(_fade, "color:a", 0.0, 0.75)


# ---------------------------------------------------------------------------
# Music / lifecycle
# ---------------------------------------------------------------------------
func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	var stream: AudioStream = _load_first_existing(MUSIC_PATHS)
	if stream == null:
		return
	_loop_stream(stream)
	_music.stream = stream
	_music.volume_db = -30.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_VOLUME_DB, 1.5)


func _load_first_existing(paths: Array) -> AudioStream:
	for p in paths:
		if ResourceLoader.exists(p):
			var res := load(p)
			if res is AudioStream:
				return res
	return null


func _loop_stream(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "loop" in stream:
		stream.set("loop", true)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_auto_timer.stop()
	GameState.intro_seen = true
	if SaveManager.current_slot > 0:
		SaveManager.save_game(SaveManager.current_slot)
	if _music != null and _music.playing:
		var t := create_tween()
		t.tween_property(_music, "volume_db", -40.0, 0.5)
		await t.finished
	if not is_inside_tree():
		return
	SceneFader.change_scene(HUB_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_finish()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
