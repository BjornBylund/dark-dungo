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

Watch it play itself: `godot --path . -- --autoplay --speed=2`. Add `--start-wave=3` to jump straight to a wave.

## Play in a browser

The project exports to the web (HTML5) without threads, so any static host works without special headers.

1. Install export templates once: in the Godot editor, Editor > Manage Export Templates > Download and Install.
2. Export with Project > Export > Web > Export Project, or from a terminal:

   ```bash
   godot --headless --path . --export-release "Web" build/web/index.html
   ```

3. Test it locally (browsers can't run it from `file://`), then open http://localhost:8060:

   ```bash
   powershell -File scripts/serve_web.ps1
   ```

### Publish on GitHub Pages

`.github/workflows/pages.yml` runs the tests, exports the game and deploys it on every push to `main`.

1. Create a GitHub repository and push this one to it. Pages on a free GitHub plan needs a public repository.
2. In the repository, open Settings > Pages and set **Source** to **GitHub Actions**.
3. Push to `main` (or run the workflow from the Actions tab). The game appears at `https://<user>.github.io/<repo>/`.

## Add art

Units draw a coloured placeholder until they have a sprite.

1. Put a transparent PNG in the project, e.g. `art/units/ghoul.png`. Draw every unit facing right with its feet on the bottom edge; enemies are mirrored automatically.
2. Open the unit's `.tres` in `content/` and drag the PNG into its **Sprite** field (Art group). Adjust **Sprite Scale** if it should stand taller or shorter.

Sprites are fitted into the unit's slot, keeping their aspect ratio. Units stand about 380 px tall on a 1080p screen and up to 1.5× that in close-ups, so draw them at least 560 px tall (around 300×560 for a normal unit, 680×560 for a 2-rank one). Textures import with mipmaps so they stay smooth when scaled down.

Other art, all replaceable:

- **Skill icons:** each skill's **Icon** field (square, e.g. `art/skills/slice.svg`). Swap, Pass and Recover use `art/skills/swap.svg`, `pass.svg` and `recover.svg`.
- **Token and status icons:** `art/tokens/<token>.svg`, e.g. `block.svg` or `bleed.svg`. Replace a file to change its icon.
- **Background:** the sandbox's **Background** field (`content/sandbox.tres`), 1920×1080 with the ground line at y ≈ 680.

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
| `art/` | Unit sprites and the UI font (Gelasio, SIL Open Font License) |
| `export_presets.cfg` | The Web export preset |
| `.github/workflows/pages.yml` | Test, export and deploy to GitHub Pages |
| `scripts/` | `test.ps1` runs the tests, `serve_web.ps1` serves the web export locally |
| `tests/` | Headless tests and the runner |
| `tools/capture.gd` | Runs the game and saves screenshots, for checking visuals |
