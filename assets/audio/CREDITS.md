# Audio Credits

All audio below is **CC0 1.0 (public domain)** — free to use, modify, and ship
with **no attribution required**. Credits are listed anyway as good practice.
Source license deed: https://creativecommons.org/publicdomain/zero/1.0/

## Music (`music/`)

| File | Title | Author | Source |
|------|-------|--------|--------|
| `intro_theme.ogg` | Whispers in the Fog | Ruhinre | https://opengameart.org/content/whispers-in-the-fog |
| `hub_theme.mp3` | Town Theme (RPG) | cynicmusic | https://opengameart.org/content/town-theme-rpg |
| `combat_theme.wav` | Epic Boss Battle (Seamlessly Looping) | SubspaceAudio / Juhani Junkala | https://opengameart.org/content/boss-battle-music |

## Sound effects (`sfx/`)

| Folder | Pack | Count | Author | Source |
|--------|------|-------|--------|--------|
| `sfx/rpg/` | RPG Audio | 51 | Kenney | https://kenney.nl/assets/rpg-audio |
| `sfx/interface/` | Interface Sounds | 100 | Kenney | https://kenney.nl/assets/interface-sounds |
| `sfx/impact/` | Impact Sounds | 130 | Kenney | https://kenney.nl/assets/impact-sounds |

---

### Wiring status — all wired
- `intro_theme.ogg` → opening cinematic (auto-plays, loops, fades).
- `hub_theme.mp3` → city/hub screen, via `MusicManager` (autoload).
- `combat_theme.wav` → battles; `MusicManager` crossfades to it on combat start
  and back to the hub theme when combat ends.
- SFX → `SFX` (autoload): a click on every button; coin on purchases/recruits;
  a hammer on rebuild/upgrade; metal-hit / cloth-whiff on combat hits & misses;
  a heavy thud when a wall falls; victory / defeat stings.

To swap any track, just replace the file (keep the name). To retune volumes or
remap SFX, see `scripts/autoload/MusicManager.gd` and `scripts/autoload/SFX.gd`.

### Notes
- `combat_theme.wav` is ~22 MB (uncompressed WAV). To shrink the repo you can
  convert it to `.ogg` later; Godot plays the `.wav` fine as-is.
- These were chosen by title/description, not auditioned — give them a listen and
  swap any that don't fit the mood.
