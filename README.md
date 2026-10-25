# Darko Dungo

A Godot 4.7 prototype: Darkest Dungeon 2's turn-based combat inside a Darkest Dungeon 1 style town loop. Recruit a fixed cast of eight heroes, send four on missions of a few fights, and spend the gold and heirlooms on gear, skills, stress relief and buildings. A combat sandbox (four heroes against three waves) is still there for testing fights.

- Design decisions: [docs/design.md](docs/design.md)
- DD2 combat research: [docs/research/darkest-dungeon-combat.md](docs/research/darkest-dungeon-combat.md)

## Run it

Open the folder in Godot 4.7 and press Play, or from a terminal:

```bash
godot --path .
```

The title screen offers Continue, New Campaign and Combat Sandbox. The campaign autosaves after every town action and every room of a mission.

- **Town:** click a building to open it (Stagecoach, Blacksmith, Guild, Abbey), or a hero in the roster for their sheet. `Esc` closes a window. **Embark** (or the noticeboard by the gate) opens the expedition map.
- **Expedition map:** click a quest shield by a region to see its details. Click heroes in the roster to fill the lineup from rank 1, drag them between slots to reorder, and click a hero in a slot to take them out. **Embark** starts the mission; `Esc` goes back to town.
- **Mission map:** click a glowing room to go there; hover a room to see what it holds. Fights open the combat screen and come back; rests, caches and events open a panel over the map. **Retreat** (click twice) ends the mission with what you earned on the way.
- **Combat:** click a skill, then a highlighted target. Keys: `1`–`8` skills, `Left`/`Right`/`Tab` change target, `Enter`/`Space` confirm, `L` combat log, `S` speed, `R` restart (sandbox only). Hover any unit for its stats.

Launch options go after `--`:

| Option | Does |
|---|---|
| `--continue` | Load the save and skip the title screen |
| `--new-campaign` | Start a new campaign, replacing the save |
| `--sandbox` | Open the combat sandbox |
| `--autoplay` | Play itself: the town hires, treats the wounded and embarks; the map picks rooms, rests and event choices; fights pick sensible moves |
| `--speed=N` | Combat animation speed |
| `--start-wave=N` | Sandbox: start at wave N |
| `--phone` | Phone layout and touch behaviour, for testing on desktop (pair with `--resolution 844x390`) |
| `--touch` | Touch behaviour with the normal layout, like a tablet |

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

### On phones and tablets

The web build plays in mobile browsers, held sideways.
- **Phones** get a larger layout.
- **Touch controls:**
  - Tap a map room to see what it holds, then Go.
  - Tap an enemy to see the attack's odds, and tap it again (or Confirm) to attack.
  - Long-press anything for its details.
- **Installing:** the build is installable. Use "Add to Home Screen" and it opens fullscreen in landscape. The title screen also has a Fullscreen button.

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
- **Expedition map:** **Expedition Background** in `content/campaign.tres` (`art/backgrounds/expedition_map.svg`). Each region's quest markers sit at its **Map Position** in `content/regions/`; move them if the landmarks move.
- **Mission maps:** **Map Background** in `content/campaign.tres` (`art/backgrounds/trail.svg`); rooms are drawn over the band y 130–750. Room icons are `art/rooms/<fight|event|rest|elite|cache|finale>.svg`.
- **Heirlooms:** `art/heirlooms/<bust|portrait|deed|crest>.svg`.

## Add content

- **Heroes and enemies:** `.tres` files in `content/heroes/` and `content/enemies/`. A hero joins the campaign by being listed in `content/campaign.tres`, either in **Starting Heroes** or in **Arrivals** (one arrives per week, in order).
- **Regions:** `content/regions/`, listed under **Regions** in `content/campaign.tres`. Each region offers two missions a week.
- **Enemy groups:** `content/encounters/`. A mission map's fight rooms draw from its region's **Encounters**, elite rooms from its **Elites**, and the final room from its **Finales**.
- **Events:** `content/events/`, each with a title, flavour text and choices. Each choice has a chance, success and failure outcomes (HP, stress, gold, heirlooms, tokens, or a fight) and can need a class in the party. Shared events are listed under **Events** in `content/campaign.tres`, region events under the region's **Events**.
- **Campaign numbers** (rewards, prices, XP, upgrade costs, map size and room odds) are constants in `src/campaign/campaign_rules.gd`.
- **Balance check:** `godot --headless --path . --script res://tools/balance_probe.gd` prints how fresh random parties fare against every enemy group.

## Test it

```bash
powershell -File scripts/test.ps1
```

Runs every `tests/test_*.gd` headless, including simulated sandbox runs and campaign missions that print win rates. Set `GODOT` to the Godot console executable if it isn't found automatically.

## Layout

| Path | What |
|---|---|
| `src/core/` | Combat rules: `battle.gd` (turns, hits, death, stress), `combatant.gd` (unit state), `tokens.gd` and `rules.gd` (DD2 numbers), `enemy_ai.gd`, `sandbox_run.gd` |
| `src/core/defs/` | Resource types for content: `UnitDef`, `SkillDef`, `EffectDef`, `EncounterDef`, `RegionDef`, `EventDef` (with `EventChoiceDef` and `EventOutcomeDef`), `SandboxDef`, `CampaignDef` |
| `src/campaign/` | The town loop, pure logic like the combat core: `campaign.gd` (estate, weeks, buildings, saving), `mission.gd`, `mission_map.gd` and `map_room.gd` (building a map), `mission_run.gd` (walking it room by room), `map_auto_player.gd`, `hero_record.gd`, `growth.gd` (levels and gear into combat stats), `campaign_rules.gd` (DD1 numbers) |
| `src/game.gd` | Autoload holding the running campaign and switching screens |
| `src/ui/` | Title, town, expedition, mission map and combat screens; `device.gd` and the `mobile.gd` autoload handle phones, tablets and touch |
| `content/` | Heroes, enemies, encounters, regions, events, the campaign and the sandbox as `.tres` files |
| `art/` | Unit sprites, skill and token icons, backgrounds, heirlooms, and the fonts (Gelasio and Grenze Gotisch, SIL Open Font License) |
| `export_presets.cfg` | The Web export preset |
| `.github/workflows/pages.yml` | Test, export and deploy to GitHub Pages |
| `scripts/` | `test.ps1` runs the tests, `serve_web.ps1` serves the web export locally |
| `tests/` | Headless tests and the runner |
| `tools/capture.gd` | Runs the game and saves screenshots, for checking visuals |
| `tools/balance_probe.gd` | Fresh random parties against every enemy group: win rate, HP lost, stress |
