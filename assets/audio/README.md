# Audio

Drop audio files here and the game picks them up automatically. **Godot supports
`.ogg` (best for music — loops seamlessly), `.wav` (best for short SFX), and `.mp3`.**

## Wired up right now

| What | Put the file at | Notes |
|------|-----------------|-------|
| Opening cinematic theme | `assets/audio/music/intro_theme.ogg` | Also accepts `.mp3` / `.wav`. Fades in, loops, fades out into the hub. If absent, the intro runs silent — no errors. |

The intro looks for `intro_theme.ogg` → `.mp3` → `.wav`, in that order (see
`MUSIC_PATHS` in `scripts/ui/intro_cinematic.gd`). Just name your file
`intro_theme.ogg`, drop it in `music/`, and play a New Game.

## Suggested layout for future audio

```
assets/audio/
  music/      # looping background tracks (.ogg)
    intro_theme.ogg
    hub_theme.ogg        # (not wired yet)
    combat_theme.ogg     # (not wired yet)
  sfx/        # one-shot sound effects (.wav)
    button_click.wav     # (not wired yet)
    sword_hit.wav        # (not wired yet)
```

## Where to find audio that fits this game

Vibe to aim for: **dark fantasy / gritty medieval with a hopeful edge** —
low strings, somber solo instruments, distant war drums, the odd lute for the
city. Witcher / Dragon Age: Origins are good reference points.

### Free (check the license — CC0 needs nothing, CC-BY needs a credit)
- **OpenGameArt.org** — biggest game-asset library; filter by CC0/CC-BY. Search
  "dark fantasy", "medieval", "dungeon ambience".
- **Pixabay Music** (pixabay.com/music) — royalty-free, **no attribution
  required**. Search "cinematic medieval", "dark fantasy", "epic somber".
- **FreePD.com** — public-domain (CC0) music, including cinematic/horror beds.
- **Incompetech (Kevin MacLeod)** — huge catalogue, lots of medieval/dark
  orchestral. CC-BY: you must credit him.
- **Freesound.org** — best for SFX and ambiences (wind, fire, crowd, footsteps).
  Per-sound licenses; filter to CC0.
- **Sonniss "GDC Game Audio Bundle"** — gigabytes of pro, royalty-free SFX, free
  every year.
- **itch.io** — search "dark fantasy music pack" / "RPG music". Many free or
  pay-what-you-want loop packs (e.g. Tallbeard's *Music Loop Bundle*).
- **YouTube Audio Library** — free tracks; filter genre = Cinematic/Ambient and
  the attribution column.

### Paid (if you want polish / one subscription covers everything)
- **GameDev Market**, **Unity Asset Store**, **Unreal Marketplace** — themed
  medieval/fantasy music + SFX packs, cheap and licensed for games.
- **Humble Bundle** audio bundles — periodically huge, cheap, game-licensed.
- **Artlist / Epidemic Sound** — subscription, large libraries, simple license.

### AI-generated (read the commercial-use terms first)
- **Suno**, **Udio** — generate full tracks from a text prompt.
- **Mubert**, **Soundraw** — royalty-free generative music aimed at games.

> Licensing tip: for anything you ship, keep a note of the source + license per
> file. CC0 = do anything. CC-BY = include a credit (a CREDITS.md is plenty).
> Avoid copyrighted game soundtracks (Witcher, etc.) — reference the *feel*, not
> the files.
