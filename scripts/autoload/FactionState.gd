# res://scripts/autoload/FactionState.gd
# Tracks standing with the Wardens, Iron Legion, and Pale Court factions.
# Other systems read computed properties (e.g. wardens_dungeon_xp_bonus) and call
# event hooks (e.g. on_dungeon_level_reached) to drive passive gameplay effects.
extends Node

# ---------------------------------------------------------------------------
# Standing values — 0–100, clamped on every write
# ---------------------------------------------------------------------------
## The Wardens: ancient forest shamans who guard the dungeon Seal. Wary of outsiders — trust must be earned.
var wardens_standing: int = 30
## Iron Legion: disciplined human army that wants the dungeon. Respects survival — starts guardedly positive.
var iron_legion_standing: int = 45
## Pale Court: unknown quantities with unknown agenda. Relationship starts cold.
var pale_court_standing: int = 20

# ---------------------------------------------------------------------------
# Per-turn change tracking — lets the recap screen surface "what changed"
# without polling every system. Accumulated net delta is reset at turn start.
# ---------------------------------------------------------------------------
var turn_delta_wardens: int = 0
var turn_delta_iron_legion: int = 0
var turn_delta_pale_court: int = 0
var diplomatic_actions_used_this_turn: int = 0

## Clears the accumulated per-turn standing deltas. Call at the start of end_turn().
func begin_turn_tracking() -> void:
	turn_delta_wardens = 0
	turn_delta_iron_legion = 0
	turn_delta_pale_court = 0
	diplomatic_actions_used_this_turn = 0

func can_use_diplomatic_action() -> bool:
	return diplomatic_actions_used_this_turn < 1

func record_diplomatic_action_used() -> void:
	diplomatic_actions_used_this_turn += 1

## Returns ordered standing-change entries for any faction that moved this turn.
## Each entry: { key, name, delta, value, label, color }. Empty when nothing changed.
func get_turn_standing_changes() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	if turn_delta_wardens != 0:
		changes.append({
			"key": "wardens", "name": "The Wardens",
			"delta": turn_delta_wardens, "value": wardens_standing,
			"label": get_standing_label(wardens_standing),
			"color": Color(0.40, 0.78, 0.45),
		})
	if turn_delta_iron_legion != 0:
		changes.append({
			"key": "iron_legion", "name": "Iron Legion",
			"delta": turn_delta_iron_legion, "value": iron_legion_standing,
			"label": get_standing_label(iron_legion_standing),
			"color": Color(0.46, 0.62, 0.80),
		})
	if turn_delta_pale_court != 0:
		changes.append({
			"key": "pale_court", "name": "Pale Court",
			"delta": turn_delta_pale_court, "value": pale_court_standing,
			"label": get_standing_label(pale_court_standing),
			"color": Color(0.83, 0.69, 0.22),
		})
	return changes

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal faction_standing_changed

# ---------------------------------------------------------------------------
# Public API — mutators
# ---------------------------------------------------------------------------
func change_wardens(delta: int) -> void:
	wardens_standing = clampi(wardens_standing + delta, 0, 100)
	turn_delta_wardens += delta
	# Rivalry lock: only one of Wardens/Iron Legion can be Friendly+ simultaneously
	if wardens_standing >= 61 and iron_legion_standing >= 61:
		var drop := iron_legion_standing - 58
		iron_legion_standing = 58
		turn_delta_iron_legion -= drop
	# Rivalry: Wardens vs Iron Legion — gaining Wardens standing costs Iron Legion 40% of the gain.
	if delta > 0:
		var penalty := int(delta * 0.4)
		iron_legion_standing = clampi(iron_legion_standing - penalty, 0, 100)
		turn_delta_iron_legion -= penalty
	emit_signal("faction_standing_changed")

func change_iron_legion(delta: int) -> void:
	iron_legion_standing = clampi(iron_legion_standing + delta, 0, 100)
	turn_delta_iron_legion += delta
	# Rivalry lock: only one of Wardens/Iron Legion can be Friendly+ simultaneously
	if iron_legion_standing >= 61 and wardens_standing >= 61:
		var drop := wardens_standing - 58
		wardens_standing = 58
		turn_delta_wardens -= drop
	# Rivalry: Iron Legion vs Wardens — gaining Iron Legion standing costs Wardens 40% of the gain.
	if delta > 0:
		var penalty := int(delta * 0.4)
		wardens_standing = clampi(wardens_standing - penalty, 0, 100)
		turn_delta_wardens -= penalty
	emit_signal("faction_standing_changed")

func change_pale_court(delta: int) -> void:
	pale_court_standing = clampi(pale_court_standing + delta, 0, 100)
	turn_delta_pale_court += delta
	# Rivalry: Pale Court vs both — gaining Pale Court standing costs each rival 20% of the gain.
	if delta > 0:
		var penalty := int(delta * 0.2)
		wardens_standing     = clampi(wardens_standing     - penalty, 0, 100)
		iron_legion_standing = clampi(iron_legion_standing - penalty, 0, 100)
		turn_delta_wardens     -= penalty
		turn_delta_iron_legion -= penalty
	emit_signal("faction_standing_changed")

# ---------------------------------------------------------------------------
# Public API — display helpers
# ---------------------------------------------------------------------------
func get_standing_label(value: int) -> String:
	if value < 20: return "Hostile"
	if value < 40: return "Cold"
	if value < 60: return "Neutral"
	if value < 76: return "Friendly"
	return "Allied"

## Standing-tier colors, muted to match the parchment palette (no neon).
## Hostile -> crimson/wax, Cold -> leather, Neutral -> muted tan-gold,
## Friendly -> moss, Allied -> a brighter but still muted green.
func get_standing_color(value: int) -> Color:
	if value < 20: return GameTheme.WAX
	if value < 40: return GameTheme.LEATHER
	if value < 60: return Color("#a39456")
	if value < 76: return GameTheme.MOSS
	return Color("#74875a")

## Returns human-readable lines describing the Wardens' current active effects.
func get_wardens_effects_text() -> Array[String]:
	var lines: Array[String] = []
	if wardens_standing >= 76:
		lines.append("+25% dungeon XP")
		lines.append("Veiled threat reduced by 8/turn")
	elif wardens_standing >= 60:
		lines.append("+10% dungeon XP")
		lines.append("Veiled threat reduced by 5/turn")
	else:
		lines.append("No active bonuses")
	return lines

## Returns human-readable lines describing the Iron Legion's current active effects.
func get_iron_legion_effects_text() -> Array[String]:
	var lines: Array[String] = []
	if iron_legion_standing <= 20:
		lines.append("Iron Legion soldiers join enemy waves")
	elif iron_legion_standing >= 76:
		lines.append("20% trade discount on all markets")
	elif iron_legion_standing >= 60:
		lines.append("10% trade discount on all markets")
	else:
		lines.append("No active bonuses")
	return lines

## Returns human-readable lines describing the Pale Court's current active effects.
func get_pale_court_effects_text() -> Array[String]:
	var lines: Array[String] = []
	if pale_court_standing <= 20:
		lines.append("Agents steal 8 Gold from the coffers each turn")
	elif pale_court_standing <= 40:
		lines.append("Agents steal 3 Gold from the coffers each turn")
	elif pale_court_standing >= 76:
		lines.append("Aldous's tonics are available, so soldiers may be enhanced")
		lines.append("Rare alchemical items appear in market occasionally")
	elif pale_court_standing >= 60:
		lines.append("Alchemical items occasionally appear in market")
	else:
		lines.append("No active effects")
	return lines

# ---------------------------------------------------------------------------
# Computed gameplay properties (queried by DungeonState / GameState)
# ---------------------------------------------------------------------------

## XP multiplier bonus from Warden favour. Applied on top of base dungeon XP.
var wardens_dungeon_xp_bonus: float:
	get:
		if wardens_standing >= 76: return 0.25
		if wardens_standing >= 60: return 0.10
		return 0.0

## When true, the Wardens are actively disrupting Veiled seepage.
var wardens_reduces_valuiti_threat: bool:
	get: return wardens_standing >= 60

## When true, Iron Legion sends soldiers to reinforce enemy waves.
var iron_legion_joins_waves: bool:
	get: return iron_legion_standing <= 20

## Fraction discount applied to market purchase prices (0.0 – 0.20).
var iron_legion_trade_discount: float:
	get:
		if iron_legion_standing >= 76: return 0.20
		if iron_legion_standing >= 60: return 0.10
		return 0.0

## When true, the Pale Court is actively stealing gold each turn.
var pale_court_steals_resources: bool:
	get: return pale_court_standing <= 20

## Gold stolen by the Pale Court per turn (0 if neutral or friendly).
var pale_court_resource_drain: int:
	get:
		if pale_court_standing <= 20: return 8
		if pale_court_standing <= 40: return 3
		return 0

## When true, Aldous's tonics are available (standing Allied).
var pale_court_tonic_available: bool:
	get: return pale_court_standing >= 81

# ---------------------------------------------------------------------------
# Event hooks — called by other systems
# ---------------------------------------------------------------------------

## Called when DungeonState.dungeon_level increases to a new value.
## Deeper digging threatens the Iron Legion's agenda while earning Warden trust.
## Pale Court is pleased by level 5+ (they want the minerals).
func on_dungeon_level_reached(level: int) -> void:
	match level:
		2:
			change_iron_legion(-5)
			change_wardens(+5)
		3:
			change_iron_legion(-10)
			change_wardens(+8)
	if level >= 5:
		change_iron_legion(-15)
		change_wardens(+10)
		change_pale_court(+5)

## Called after each city-defense wave is survived.
## The Iron Legion respects demonstrated resilience, up to a point.
func on_wave_survived(_wave_number: int) -> void:
	# Capped at 60 so the player cannot grind their way to Allied standing
	# through wave victories alone — requires diplomatic options as well.
	if iron_legion_standing < 60:
		change_iron_legion(+2)

## Called when the player reads a story letter.
## Letters from known senders shift their faction's standing.
func on_letter_read(sender: String) -> void:
	if "Otava" in sender or "Warden" in sender:
		change_wardens(+5)
	if "Boran" in sender or "Iron Legion" in sender:
		change_iron_legion(+3)
	if "Aldous" in sender or "Pale Court" in sender:
		change_pale_court(+3)

# ---------------------------------------------------------------------------
# Save / load helpers
# ---------------------------------------------------------------------------
func get_data_for_save() -> Dictionary:
	return {
		"wardens": wardens_standing,
		"iron_legion": iron_legion_standing,
		"pale_court": pale_court_standing,
	}

func restore_from_save(data: Dictionary) -> void:
	# Support old saves that used "spini" key; fall back to new starting values, not 50.
	wardens_standing     = clampi(data.get("wardens",     data.get("spini", 30)), 0, 100)
	iron_legion_standing = clampi(data.get("iron_legion", 45), 0, 100)
	pale_court_standing  = clampi(data.get("pale_court",  20), 0, 100)
	emit_signal("faction_standing_changed")
