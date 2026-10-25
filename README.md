# Darko Dungo

A Godot 4.7 prototype whose turn-based combat mirrors Darkest Dungeon 2. Right now it is a combat sandbox: four heroes against three enemy waves.

- Design decisions: [docs/design.md](docs/design.md)
- DD2 combat research: [docs/research/darkest-dungeon-combat.md](docs/research/darkest-dungeon-combat.md)

## Run it

Open the folder in Godot 4.7 and press Play, or from a terminal:

```bash
godot --path .
```

Controls: click a skill, then a highlighted target. Keys: `1`–`8` skills, `Left`/`Right`/`Tab` change target, `Enter`/`Space` confirm, `L` combat log, `S` speed, `R` restart. Hover any unit for its stats.

Watch it play itself: `godot --path . -- --autoplay --speed=2`.

## Add art

Units draw a coloured placeholder until they have a sprite.

1. Put a transparent PNG in the project, e.g. `art/units/ghoul.png`. Draw every unit facing right with its feet on the bottom edge; enemies are mirrored automatically.
2. Open the unit's `.tres` in `content/` and drag the PNG into its **Sprite** field (Art group). Adjust **Sprite Scale** if it should stand taller or shorter.

Sprites are fitted into the unit's slot, keeping their aspect ratio. Work at about 2x the on-screen size, roughly 300×560 px for a normal unit and 680×560 px for a 2-rank one. Textures import with mipmaps so they stay smooth when scaled down.

## Test it

```bash
powershell -File scripts/test.ps1
```

Runs every `tests/test_*.gd` headless, including 200 simulated full runs that print win rates. Set `GODOT` to the Godot console executable if it isn't found automatically.

## Layout

| Path | What |
|---|---|
| `src/core/` | Combat rules: `battle.gd` (turns, hits, death, stress), `combatant.gd` (unit state), `tokens.gd` and `rules.gd` (DD2 numbers), `enemy_ai.gd`, `sandbox_run.gd` |
| `src/core/defs/` | Resource types for content: `UnitDef`, `SkillDef`, `EffectDef`, `EncounterDef`, `SandboxDef` |
| `src/ui/` | The combat screen and its placeholder drawing |
| `content/` | Heroes, enemies, waves and the sandbox as `.tres` files |
| `tests/` | Headless tests and the runner |
| `tools/capture.gd` | Runs the game and saves screenshots, for checking visuals |
