# Dungeon UI — Asset Spec (drop assets here)

This folder is the **single source of truth** for the dungeon UI art. Place files at the
exact paths/names below. The UI code (theme + components) will load `res://assets/ui/dungeon/...`.

- **Format:** PNG-32 with alpha. **No anti-aliasing on edges** (true pixel art).
- **Import:** each file's `.import` must use **Filter = Nearest** (the project default is being
  set to Nearest, so this is automatic — just don't override it per-file).
- **Design at native size.** Never downscale a high-res image into these — draw at the pixel size listed.

---

## 1. Palette (use these exact hexes on EVERYTHING — this is what makes it cohesive)

| Role | Hex | Use |
|---|---|---|
| Stone darkest | `#16141d` | outlines, deepest shadow, panel interior |
| Stone dark | `#2a2633` | panel/button base |
| Stone mid | `#3c3a4a` | raised surfaces, button face |
| Stone light | `#5a5870` | top-lit edges |
| Gold | `#d4af37` | all trim / borders / rivets (the unifying accent) |
| Gold highlight | `#f2d27a` | gold top-light |
| Parchment | `#d4d4be` | body text, readable insets |
| Torch orange | `#e8913a` | flame mid, warm glow |
| Torch bright | `#ffcf6b` | flame core, current-room glow |
| Danger red | `#c44533` | monster/boss accents, low HP |
| Heal blue | `#4aa3e8` | fountain accent |
| Lore purple | `#9a6cff` | lore accents |

These mirror the game's existing palette (gold `#d4af37`, parchment `#d4d4be`) so the dungeon
matches the rest of the game even though it's textured.

## 2. The 5 rules that make it look "finished"

1. **One light source — top-left.** Light edge on top/left, shadow on bottom/right of every
   frame, button, and medallion. Consistency here is 80% of the "polished" feel.
2. **1px dark outline (`#16141d`)** around every UI shape. Clean outlines = intentional, not amateur.
3. **3–4 tones per material max** (base, shadow, light, highlight). Don't over-render; flat-ish reads better at this scale.
4. **Same gold trim + corner rivets/studs** on panels, buttons, and medallion rings. Repeating one
   motif ties unrelated elements into a "set."
5. **Warm torch light** over a cool stone background. The orange-vs-blue contrast is the mood.

---

## 3. Files needed (exact paths, sizes, 9-slice margins)

> **9-slice margin** = the px from each edge that must NOT stretch (the corner art). Keep all four
> corners identical so the margin is uniform. If you change a size, tell me the new corner inset.

### frames/  — 9-slice panels
| File | Size | 9-slice margin | What it is |
|---|---|---|---|
| `frames/window.png` | 128×128 | 32 | Big ornate stone window — used for lore / market / party overlays |
| `frames/panel.png` | 64×64 | 16 | General panel — side panel, cards, log box, sub-panels |

### buttons/  — 9-slice, 4 states (all 64×64, margin 16)
| File | State look |
|---|---|
| `buttons/normal.png` | stone face, gold edge, top-left lit |
| `buttons/hover.png` | brighter / faint torch-warm glow on the edge |
| `buttons/pressed.png` | inset/darker, shadow flipped (light bottom-right) |
| `buttons/disabled.png` | desaturated grey, no gold |

### bars/  — HP/progress bars (9-slice horizontally)
| File | Size | margin (L,R,T,B) | Note |
|---|---|---|---|
| `bars/bar_bg.png` | 24×16 | 6,6,4,4 | empty groove (dark) |
| `bars/bar_fill.png` | 24×16 | 6,6,4,4 | **near-white/light grey** — code tints it green/yellow/red by HP% |

### medallions/  — the room nodes (the centerpiece)
> **Contrast design:** the disc stays **dark** so a light icon always reads on it; the room *color*
> is shown by a thin tinted **rim**, not by tinting the whole disc.

| File | Size | What it is |
|---|---|---|
| `medallions/ring.png` | 80×80 | ornate **neutral** stone+gold circular frame, transparent center (~60px hole) — never tinted |
| `medallions/disc.png` | 64×64 | **dark polished-stone** circular face (neutral), subtle top-left light — the icon sits on this |
| `medallions/rim.png` | 72×72 | thin **white** circular ring (~4px stroke), transparent inside & outside — code tints it to the room color to signal type |
| `medallions/glow.png` | 112×112 | soft radial warm glow (additive) — only the current room shows it, pulsing |
| `medallions/check.png` | 32×32 | gold/green checkmark — overlaid on cleared rooms |
| `medallions/lock.png` | 28×28 | grey padlock — overlaid on locked/undiscovered rooms |

### icons/rooms/  — one per room type (48×48, transparent, pale cream `#f0e6c8` so they read on the dark disc + dark outline)
| File | Subject |
|---|---|
| `icons/rooms/spawn.png` | doorway / banner / portal (the entrance) |
| `icons/rooms/monster.png` | crossed swords |
| `icons/rooms/elite.png` | horned / armored skull |
| `icons/rooms/boss.png` | crowned skull (bigger, meaner — clearly distinct from elite) |
| `icons/rooms/fountain.png` | fountain or water drop |
| `icons/rooms/empty.png` | rubble / faint dots (subtle, low-contrast) |
| `icons/rooms/market_trait.png` | open tome / scroll (skills & traits) |
| `icons/rooms/market_gear.png` | treasure chest or anvil (gear) |
| `icons/rooms/lore.png` | rune tablet / inscription (distinct from the trait scroll) |

### background/  — dungeon atmosphere
| File | Size | Note |
|---|---|---|
| `background/cave_back.png` | ≥1280×720 | far cave wall (darkest, low detail) — **tileable horizontally preferred** |
| `background/cave_mid.png` | ≥1280×720 | mid pillars/arches |
| `background/cave_front.png` | ≥1280×720 | near floor/foreground detail |
| `background/vignette.png` | 1280×720 | transparent center → dark edges, frames the screen |

> A single `background/cave.png` (1280×720) is acceptable if you don't want 3 parallax layers.
>
> **PixelLab-friendly alternative:** instead of full 1280×720 layers, provide a **seamless tileable
> cave-wall tile** `background/wall_tile.png` (128×128) + a few decor objects (`background/pillar.png`,
> `background/arch.png`, `background/brazier.png`). The code will tile the wall, scatter the decor,
> and add the gradient + vignette in-engine.

### fx/
| File | Size | Note |
|---|---|---|
| `fx/torch_strip.png` | 192×48 | **horizontal sprite sheet, 6 frames of 32×48** (torch + animated flame loop) |
| `fx/connector.png` | 16×16 | tileable stone/chain link — drawn as the path between rooms |

### fonts/
| File | Recommendation |
|---|---|
| `fonts/body.ttf` | **Pixel Operator** (OFL, free, very readable) — body text, buttons, labels |
| `fonts/heading.ttf` | **Alagard** (free for games) or **m6x11 / m5x7** (Daniel Linssen) — titles & headers only |

Use integer sizes on the font's native grid: **body 16**, **headers 16/24**, **title 32**. Ship each font's LICENSE text next to it.

---

## 4. RoomType → asset wiring (for reference; handled in code)

The room color (`DungeonRoom.get_display_color()`) tints **`rim.png`** only; the ring and disc stay
neutral and the cream icon sits on the dark disc → always high contrast. Color key:
SPAWN=green, MONSTER=red, ELITE=orange, BOSS=dark red, FOUNTAIN=blue, EMPTY=grey,
MARKET_TRAIT=yellow, MARKET_GEAR=lime, LORE=purple.

## 5. When assets are in

Once these files exist, the build step creates: a shared `Theme` (.tres) wired to these textures,
`RoomMedallion` + `DungeonBackdrop` components, and refactors the dungeon scene to use them.
Missing files degrade gracefully (code falls back to a flat stylebox) so you can add art incrementally.
