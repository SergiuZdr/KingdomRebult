# War-Table Main Menu — Layout Spec

Viewport: 1200×720, canvas_items stretch, NEAREST filtering (uniform integer-ish scales preferred).
All art in this folder is final (PixelLab, game palette family). `table_wood_raw.png` is the
pre-composite original — not used at runtime.

## Layers (back → front)

1. **NIGHT base** — full-rect ColorRect `#17151c` (safety fill behind everything).
2. **Table surface** — `table_wood.png` (200×200, fully opaque, has a baked candle-light pool
   slightly above center fading to near-NIGHT edges). Stretch to ~1320×800, centered (60px
   overscan on each side). STRETCH_SCALE; chunky pixels are intended.
3. **Parchment city map** — `map_parchment.png` (300×220) scaled ×2.4 → 720×528.
   Center at (600, 368): map rect ≈ (240, 104) → (960, 632). Rotate −1.5° for a casually
   thrown-on-table feel.
4. **Title** — rendered as TEXT over the map's top band (the map's mostly-parchment margin):
   "KINGDOM REBUILT", heading font, 54px, color INK `#2e2519` with a strong 8px PARCHMENT
   `#d8c89e` font outline (so it pops against both parchment and any darker map detail),
   centered at ≈ (600, 168), same −1.5° rotation as the map (parent it to the map node).
   Subtitle "The prince returns to a city of ash." body font 15px, INK with a 4px PARCHMENT
   outline, centered at ≈ (600, 206).
5. **Dressing props** (non-interactive, MOUSE_FILTER_IGNORE, parented to map or table):
   - `prop_dagger.png` (160×100, reads as a sword) ×3.5 → 560×350 — an oversized table prop
     running off the LEFT screen edge: hilt off-screen, blade lying across the table's left
     side, center ≈ (-80, 280), rotation ≈ −20°. Stays clear of the New Game letter's hover
     zone (center ≈ (160, 520)) — positioned above/left of it.
   - `prop_inkpot.png` (120×120) ×1.2 — right of the map, center ≈ (1030, 280).
6. **Interactive props** (hover targets — TextureButton or Control+TextureRect):
   - **New Game** — `prop_letter.png` (140×140, wax-sealed orders) ×1.5 → 210px.
     Center ≈ (160, 520) (bottom-left table area, inside the lit pool's reach).
   - **Load Save** — `prop_ledger.png` (140×140, leather ledger) ×1.5 → 210px.
     Center ≈ (600, 660)? NO — keep it clear of the map: center ≈ (1040, 520).
   - **Quit** — `prop_candle.png` (110×130, lit candle) ×1.3 → ~143×169.
     Center ≈ (1090, 140) (top-right, its glow motivates the table's light pool).

NOTE: the candle glow radial gradient and the screen-edge vignette overlay have been REMOVED
(both read as a washed-out white halo/blob over the art). The candle sprite itself stays;
only the glow gradient is gone. Layers 7/8 from the original spec no longer exist.

## Prop labels & interaction

- Each interactive prop gets a label UNDER it (body font 19px): "New Game" / "Load Save" /
  "Quit Game". Idle AND hover: full-opacity PARCHMENT `#d8c89e` with a 2px NIGHT `#17151c`
  font outline (no soft drop shadow — the outline keeps it readable on the dark table).
  Hover also brightens the prop (modulate 1.15) + scales it to 1.07 (0.12s QUAD out, pivot
  at prop center).
- Click feedback before action (~0.2–0.4s, then proceed):
  - Letter → quick press feedback (scale to 0.94 then back to 1.0, ~0.18s total) → opens
    the save-slot panel in "new game" mode. (No seal-flash effect.)
  - Ledger → slight tilt tween → opens save-slot panel in "load" mode.
  - Candle → modulate to dark (snuff) over 0.4s → quit.
- Load Save disabled state (no saves): ledger modulate 0.55, label "Load Save" INK_SOFT,
  no hover response.
- Entrance: table+map+dressing fade in (0.4s); interactive props `UIKit.pop_in` staggered
  +0.08s each; title fades in last.
- Keep: SaveSlotsPanel behavior/structure, MusicManager.play("menu"), SceneFader transitions.
- Keyboard: Enter = New Game, Esc = nothing (menu is root).

## Save-slots panel skin

The panel that opens from the letter (New Game) or the ledger (Load) is reskinned per mode
in `_apply_slots_panel_skin(mode)` (scripts/ui/main_menu.gd), panel size ~600×520:

- **New Game** ("save" mode) — background = `panel_sheet.png` (256×256 blank weathered
  parchment sheet), stretched via StyleBoxTexture. Fallback (if the art doesn't exist yet):
  flat PARCHMENT with a LEATHER border.
- **Load** ("load" mode) — background = `panel_book.png` (256×256 open crimson leather book
  with two parchment pages), stretched the same way. Fallback: flat PARCHMENT with a
  CRIMSON border.
- Both modes: panel title text is INK with a small (2px) PARCHMENT outline. Slot cards keep
  the existing "Card" theme (VELLUM face); slot/back/delete button logic is unchanged.
- `panel_sheet.png` / `panel_book.png` are optional — code checks `ResourceLoader.exists()`
  and falls back cleanly, so dropping the art in later needs no code change (just re-import).

## Hover-safety note

Props are positioned ABSOLUTELY (plain Control parents, not containers) so scale/position
tweens never fight layout. Set pivot_offset to half size after sizing.
