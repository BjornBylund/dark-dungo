# Darko Dungo

A Godot 4.7 prototype: Darkest Dungeon 2's turn-based combat inside a Darkest Dungeon 1 style town loop. Recruit a fixed cast of seven Darkest Dungeon 2 heroes (each with DD2's 11 skills, 5 taken into a fight), send four on missions across a map of fights, events and rests, and spend the gold and heirlooms on gear, skills, stress relief and buildings. Dungeons give DD2's trinkets, rarer ones less often and mostly in harder dungeons, and the Nomad Wagon trades them; each hero wears two. Heroes who go out together and help each other form bonds (Friendly, Respected, Partners) that make them stronger side by side. Each hero has a story told in dialogue scenes, a part when they join and a part at every level, each starting with a look back at the mission just played. A combat sandbox (four heroes against three waves) is still there for testing fights.

- Design decisions: [docs/design.md](docs/design.md)
- DD2 combat research: [docs/research/darkest-dungeon-combat.md](docs/research/darkest-dungeon-combat.md)
- DD2 hero kits the cast is built from: [docs/research/darkest-dungeon-2-heroes.md](docs/research/darkest-dungeon-2-heroes.md)
- DD2 trinkets: [docs/research/darkest-dungeon-2-trinkets.md](docs/research/darkest-dungeon-2-trinkets.md)

## Run it

Open the folder in Godot 4.7 and press Play, or from a terminal:

```bash
godot --path .
```

The title screen offers Continue, New Campaign and Combat Sandbox, and when running from the project folder the Balance Tool. The campaign autosaves after every town action and every fight of a mission.

- **Music and sound:** a track each for the town, the mission map, fights and boss fights, stings for a fight won or lost and a level gained, and sounds for blows, spells, tokens, stress, town trades and buttons. **Settings** on the title screen, or the gear on any other screen, sets the Master, Music and Effects volumes (kept between sessions) and fullscreen.
- **Dialogue scenes** play in town when a campaign starts, when a hero joins and when one levels up: click, tap, `Enter` or `Space` to go on, **Skip** or `Esc` to skip the scene.
- **Town:** click a building to open it (Blacksmith, Guild, Abbey, and from the first weeks the Nomad Wagon, Tavern and Heirloom Exchange), or a hero in the roster for their sheet: click a skill icon to equip or unequip it (hover it for what it does), and a worn trinket to take it off. Its **Talents** tab picks a talent at levels 2, 4, 6, 8 and 10 (click one, then **Choose**); a gold diamond on a hero's portrait means a talent is waiting. The Guild clears a hero's talents for gold. Each building window has a Services tab and an Upgrades tab. `Esc` closes a window. **Embark** (or the noticeboard by the gate) opens the expedition map.
- **Expedition map:** click a quest shield by a region to see its details. Click heroes in the roster to fill the lineup from rank 1, drag them between slots to reorder, and click a hero in a slot to take them out. **Embark** starts the mission; `Esc` goes back to town.
- **Mission map:** click a glowing room to go there; hover a room to see what it holds. Fights open the combat screen and come back; rests, caches and events open a panel over the map. **Retreat** (click twice) ends the mission with what you earned on the way.
- **Combat:** click a skill, then a highlighted target. No skill is chosen when a turn starts: click any unit (or right-click one at any time) for its details: HP, resistances, tokens and what they do, and its skills. Click the chosen skill again to let go of it. Keys: `1`–`8` skills, `Left`/`Right`/`Tab` change target, `Enter`/`Space` confirm, `Esc` close the details or let go of the skill, `L` combat log, `S` speed, `R` restart (sandbox only). Hover any unit for a quick look at its stats.

Launch options go after `--`:

| Option | Does |
|---|---|
| `--continue` | Load the save and skip the title screen |
| `--new-campaign` | Start a new campaign, replacing the save |
| `--sandbox` | Open the combat sandbox |
| `--balance` | Open the balance tool (not in exports) |
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

Each unit keeps all its images in one folder named after its class, `art/characters/<class>/`, e.g. `crusader/`, `man_at_arms/` or `gravelord/`:

| File | Shown |
|---|---|
| `sprite.png` | On the battlefield, and cropped for portraits |
| `hurt.png` | In an attack close-up while the unit is hit |
| `<skill id>.png` | In the close-up while the unit uses that skill, e.g. `smite.png` |

Units draw a coloured placeholder until they have a sprite.

1. Put a transparent `sprite.png` in the unit's folder, e.g. `art/characters/ghoul/sprite.png`. Draw every unit facing right with its feet on the bottom edge; enemies are mirrored automatically.
2. Open the unit's `.tres` in `content/` and drag the PNG into its **Sprite** field (Art group). Adjust **Sprite Scale** if it should stand taller or shorter.
3. Poses are found by their file names next to the sprite, with no field to set. A missing pose shows the normal sprite. `tools/make_poses.gd` writes placeholders for missing ones.

Sprites are fitted into the unit's slot, keeping their aspect ratio. Units stand about 380 px tall on a 1080p screen and up to 1.5× that in close-ups, so draw them at least 560 px tall (around 300×560 for a normal unit, 680×560 for a 2-rank one). Textures import with mipmaps so they stay smooth when scaled down.

Other art, all replaceable:

- **Skill icons:** each skill's **Icon** field (square, e.g. `art/skills/smite.svg`). Swap, Pass and Recover use `art/skills/swap.svg`, `pass.svg` and `recover.svg`.
- **Token and status icons:** `art/tokens/<token>.svg`, e.g. `block.svg` or `bleed.svg`. Replace a file to change its icon.
- **Battle backgrounds:** **Battle Background** in `content/campaign.tres` and **Background** in `content/sandbox.tres`, 1920×1080 with the ground line at y ≈ 680.
- **Town:** **Town Background** in `content/campaign.tres` (`art/backgrounds/hamlet.svg`). The clickable building areas are the `BUILDINGS` rectangles at the top of `src/ui/town_screen.gd`; move them if the buildings move.
- **Expedition map:** **Expedition Background** in `content/campaign.tres` (`art/backgrounds/expedition_map.svg`). Each region's quest markers sit at its **Map Position** in `content/regions/`, and its **Landmark** rectangle is greyed out while the region is closed; move both if the landmarks move.
- **Mission maps:** **Map Background** in `content/campaign.tres` (`art/backgrounds/trail.svg`); rooms are drawn over the band y 130–750. Room icons are `art/rooms/<fight|event|rest|elite|cache|finale>.svg`.
- **Heirlooms:** `art/heirlooms/<bust|portrait|deed|crest>.svg`.

## Add content

The **balance tool** edits heroes, enemies, encounters, trinkets and talents with their numbers on paper beside them, and the dialogue scripts: `godot --path . -- --balance`, or Balance Tool on the title screen.
- **Tables:** one per kind. Click a column title to sort. Green and red cells rank strong and weak within their group; hover one for its rank. A hero or enemy expands into its skills. The Talents table lists every class's talents with their level and effects.
- **Editing:** the form edits the selected row. Fields changed from their default are named in gold; hover a name for what it does. A hero's **Talents** list picks which talent files sit on its rows, three per row.
- **New content:** **Duplicate** makes a new one from a copy (not talents, which come three to a row). **List in campaign** decides where the game uses it.
- **Simulating:** pick a preset (Base, Apprentice, Veteran, Champion) and Quick (about 25 s) or Thorough (about a minute and a half), then **▶ Run**. It simulates what's on screen, saved or not.
  - **The sweep:** random parties of four with random loadouts fight every encounter. At presets with trinkets they wear random ones, and they take a random talent on each row their level opens.
  - **Paired fights:** every hero skill and trinket is measured with and without it, and every talent against another of its row.
  - **Result columns:** what the run found, beside the numbers on paper. Hover a cell for its margin of error.
  - **Flags:** amber marks an encounter that misses its target, or a hero, skill, trinket or talent that stands out.
  - **Out of date:** results grey out after an edit, and come back if you undo it.
  - **Pin:** keeps a run to compare later ones with, in the **vs pin** column.
  - **Targets:** opens the presets and targets (`content/balance_targets.tres`).
- **Dialogue tab:** each hero's script and the Ancestor's as text, with sections, conditions, speakers and placeholders coloured.
  - **Checks:** as you type, the list under the editor names each mistake and its line: a missing section, an unknown condition or placeholder, a speaker who can't be there. Click one to go to it. They're the checks `tests/test_dialogue.gd` runs.
  - **▶ Play** plays the variant the caret is in as the game shows it, with example names in the placeholders. **Go to** jumps to a section.
  - **Reference:** the right panel lists the sections the script needs, who may speak, and the conditions and placeholders.
  - **Saving:** edits undo with the rest, and Save writes the `.txt` file. Dialogue changes no fight, so run results stay current.
- **Arena tab:** one fight of your choosing, played 200 times again after every change.
  - **Setup:** pick four heroes in rank order, the skills they take (click to toggle, five at most), their trinkets and a talent per row (any row, whatever the preset's level), an encounter, a preset, and the party's starting HP and stress.
  - **Results:** the win rate, HP lost, deaths and rounds, each hero's HP lost and deaths, and how often each skill was used, with a comparison to before your last change.
  - **Edit** beside a hero or the encounter opens it in the form; changes there re-run the fight.
  - **▶ Watch** plays the fight in the real combat screen with the bot, and **Play it** lets you play it. R plays it again; Esc goes back (once any unit's details are closed and no skill is chosen).
- **Keys:** `Ctrl+S` saves the changed files, `Ctrl+Z` / `Ctrl+Y` undo and redo.

The files can also be edited by hand or in the Godot inspector:

- **Trinkets:** `content/trinkets/`, listed under **Trinkets** in `content/campaign.tres`. Each has a rarity, an optional class, a price, stats (fractions like 0.15 for +15%, speed in points, `max_hp` as a share of base HP), **Bonuses** (stats with a condition) and **Triggers** (effects fired by combat events, like Apply on Hit). An empty **Icon** draws a placeholder in the rarity's colour.
- **Dialogue:** plain-text scripts in `content/dialogue/`, one per hero (named by class, set in the hero's **Dialogue** field) and `ancestor.txt` for the opening and the homecoming lines (**Dialogue** in `content/campaign.tres`). A hero's script has `== join` (recruits), `== level 1` to `== level 10`, and `== reflect` with variants like `? boss`, `? with Vestal` or `? region chapel`. Each line reads `Speaker: text`. The format is explained at the top of `src/campaign/dialogue.gd`, and `tests/test_dialogue.gd` checks every script. The balance tool's **Dialogue** tab edits them with the same checks.
- **Sound and music** are made in code, not recorded: the recipes in `tools/audio/` (`sounds.gd` for the effects, `music.gd` for the tracks, `synth.gd` for the oscillators, filters, reverb and instruments they share) render to WAV files in `audio/` with `godot --headless --path . --script res://tools/make_audio.gd` (about 2 minutes; `-- --only=hit,town` renders just those). The same recipes always give the same files, and Godot imports them compressed. A new sound needs its recipe and its name in `Audio.SOUNDS` (`src/audio/audio.gd`); `tests/test_audio.gd` checks both, and that every sound the code names exists. A skill's **Sound** field picks its swing, shot or spell; From Ranks works it out.
- **Talents:** `content/talents/<class>/`, 15 per class, listed in order under **Talents** on the hero's `.tres`: three per row, the rows for levels 2, 4, 6, 8 and 10. Each has a name, a line of flavour, and the same **Stats**, **Bonuses** and **Triggers** as a trinket.
- **Heroes and enemies:** `.tres` files in `content/heroes/` and `content/enemies/`. A hero joins the campaign by being listed in `content/campaign.tres`, either in **Starting Heroes** or in **Recruits** (one joins, chosen by the player, for each region boss beaten for the first time).
- **Regions:** `content/regions/`, listed under **Regions** in `content/campaign.tres`. They open in that order: the first from the start, each next one when the boss before it is beaten for the first time. Each open region offers two missions a week (four while only the first is open).
- **Enemy groups:** `content/encounters/`. A mission map's fight rooms draw from its region's **Encounters**, elite rooms from its **Elites**, and the final room from its **Finales**, or its **Boss** on a boss mission.
- **Events:** `content/events/`, each with a title, flavour text and choices. Each choice has a chance, success and failure outcomes (HP, stress, gold, heirlooms, tokens, or a fight) and can need a class in the party. Shared events are listed under **Events** in `content/campaign.tres`, region events under the region's **Events**.
- **Campaign numbers** (rewards, prices, XP, upgrade costs, map size, room odds and bonds) are constants in `src/campaign/campaign_rules.gd`.
- **Balance checks:**
  - `powershell -File scripts/balance.ps1` plays whole missions with random parties on parallel Godot processes (about 5 seconds). It prints how often each length is finished, how far parties get, the fight shares a full clear earns, and finish rates by class. `-Tier 0|1|2` and `-Level N` pick the missions and the heroes' level, and `-Runs N` the sample size. Heroes spend their talent points at random; `-NoTalents` leaves them unspent, to see what talents add.
  - `godot --headless --path . --script res://tools/balance_probe.gd -- --preset=Base` runs the balance tool's sweep from the terminal. It prints every encounter against its targets, every hero against the cast's average, and the skills, trinkets and talents that stand out (`--all` for every one). `--thorough` plays 4 times as many fights.

## Test it

```bash
powershell -File scripts/test.ps1
```

Runs every `tests/test_*.gd` headless in about 6 seconds. It re-imports the project first only when a file changed since the last run. `-Only text` runs just the tests whose file or method name contains the text, for example `-Only mission_map`. Tests slower than half a second show their time. Win rates come from the balance checks above, not the tests. Set `GODOT` to the Godot console executable if it isn't found automatically.

## Layout

| Path | What |
|---|---|
| `src/core/` | Combat rules: `battle.gd` (turns, hits, death, stress), `combatant.gd` (unit state), `tokens.gd` and `rules.gd` (DD2 numbers), `enemy_ai.gd`, `auto_player.gd` (the hero bot: scores every skill and target by the HP it's worth), `sandbox_run.gd` |
| `src/core/defs/` | Resource types for content: `UnitDef`, `SkillDef`, `EffectDef`, `TrinketDef` (with `TrinketBonus` and `TrinketTrigger`), `EncounterDef`, `RegionDef`, `EventDef` (with `EventChoiceDef` and `EventOutcomeDef`), `SandboxDef`, `CampaignDef` |
| `src/campaign/` | The town loop, pure logic like the combat core: `campaign.gd` (estate, weeks, buildings, trinkets, saving), `trinkets.gd` (trinket drops), `mission.gd`, `mission_map.gd` and `map_room.gd` (building a map), `mission_run.gd` (walking it room by room), `bonds.gd` (bonds between heroes), `dialogue.gd` and `dialogue_scene.gd` (dialogue scenes from the scripts), `map_auto_player.gd`, `hero_record.gd`, `growth.gd` (levels and gear into combat stats), `campaign_rules.gd` (DD1 numbers) |
| `src/game.gd` | Autoload holding the running campaign and switching screens |
| `src/audio/audio.gd` | Autoload playing the music (crossfades, stings, dipping under dialogue) and the sound effects, and keeping the volumes |
| `src/balance/` | The balance tool: `balance_app.gd` (the screen), `balance_library.gd` (loading, undo, saving, duplicating, listing), `balance_stats.gd` (numbers on paper), `balance_sweep.gd` (simulated fights in worker processes), `balance_arena.gd` and `balance_arena_panel.gd` (the Arena), `balance_dialogue_panel.gd`, `dialogue_file.gd` and `dialogue_highlighter.gd` (the Dialogue tab), `balance_flags.gd` and `balance_result_columns.gd` (what a run found, flagged against `content/balance_targets.tres`), `resource_form.gd` (forms built from exported fields), `balance_table.gd` (sortable, ranked tables) |
| `src/ui/` | Title, town, expedition, mission map and combat screens; `settings_window.gd` (volumes and fullscreen), `combat_sounds.gd` (a sound per battle event); `device.gd` and the `mobile.gd` autoload handle phones, tablets and touch |
| `content/` | Heroes, enemies, encounters, regions, events, trinkets, the campaign and the sandbox as `.tres` files, and the dialogue scripts in `content/dialogue/` |
| `audio/` | The rendered sound effects (`sfx/`) and music (`music/`), made by `tools/make_audio.gd` |
| `art/` | One folder per unit under `art/characters/` (sprite and close-up poses), skill and token icons, UI frames, backgrounds, heirlooms, and the fonts (Gelasio and Grenze Gotisch, SIL Open Font License) |
| `export_presets.cfg` | The Web export preset |
| `.github/workflows/pages.yml` | Test, export and deploy to GitHub Pages |
| `scripts/` | `test.ps1` runs the tests, `balance.ps1` plays missions in parallel for balance numbers, `serve_web.ps1` serves the web export locally |
| `tests/` | Headless tests and the runner |
| `tools/capture.gd` | Runs the game and saves screenshots, for checking visuals |
| `tools/make_audio.gd`, `tools/audio/` | Renders the sound effects and music from their recipes |
| `tools/balance_probe.gd` | The balance tool's sweep from the terminal |
| `tools/balance_worker.gd` | One worker process of a sweep |
| `tools/mission_probe.gd` | Random parties play whole missions; `scripts/balance.ps1` runs it in parallel |
| `tools/make_poses.gd` | Writes placeholder attack and hurt poses into each unit's `art/characters/` folder (keeps existing files unless `--overwrite`) |
