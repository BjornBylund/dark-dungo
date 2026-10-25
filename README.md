# Darko Dungo

A Godot 4.7 prototype: Darkest Dungeon 2's turn-based combat inside a Darkest Dungeon 1 style town loop. Recruit a fixed cast of eight heroes, send four on missions of a few fights, and spend the gold and heirlooms on gear, skills, stress relief and buildings. A combat sandbox (four heroes against three waves) is still there for testing fights.

- Design decisions: [docs/design.md](docs/design.md)
- DD2 combat research: [docs/research/darkest-dungeon-combat.md](docs/research/darkest-dungeon-combat.md)

## Run it

Open the folder in Godot 4.7 and press Play, or from a terminal:

```bash
godot --path .
```

The title screen offers Continue, New Campaign and Combat Sandbox. The campaign autosaves after every town action and every fight.

- **Town:** click a building to open it (Stagecoach, Blacksmith, Guild, Abbey, Mission Board), or a hero in the roster for their sheet. `Esc` closes a window.
- **Combat:** click a skill, then a highlighted target. Keys: `1`–`8` skills, `Left`/`Right`/`Tab` change target, `Enter`/`Space` confirm, `L` combat log, `S` speed, `R` restart (sandbox only). Hover any unit for its stats.

Launch options go after `--`:

| Option | Does |
|---|---|
| `--continue` | Load the save and skip the title screen |
| `--new-campaign` | Start a new campaign, replacing the save |
| `--sandbox` | Open the combat sandbox |
| `--autoplay` | Play itself: the town hires, treats the wounded and embarks; fights pick sensible moves |
| `--speed=N` | Combat animation speed |
| `--start-wave=N` | Sandbox: start at wave N |

For example, watch a campaign play itself: `godot --path . -- --new-campaign --autoplay --speed=4`.

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
- **Battle backgrounds:** **Battle Background** in `content/campaign.tres` and **Background** in `content/sandbox.tres`, 1920×1080 with the ground line at y ≈ 680.
- **Town:** **Town Background** in `content/campaign.tres` (`art/backgrounds/hamlet.svg`). The clickable building areas are the `BUILDINGS` rectangles at the top of `src/ui/town_screen.gd`; move them if the buildings move.
- **Heirlooms:** `art/heirlooms/<bust|portrait|deed|crest>.svg`.

## Add content

- **Heroes and enemies:** `.tres` files in `content/heroes/` and `content/enemies/`. A hero joins the campaign by being listed in `content/campaign.tres`, either in **Starting Heroes** or in **Arrivals** (one arrives per week, in order).
- **Enemy groups:** `content/encounters/`. Missions draw their fights from the campaign's **Encounters**; medium and long missions end with one of its **Finales**.
- **Campaign numbers** (rewards, prices, XP, upgrade costs) are constants in `src/campaign/campaign_rules.gd`.

## Test it

```bash
powershell -File scripts/test.ps1
```

Runs every `tests/test_*.gd` headless, including simulated sandbox runs and campaign missions that print win rates. Set `GODOT` to the Godot console executable if it isn't found automatically.

## Layout

| Path | What |
|---|---|
| `src/core/` | Combat rules: `battle.gd` (turns, hits, death, stress), `combatant.gd` (unit state), `tokens.gd` and `rules.gd` (DD2 numbers), `enemy_ai.gd`, `sandbox_run.gd` |
| `src/core/defs/` | Resource types for content: `UnitDef`, `SkillDef`, `EffectDef`, `EncounterDef`, `SandboxDef`, `CampaignDef` |
| `src/campaign/` | The town loop, pure logic like the combat core: `campaign.gd` (estate, weeks, buildings, saving), `mission.gd` and `mission_run.gd` (a chain of fights), `hero_record.gd`, `growth.gd` (levels and gear into combat stats), `campaign_rules.gd` (DD1 numbers) |
| `src/game.gd` | Autoload holding the running campaign and switching screens |
| `src/ui/` | Title, town and combat screens |
| `content/` | Heroes, enemies, encounters, the campaign and the sandbox as `.tres` files |
| `art/` | Unit sprites, skill and token icons, backgrounds, heirlooms, and the fonts (Gelasio and Grenze Gotisch, SIL Open Font License) |
| `export_presets.cfg` | The Web export preset |
| `.github/workflows/pages.yml` | Test, export and deploy to GitHub Pages |
| `scripts/` | `test.ps1` runs the tests, `serve_web.ps1` serves the web export locally |
| `tests/` | Headless tests and the runner |
| `tools/capture.gd` | Runs the game and saves screenshots, for checking visuals |
