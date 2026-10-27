# Darko Dungo — Design

Living record of agreed decisions. Anything not written here is either "do what Darkest Dungeon 2 does" or still open (see the end).

## Platform & tooling

- Godot 4.7.2, standard (non-.NET) build, statically typed GDScript.
- Git repository. Tests run headless through a small hand-rolled runner (`godot --headless --script ...`); no test add-on.

## Scope

- **v1: the campaign.** A DD1-style town loop around the combat: recruit a fixed cast, pick a party of 4, run missions of a few fights, and spend gold and heirlooms on the heroes and buildings. Details under [Campaign](#campaign).
- **The combat sandbox** (a fixed party against 3 waves) stays as a test mode, started with `-- --sandbox`.
- Out of scope for v1: dungeon map, quirks, diseases, trinkets, supplies, relationships, skill loadouts, Paths. See [Open / deferred](#open--deferred).

## Architecture

- **Combat core** (`src/core/`) is pure logic: plain GDScript classes (no nodes), a seeded RNG so any fight replays exactly from its seed, and an event stream ("X used Y on Z, crit, 7 damage, Bleed applied") as its only output.
- **Presentation** (`src/ui/`) renders those events and sends the player's choices back to the core. It never decides outcomes.
- **Content** (`content/`) — heroes, enemies, skills, waves — is data, stored as Godot Resources (`.tres`), not code. Edit them in the Godot inspector.
- Combat takes a party in and hands it back out (HP, stress, Death's Door, deaths, long-lasting buffs), so it plugs into whichever game loop is chosen later.

## Combat model

- **Mirror Darkest Dungeon 2.** Where DD2 has a rule, copy it number for number. Reference: [research/darkest-dungeon-combat.md](research/darkest-dungeon-combat.md). All DD2 numbers live in `src/core/rules.gd` and `src/core/tokens.gd`.
- **Stress** 0–10 with Meltdown (80%) or Resolute (20%) at 10. In a fight it happens on the spot; on a mission map, as soon as an event pushes a hero to 10 or when a hero sets out at 10 (the map opens with a "Setting out" panel). Round-based buffs from one outside a fight count down in the next fight.
- **Death's Door**: heroes at 0 HP are on Death's Door; further damage rolls deathblow resistance (60% base, −10% per survived check, clamped 33–90%). A failed roll **defeats** the hero rather than killing them (see [Campaign](#campaign)). Enemies die at 0 HP unless they have Death Armor.
- **Hero kit**: each class has DD1's 7 skills and a hero takes 4 into a fight (see [Skill loadouts](#hero-growth)), plus Swap and Pass. Recover (DD2's `pass_heal`) appears below 25% HP. Cooldowns and per-battle limits apply.
- **Enemy AI**: a forced skill if one is usable, otherwise a pick among usable skills by `ai_weight` (all 1 by default, which is DD2's uniform pick), then a target that respects Taunt and Stealth and avoids corpses when possible.

### Where DD2 is unknown, we chose

The research could not confirm these, so the engine does the following:

- **Turn order**: round speed = SPD + integer 0–6; ties broken randomly.
- **Rounding**: final damage rounds half away from zero, minimum 1 on a damaging hit.
- **Token timers**: one shared 3-turn timer per token type, started by the first stack and not refreshed by later stacks.
- **Guard** does not redirect multi-target attacks.
- **Vulnerable** can be resisted (Debuff resistance), as in DD2's 2024 data.
- **Taunt**: a single-target attack aimed at a taunting unit spends one Taunt stack.
- **Blind** is rolled once per skill use, even for multi-target attacks.
- **Riposte** triggers when a riposte-able damaging attack hits (not when it is dodged); only the frontmost riposter answers; the counter ignores rank restrictions.
- **Daze** is checked before damage-over-time ticks, so a delayed turn ticks only once.
- **Corpses** (heroes and enemies) hold their rank for 3 rounds. Attacks can target them; heals, tokens and DoTs cannot.
- **After a win** heroes are healed up to 20% HP (DD2's `m_BattleEndMinHealthHealUpToPercent`), which also lifts them off Death's Door. Tokens, DoTs, cooldowns and per-battle buffs clear.
- **Self- and ally-applied effects** are never resisted.
- An enemy with no usable skill steps one rank towards a rank its skills launch from, otherwise waits.

## Campaign

DD1's town loop ([research/darkest-dungeon-town.md](research/darkest-dungeon-town.md)) with DD1's numbers, stress divided by 10 for our 0–10 scale. Rules and prices live in code constants next to the combat ones; content stays in `.tres`.

### Roster: a fixed cast, no permadeath

- **One unique hero per class.** The cast is 8 of DD1's classes (see [Heroes](#heroes)); you start with 5 at level 0: the Crusader, Grave Robber, Arbalest, Vestal and Man-at-Arms.
- **Recruiting through bosses:** there is no Stagecoach. Beating a region's boss for the first time lets one hero join: you choose from those who haven't, and they join at level 1. Three regions, three heroes left (Plague Doctor, Jester, Flagellant). See [Region bosses](#region-bosses).
- **No permadeath.** A failed deathblow **defeats** the hero: they leave the fight and take no further part in the mission. Back in town they are **Wounded** and sit out the next week, unless you pay to treat them at once. They keep their levels, gear and skills.
- **Between missions** heroes return at full HP. Stress carries over until relieved at the Abbey. Idle heroes lose 1 stress per week.

### Weeks and missions

- **One mission is one week.** The week advances when the party returns, whether it won, retreated or wiped. Then: Abbey and Tavern visits and wound treatments finish, idle heroes lose stress, and the mission board refreshes.
- **Regions**, like DD1's Ruins, Weald, Warrens and Cove: three placeholder places, each with its own enemy groups and finale. **The Graveyard** has skeletons and cultists, **the Burrows** ghouls and spitters, and **the Chapel** cultists and the Brute (`content/regions/`).
- **Regions open one at a time,** in that order. Only the Graveyard is open at the start; beating a region's boss for the first time opens the next one, and the mission results say so. On the expedition map a closed region shows dimmed, with the boss that opens it ("Opens when The Gravelord falls").
- **Missions:** 2 per open region each week, or 4 while only the first is open, so 4 to 6 to choose from. Each has a **tier** (Apprentice level 1, Veteran level 3, Champion level 5) and a **length** (short, medium, long). At least one is at the highest unlocked tier and, once Veteran is unlocked, at least one is still Apprentice. Veteran missions appear once a hero reaches level 2, Champion once a hero reaches level 4.
- **A mission is a map** of rooms to pick a route through, like a Slay the Spire act or DD2's roads, longer for longer missions. Its goal is to reach the end and win the region's finale, or its boss on a boss mission. See [Mission maps](#mission-maps). DD1's other quest goals (Explore, Gather, Activate) stay deferred.
- **Party selection:** up to 4 heroes, rank 1 first in the order picked. Heroes who are Wounded or busy at the Abbey can't go. Heroes at least 2 levels above the mission level refuse it ("will not go"). Heroes more than one level below it start the mission with +2 stress per level short: level 0 is fine for Apprentice, level 2 for Veteran, level 4 for Champion.
- **Nobody fit to go:** when every hero is Wounded or busy in town and no recruit is waiting to join, the board offers **Wait out the week**, which ends the week without a mission. It keeps a wiped party that can't afford treatment from locking the campaign; DD1 never needs it because its Stagecoach always has recruits.

### Region bosses

After DD1's region progress and bosses:

- **Unlocking:** every mission **completed** in a region fills its **boss progress**, by its length: short 25%, medium 35%, long 50% (so 4, 3 or 2 missions); retreats and wipes don't count. When it's full, the region's **boss mission** appears on the board, by its region, as a skull shield on a blood-red field. It stays there, week after week, until beaten.
- **Where it shows:** on the expedition map, a bar under each open region's name fills blood-red towards a skull, with the chosen quest's share shown ahead of it in pale gold; it becomes "Boss awaits", then "Conquered". The quest details list the share ("+35% boss progress"), and the mission results the new total.
- **A boss mission** is a **long** map (20 columns) that ends at the region's boss instead of its finale. It pays a long mission's gold and XP and **double** heirlooms.
- **The first win** against each region's boss lets a new hero join (see Recruiting), and opens the next region. A window in town offers the choice of hero.
- **Coming back harder:** after a win the region's progress starts again from empty, and when it's full again its boss returns a tier harder: Apprentice, then Veteran, then Champion. Later wins pay but bring no recruit. After the Champion boss the region is **conquered**.
- **The bosses**, each with escorts, built from mechanics the engine already has and tuned with `tools/balance_probe.gd` so fresh level-0 random parties win about 40–46% at Apprentice:

| Region | Boss | Kit |
|---|---|---|
| Graveyard | **The Gravelord** (2 ranks), with a Bone Spearman and a Cultist | Bone Storm on every rank, Grasp of the Grave (heavy, Weak), Raise the Dead (Strength for all), Death Knell (stress to all) |
| Burrows | **The Maw** (2 ranks), with two Spitters | Gorge (heavy, Bleed), Swallow (Stun), Retch (Blight on the back ranks), Ravenous Howl (stress to all) |
| Chapel | **The Hollow Saint** (rank 3, acts twice), between the Brute and a Cultist | Sermon of Despair (+2 stress to all), Smite (heavy, Vulnerable), Wailing Choir (every rank), Hallowed Ward (Block for all), Saint's Mercy (heals) |
- **Enemy tiers:** Veteran enemies have +25% HP and damage; Champion enemies +50% HP and damage and +5% crit.

### Rewards

| | Short | Medium | Long |
|---|---|---|---|
| Gold (Apprentice; Veteran ×1.5, Champion ×2) | 3,000 | 4,500 | 7,500 |
| XP (Apprentice; Veteran ×2, Champion ×4) | 2 | 3 | 4 |
| Bust or Portrait (Apprentice / Veteran / Champion) | 2 / 2 / 3 | 2 / 3 / 5 | 4 / 6 / 9 |
| Deed or Crest (Apprentice / Veteran / Champion) | 3 / 4 / 6 | 5 / 6 / 9 | 9 / 12 / 18 |

- **Gold:** half is paid on completion. The other half sets the **fight share**, half the gold divided by 6 / 9 / 12 for short / medium / long, which every fight won pays. Those are about the shares a full clear earns from fights, elites, caches and events, so a route with more fights pays more.
- **Heirlooms:** each mission shows one heirloom type, paid on completion in the amount above. Elites and caches pay extra on the way (see [Mission maps](#mission-maps)).
- **XP** only for completing the mission.
- **Retreat:** keep everything earned on the way (fight gold, elite and cache loot); no completion gold, heirlooms or XP; +2 stress per hero.
- **Party wipe:** the mission fails. No rewards at all, not even what was earned on the way, and every hero is Wounded.
- **Starting resources:** 5,000 gold, no heirlooms.

### Mission maps

A map is rooms in columns, played left to right, like a Slay the Spire act ([research/path-maps.md](research/path-maps.md)). From each room you choose one of the rooms it leads to in the next column. Every route ends at the same final room, the finale.

- **Size:** 5 rows, and 10 / 15 / 20 columns for short / medium / long, counting the finale. Medium is about a Slay the Spire act (15 floors and the boss). A route holds roughly 4 / 6 / 8 fights plus the finale.
- **Building a map:** 4 random walks from the first column to the final room, starting in different rows. Each step moves to the same row or the next one up or down, and walks never cross. Rooms no walk reaches are removed, so most rooms offer 2–3 ways on.
- **Hidden rooms:** the layout (rooms and paths) shows from the start, but a room's type shows only once it's one of the party's next choices: the first column, then the exits of each room entered. Rooms seen that way stay revealed. The final room always shows its finale or boss. Ways to see further ahead are [scouting](#scouting), a future feature.
- **Validation:** a map is redrawn until it passes the elite rules below and these layout rules:
  - Every column before the final room has at least two rooms, so routes never narrow to a single room before the end.
  - Every room leads on.
  - Every room can be reached from the first column.
- **Room types:**

| Room | Share | What happens |
|---|---|---|
| **Fight** | 50% | One of the region's enemy groups. Pays the fight share. |
| **Event** | 22% | A scene with flavour text and choices (below). |
| **Rest** | 12% | The whole party either heals 30% of max HP (which lifts heroes off Death's Door) or loses 2 stress each. |
| **Elite** | 8% | The region's miniboss and two of its regular enemies. Pays twice the fight share plus 2 / 3 / 4 heirlooms of the mission's type (Apprentice / Veteran / Champion). |
| **Cache** | 8% | Free loot, shown on the map before you choose: the fight share in gold, or 2 / 3 / 4 heirlooms of a random type. |
| **Finale** | final room | The region's finale group. |

- **Placement rules**, after Slay the Spire's:
  - The first column is all fights.
  - One column a little past the middle is all caches, like Slay the Spire's treasure floor: the 6th / 9th / 12th for short / medium / long.
  - The column just before the finale is all rests.
  - No elite or rest in the first 4 / 5 / 7 columns, and no rest in the column before the rests.
  - No elite after an elite or rest after a rest on any route.
  - A room's exits lead to rooms of different types, except into the all-cache and all-rest columns.
  - Every map has at least one elite. If none was rolled, an open room becomes one (a fight room when possible) where the rules allow it.
  - Every map has a route to the finale that avoids all elites, so an elite is always a choice.
- **Between rooms** the map screen shows where the party is, the rooms it can reach next, each hero's HP and stress, and the gold earned so far. **Retreat** is offered there, before picking the next room. HP, stress, Death's Door and defeated heroes carry from room to room; the DD2 end-of-battle heal (up to 20% HP) still applies after fights.
- **Attrition is meant to be harsh**, as in Slay the Spire: beyond the small end-of-battle heal, only rests, events and heal skills restore HP within a map. Higher tiers are meant to need levels and gear.
- **Saving:** in town and after each fight, with the map and the party's place on it, so Continue resumes on the map after the last fight. Other rooms (rests, events, caches) aren't saved on their own: quitting loses what happened since the last fight, or the whole mission before its first fight, as if the party never left. The map's Quit asks first.

#### Events

- **10 to start:** 4 that can appear in any region and 2 for each region. An event doesn't repeat within one map. They are content files (`content/events/`), editable in the inspector.
- **Text:** a title, descriptive flavour text setting the scene, and choice buttons that state what they do.
- **Choices** are certain ("Drink: the party heals 20% HP") or a stated chance ("Search the coffin: 60% 900 gold, otherwise a fight"). Some need a class in the party; for example, only the Vestal can tend the wounded stranger.
- **Outcomes:** HP or stress change for the party or one hero; gold or heirlooms gained or lost; tokens that carry into the next fight (Block, Strength, Dodge, Vulnerable and so on); or a fight, normal or the region's elite. Fights from events count as normal or elite fights in every way, including pay and wipes.

#### Minibosses

One per region, fought in elite rooms with two regular enemies of the region, using mechanics the combat engine already has:

| Region | Miniboss | Kit |
|---|---|---|
| Graveyard | **Bone Captain** | Acts twice a round. Guards its escorts, gives them Block, rallies them with Strength, sweeps the front two ranks |
| Burrows | **Broodmother** (2 ranks) | Blight sprays at the back ranks, a bleeding bite across the front two, a stress shriek |
| Chapel | **High Priest** (ranks 2–4) | Party-wide stress, Vulnerable and Weaken curses, a sweeping scourge, heals its followers |

Tuned with `tools/balance_probe.gd` so that a fresh level-0 party loses about 50–60% of its HP to an elite, against about 30% to a normal fight and 45% to a finale.

### Hero growth

- **Levels 1–6** at 2 / 8 / 14 / 24 / 36 / 48 total XP. Each level gives +10% to stun, bleed, blight, burn, move and debuff resistance, and raises the gear and skill caps.
- **Blacksmith:** weapon and armour ranks 2–5 for 750 / 1,750 / 3,000 / 6,000 gold, needing hero level 1 / 2 / 3 / 5 and the matching Blacksmith upgrade.
  - Each weapon rank above 1: +10% damage, +1% crit, and +1 speed at ranks 3 and 5.
  - Each armour rank above 1: +20% of base HP.
- **Guild:** skill ranks 2–5 for 250 / 750 / 1,250 / 2,500 gold, same level gates, needing the matching Guild upgrade. Each rank above 1: +10% damage or healing, +1% crit, +10% resistance pierce on its effects.
- **Skill loadouts**, DD1's: each class has more skills than a hero takes into a fight. A hero takes **4**, chosen from the skills they've learned. Every hero knows their class's first 4 skills from the start, and learns the others at the Guild for 500 gold each (×1.4 at levels 3–4, ×1.8 at 5–6); a new skill is equipped straight away while a slot is free. Only learned skills can be trained. The 4 are chosen in town (the hero's sheet or the Guild) or on the mission map between rooms (the Skills button), and apply from the next fight.

### Bonds

After DD2's relationships, but long-term and only positive: every pair of heroes has bond points that only go up and last the whole campaign.

- **Earning points:**
  - Every pair in the party gains +2 for completing a mission together, or +1 for any other ending.
  - When a hero's skill reaches another hero (a heal, a good token, stress relief, a guard), the pair has a 50% chance of +1, at most once per pair per fight.
- **Levels:** Strangers (0) → Friendly (5) → Respected (12) → Partners (20, the maximum).
- **Level bonuses**, for both partners while they stand in the same party. Each level keeps the ones below, and each pair counts separately:
  - Friendly: +10% stress resist.
  - Respected: also +5% crit.
  - Partners: also +15% chance of Resolute instead of Meltdown at max stress (20% → 35%), on the map as well as in fights.
- **Level-up boost:** reaching a new level gives both heroes −2 stress and +10% damage for the rest of the mission. Levels from helping are checked when each fight ends, and the fight-won panel announces them. A level reached as a mission ends (its points, or the last fight) holds the boost for the pair's next mission together, announced as they set out.
- **Where it shows:** each hero's sheet in town lists their bonds with level and progress, the expedition lineup lists the bonds within the chosen party, the fight stat sheet shows a hero's bond bonuses and boost, and the fight-won panel and mission results announce new levels.
- **Not yet:** losing points, negative relationships, and DD2's relationship act-outs.

### Buildings

Each building has DD1's separate **upgrade lines**, bought with heirlooms in its window's Upgrades tab, so you choose where to spend. Costs are DD1's.

| Building | Opens | Services (gold) | Upgrade lines (heirlooms per level) |
|---|---|---|---|
| **Blacksmith** | week 1 | Weapon and armour ranks | Weaponsmithing and Armorsmithing: max rank 2 / 3 / 4 / 5 (8 Deeds + 8 Crests, 20 + 21, 32 + 35, 44 + 49). Furnace: −10% gear gold per level, 5 levels (4 + 4, 9 + 10, 14 + 15, 18 + 20, 24 + 26) |
| **Guild** | week 1 | Skill ranks | Instructors: max rank 2 / 3 / 4 / 5 (6 Portraits + 14 Crests, 15 + 38, 24 + 60, 33 + 84). Training regimen: −10% skill gold per level, 5 levels (2 + 6, 5 + 14, 8 + 21, 11 + 29, 14 + 36) |
| **Abbey** | week 1 | Safe stress relief: Meditation, Prayer, Flagellation. Wound treatment | One line per activity (below), Busts + Crests |
| **Tavern** | week 3 | Risky stress relief: Bar, Gambling Hall, Bathhouse | One line per activity (below), Portraits + Crests |
| **Heirloom Exchange** | week 5 | Trades heirlooms at a loss | none |

- **Stress relief activities:** the hero pays now, misses this week's mission, and the stress comes off when the week ends. Prices ×1.4 for heroes of level 3–4 and ×1.8 for level 5–6.

| Activity | Stress off | Gold | Slots |
|---|---|---|---|
| Meditation, Bar | 4 | 1,000 | 1 (Bar: 2) |
| Prayer, Gambling Hall | 5 | 1,250 | 1 |
| Flagellation, Bathhouse | 6 | 1,500 | 1 |

- **Activity upgrade lines**, one per activity, DD1's: (1) more relief, (2) prices −15%, (3) one more slot, (4) more relief, (5) prices −15% more, (6) one more slot. Relief goes 4 → 6 → 7, 5 → 7 → 9, 6 → 8 → 10. Abbey levels cost 4 Busts + 5 Crests up to 23 + 29; Tavern levels 2 Portraits + 5 Crests up to 11 + 29.
- **The Abbey is safe**; the **Tavern** has side effects, about 1 visit in 4, DD1's without quirks, trinkets or diseases. Gold can't drop below 0.

| Activity | Good | Bad |
|---|---|---|
| Bar | 10%: +20% max HP for the next mission | 10%: away an extra week; 5%: loses 500 gold |
| Gambling Hall | 5%: wins 2,000 gold | 10%: away an extra week; 8%: loses 1,000 gold |
| Bathhouse | 8%: +1 speed for the next mission; 4%: 2 more stress off | 8%: away an extra week; 4%: loses 750 gold |

- **The Bar starts with 2 slots**, and every pair of heroes there in the same week gains +2 bond points, like DD2's inn items. A bond level reached there gives its boost on the pair's next mission together.
- **Heirloom Exchange**, DD1's rates: 3 Crests → 1 Bust or Deed; 6 Crests → 1 Portrait; 2 Busts or 2 Deeds → 3 Crests; 1 Portrait → 3 Crests; 3 Busts ↔ 2 Deeds; 3 Busts or 3 Deeds → 1 Portrait; 2 Portraits → 3 Busts or 3 Deeds. Any number of trades a week.
- **Wound treatment:** 750 gold (same ×1.4 / ×1.8) at the Abbey to heal a Wounded hero for this week's mission.
- **On the hamlet** a plate over each building shows its name and upgrades bought (gold when one is affordable), or the week it opens. What happened in town at week's end (Abbey and Tavern visits, side effects, the Bar's bonds) shows with the mission results, or in a "The week in town" window after waiting out a week.
- **Not yet:** the Sanitarium (needs quirks and diseases) and the Nomad Wagon (needs trinkets).

### Town screen and saving

- DD1 layout: a placeholder hamlet panorama with clickable buildings, a roster panel on the right, and a window per building. Top bar: week, gold and heirlooms, and **Embark**.
- **Expedition screen**, DD1's quest map: Embark (or the noticeboard) opens a full-screen placeholder map of the land beyond the hamlet with one landmark per region. Each region's quests sit by its landmark as shields framed in the tier's colour (Apprentice green, Veteran orange, Champion red), with the mission level inside and one pip per length step. The chosen quest's region, title, level, goal and rewards show top left, the roster runs down the right, and the lineup and Embark button sit along the bottom. Embark goes straight to the mission map; DD1's provisioning shop is skipped because there are no supplies. Esc goes back to town.
- **Mission map screen:** the map drawn over one shared placeholder backdrop (a dark trail), the region's name in the header, the party's marker, and the reachable rooms highlighted. A party panel shows HP and stress; the gold earned so far and Retreat sit beside it. Rest, cache and event rooms open as a panel over the map; fights go to the combat screen and come back.
- **Lineup:** DD1's embark slots: four slots, rank 4 on the left to rank 1 on the right as in combat. Each slot shows the hero standing there and their skills, with gold pips for the ranks each skill can be used from. Skills that can't be used from that rank are dimmed, and a hero with no attack from their rank is flagged in red. Click heroes to fill the slots from the front, drag to reorder or swap in a hero from the roster, and click a hero in a slot to take them out.
- One autosave slot, written after every town action and every fight on a mission (`user://`, which is browser storage on the web build).
- A title screen offers Continue, New Campaign and the Combat Sandbox. Launch options skip it: `--continue`, `--new-campaign`, `--sandbox`. With `--autoplay` the town takes any recruit waiting, treats the wounded, and embarks on its own, and the fights play themselves.

## Deviations from DD2

- `ai_weight` on skills is our extension. DD2 picks uniformly; leaving every weight at 1 does the same.
- **No permadeath.** A failed deathblow defeats and wounds a hero instead of killing them. Both DD games have permadeath.
- "Until next Inn" effects (Meltdown/Resolute deathblow changes) last until the end of the mission.
- Not implemented yet: relationships and affinity, quirks, diseases, combat items, Flame, battle modifiers, stalling penalties, retreating in the middle of a fight (you can only retreat between fights). Burn and the Immobilize token work in the engine but no content uses them.

## Presentation & input

The combat screen follows DD2's, as measured in [research/darkest-dungeon-ui.md](research/darkest-dungeon-ui.md). Authored at 1920×1080; it scales.

- **Battlefield** in the top ~70% on a background scene (`SandboxDef.background`), fading to black below the ground line. Heroes on the left facing right, rank 1 nearest the centre; enemies mirrored. Figures are about 380 px tall (`UnitDef.sprite`, mirrored for enemies) or a coloured placeholder shape.
- **No names on the battlefield.** Under each unit: DoT icons, an HP bar without numbers, stress pips (heroes), and token icons with small diamonds for extra stacks. Hover a unit for its full stat sheet.
- **Death's Door:** empty HP bar with a pulsing red frame, red tint, skull in the token row. **Corpses:** dark placeholder mound with a brown-grey HP bar.
- **Top:** ragged black band with the round counter and a turn-order queue of diamond portraits; the acting unit is rightmost.
- **Bottom HUD** on black, shown on hero turns only:
  - left: hero portrait and name, and the selected skill's details in DD2's order (numbers, Target, Self, conditional bonuses), then its limits (cooldown, uses per battle, an HP condition);
  - centre: skill name, rank pips, the 4 equipped skill icons, then Swap, Recover and Pass diamonds; under them the HIT / DMG / CRIT preview against the focused target;
  - right: target panel with HP, speed and resistances, lighting up the ones the skill rolls against.
- **Targeting:** blue brackets under valid enemy targets (green for allies), a translucent box on the focused one, gold squares on the tokens the attack would use up. The acting unit gets a gold bracket and amber glow.
- **Attacks cut to a letterboxed close-up:** HUD hidden, scene tinted with dark ink edges, attacker and targets re-staged up to 1.5× size, skill name in gold. Self and party skills stay on the battlefield.
- **Poses in the close-up:** the attacker shows that skill's **attack pose** and each target hit shows its **hurt pose**; a missing pose means the normal sprite. Poses go by convention in `art/poses/<unit id>/<skill id>.png` and `art/poses/<unit id>/hurt.png`, so real art can replace them one file at a time. `tools/make_poses.gd` generates placeholders from the normal sprites (leaning into the blow with motion lines and the skill's icon, or recoiling and flushed red): an attack pose for every hero skill and a hurt pose for every unit. Enemy attack poses aren't generated yet.
- **Pop-ups:** red damage (the unblocked number struck through when Block reduced it), orange "Critical!", grey Dodge, Miss and Resist, green heals, token and DoT icons with their names, stress in white.
- Wave title before round 1. Fonts: Grenze Gotisch for display text, Gelasio for body text (both SIL Open Font License).
- Combat log showing every roll (L, a dev overlay hidden by default) and a 2× speed toggle (S).
- Mouse first: click a skill, valid targets highlight, click a target. Keyboard: 1–8 pick a skill, Left/Right/Tab move the target, Enter/Space confirm, L log, S speed, R restart. Controller later.

### Mobile and touch

The web build plays on phones and tablets with touch. Mouse and keyboard on desktop stay exactly as they are; touch behaviour turns on with a touchscreen, and the phone layout on small screens.

- **Platform:** the same web build (GitHub Pages) in mobile browsers. Native Android and iOS apps come later.
- **Landscape only.** Held upright, the game shows "Turn your phone sideways".
- **Phone layout** on screens shorter than about 600 CSS pixels: roughly twice the text size and full-size touch targets (about 44 CSS pixels), with each screen rearranged to show less at once. Town building windows go full-screen with scrolling lists, and combat shows skill details only when asked. Tablets keep the normal layout, where text comes out around 13 CSS pixels.
- **Tap to look, tap again to act** in place of hover:
  - **Map:** tapping a room shows what it holds, with a Go button.
  - **Combat:** tapping a target shows its stats and the damage preview; tapping it again, or Confirm, uses the skill.
  - **Long press** (about half a second) on anything with extra information shows it: unit stat sheets, why a button is greyed out, skill icons, heirlooms.
- **Lineup:** tap a hero in a slot to pick them up, tap another slot to swap, tap the picked hero again to take them out. Dragging still works.
- **Fullscreen:** a button on the title screen. The web build is installable (Godot's progressive web app export), so "Add to Home Screen" opens it fullscreen in landscape. iPhones can't lock orientation from the browser, so they rely on the "turn sideways" screen.
- **How it's built:**
  - The phone layout runs the game on a 960×540 logical screen (half the 1920×1080 the screens are authored at), so everything is drawn twice as large.
  - Each screen's 1920×1080 stage (backgrounds, battlefield, map) shrinks to fit. The bars, panels, windows and buttons that must stay readable sit on a full-size layer on top.
  - Quest shields grow 1.8× and map rooms 1.6× on phones; combat skill buttons grow 1.3×.
  - Combat on phones hides the skill text, target panel and log. It shows Skill info (a popup), the focused target's HIT / DMG / CRIT and Confirm beside the skill bar instead.
  - Touch behaviour follows the last input: taps arrive as emulated mouse clicks, and a real mouse switches back to click behaviour.
  - Tablets keep the desktop layout with touch. They target with tap-and-tap-again, without a Confirm button.
  - `src/ui/device.gd` holds the flags and `src/ui/mobile.gd` (an autoload) does the detection, the long press and the overlays. `--phone` and `--touch` force them on desktop for testing.

## Content v0

Names are placeholders; the theme/setting is undecided. Rank notation: "From 1–2 → Enemy 1–3" means usable from ranks 1–2 against enemies in ranks 1–3; "1+2" hits both ranks at once. Resistances, crit chances and corpse HP are in the `.tres` files.

### Heroes

The cast is Darkest Dungeon 1's: the class names and each class's 7 combat skills at rank 1, translated from [research/darkest-dungeon-1-heroes.md](research/darkest-dungeon-1-heroes.md). The files keep the old placeholder ids (`content/heroes/vanguard.tres` is the Crusader). A hero starts with the first 4 skills in its file. They always include the skill DD1 gives every new hero of the class, and they let the class act from every rank. Exact numbers are in the `.tres` files and each skill's tooltip.

| Class (file) | Ranks | HP | Speed | Swap | Starting skills | Learned at the Guild |
|---|---|---|---|---|---|---|
| **Crusader** (vanguard) | 1–2 | 40 | 1 | ±1 | Smite, Zealous Accusation, Stunning Blow, Holy Lance | Battle Heal, Bulwark of Faith, Inspiring Cry |
| **Grave Robber** (cutthroat) | 1–4 | 28 | 8 | ±1 or ±2 | Lunge, Shadow Fade, Thrown Dagger, Pick to the Face | Flashing Daggers, Poison Dart, Toxin Trickery |
| **Arbalest** (marksman) | 3–4 | 32 | 3 | back 1–2 | Sniper Shot, Sniper's Mark, Battlefield Bandage, Blindfire | Bola, Suppressing Fire, Rallying Flare |
| **Vestal** (mender) | 2–4 | 29 | 4 | ±1 | Divine Grace, Divine Comfort, Dazzling Light, Mace Bash | Judgement, Illumination, Hand of Light |
| **Man-at-Arms** (warden) | 1–3 | 37 | 3 | ±1 or ±2 | Crush, Rampart, Defender, Retribution | Bellow, Command, Bolster |
| **Plague Doctor** (plaguebearer) | 2–4 | 26 | 7 | ±1 | Noxious Blast, Plague Grenade, Blinding Gas, Incision | Battlefield Medicine, Emboldening Vapours, Disorienting Blast |
| **Jester** (minstrel) | 1–4 | 25 | 7 | ±1 to ±3 | Dirk Stab, Harvest, Slice Off, Inspiring Tune | Finale, Solo, Battle Ballad |
| **Flagellant** (penitent) | 1–2 | 32 | 6 | forward 1–3, back 1 | Punish, Rain of Sorrows, Reclaim, Endure | Exsanguinate, Redeem, Suffer |

How DD1 translates:

- **Damage:** each class has a weapon damage range on our scale: Crusader 5–9; Grave Robber and Arbalest 4–8; Man-at-Arms and Flagellant 4–7; Vestal, Plague Doctor and Jester 3–6. A skill applies DD1's modifier to it, so Zealous Accusation's −40% gives 3–5. Crit is the class's DD1 base plus the skill's modifier, plus 2 points.
- **Stats:** HP is about 1.2× DD1's. Speed, resistances and Swap distances (DD1's move skill) are DD1's.
- **No accuracy or PROT,** as in DD2, so DD1's stat buffs become tokens:

  | DD1 effect | Token |
  |---|---|
  | PROT buff | Block |
  | Dodge buff | Dodge |
  | Damage buff | Strength |
  | Crit buff | Crit |
  | Speed buff | Speed |
  | Accuracy debuff | Blind |
  | Dodge debuff | Vulnerable |
  | Speed debuff | Daze |
  | Mark on an enemy | Combo; skills with a bonus against Marked targets get a Combo bonus |
  | Mark on oneself | Taunt |
- **Healing and DoTs:**
  - DoTs are 0.6× DD1's per-turn amount, rounded up.
  - Heals are about 1.3× DD1's.
  - Stress relief is −1 for Inspiring Cry and Bolster, and −2 for Inspiring Tune and Endure.
  - Judgement, Exsanguinate and Redeem heal the user a share of their max HP.
- **Limits:**
  - Per-battle limits are DD1's: 1 for Bulwark of Faith, Toxin Trickery and Bolster, 2 for Emboldening Vapours, Solo and Redeem, 3 for Blinding Gas and Exsanguinate.
  - Exsanguinate and Redeem need the Flagellant below 40% HP.
  - Cooldowns are ours, since DD1 has none. They go on stuns from the back ranks, Shadow Fade, Retribution, the party-wide buffs and Disorienting Blast.
- **Left out for now:**
  - Unholy and Blighted damage bonuses, and accuracy buffs.
  - The Jester's Finale build-up; Finale hits for +100% instead.
  - Stealth reveal on Rallying Flare and Illumination.
  - Pick to the Face ignoring PROT, and Blindfire's random target.
  - Disorienting Blast's shuffle, which is a knockback instead.
  - Resistance debuffs.
  - The Flagellant's low-HP bonus applies below half HP, the engine's threshold, rather than DD1's 40%.
### Enemies

| Enemy | Ranks | HP | Speed | Skills |
|---|---|---|---|---|
| Ghoul (melee) | 1–2 | 26 | 3 | **Claw**: 4–7 damage to hero ranks 1–2, Bleed 1 × 3. **Gnaw**: 2–4 damage and +1 stress to hero rank 1 |
| Bone Spearman (melee, blocks) | 1–3 | 24 | 4 | **Thrust**: 5–8 damage to hero ranks 1–3. **Brace** (when it has no Riposte): self Block and Riposte ×2. Ripostes with **Counter Thrust** (2–4) |
| Spitter (blight) | 2–4 | 15 | 6 | **Spit**: 1–2 damage, Blight 3 × 3, hero ranks 2–4. **Skitter** (from 2–3): self moves back 1, gains Dodge |
| Cultist (stress and debuffs) | 3–4 | 18 | 5 | **Whisper**: +2 stress to any hero. **Curse**: 2–4 damage plus Blind or Weak |
| Brute (large, 2 ranks) | 1–2 | 75 | 2 | **Smash**: 8–12 damage to hero rank 1, knock back 1. **Sweep**: 4–7 damage to hero ranks 1+2. **Roar** (when it has no Strength): +1 stress to all heroes, self Strength. 1 Death Armor |

### Sandbox run

- Starting order: Crusader (1), Grave Robber (2), Arbalest (3), Vestal (4), each with their starting skills.
- Wave 1 "Ghoul Pack": Ghoul, Ghoul, Spitter, Cultist.
- Wave 2 "Bone Line": Bone Spearman, Ghoul, Spitter, Cultist.
- Wave 3 "The Brute": Brute (ranks 1–2), Cultist, Spitter.
- Between waves nothing is restored except DD2's end-of-battle cleanup above. HP, stress and Death's Door carry over.

### Changes from the approved draft, and why

- **Cultist's skill is called Curse** (was Hex), so the log doesn't show two different skills named Hex.
- **Enemy HP and damage went up** (Ghoul 20→26 HP, Claw 3–6→4–7; Spearman 18→24, Thrust 4–7→5–8; Spitter 12→15; Cultist 14→18, Curse 2–3→2–4; Brute 60→75, Smash 6–10→8–12, Sweep 3–6→4–7) and the **Brute got 1 Death Armor**. With the draft numbers a scripted sensible player won every run.

### Balance snapshot

`tests/test_simulation.gd` plays full sandbox runs with scripted players and prints:

- Sensible player (heals the hurt, calms the stressed, otherwise hits hardest on the weakest foe): wins ~96% of runs, losing ~1.1 heroes per run.
- Random player: wins ~52% of runs.

A human should land between the two. Retune once it has been played.

`scripts/balance.ps1` plays whole missions with random parties of the cast and the map auto-player. With level-1 heroes at Apprentice they finish about 40% of short missions, 23% of medium and 19% of long. Veteran and Champion missions with unupgraded heroes are far lower, which is intended: they need levels and gear. The bot is a pessimistic stand-in for a human, who picks a party and a route on purpose.

## Future features

Ideas we want to build, not designed in detail yet. Each will be a deliberate difference from DD2 and go under Deviations once built.

### Terrain effects

Rank slots on either side can hold a terrain effect, so the fight is about **where** units stand as well as who they are.

- **Effects on a slot.** Examples:
  - cover: start each round with Block
  - hazard: fire, spikes or a blight pool that harms whoever ends a turn there or is moved into it
  - high ground: bonus crit
  - mire: Immobilize when entering
- **Skills that target terrain instead of units.** A skill can aim at a rank slot rather than the unit standing in it: set enemy rank 2 on fire, scatter caltrops over ranks 3–4, or raise cover for your own rank 1. Effects stay on the slot when its occupant moves or dies.
- **Pushing enemies into effects.** Knockback, pull and swap become attacks: the Brute's Smash knocking a hero back into fire, or a hero pulling an enemy onto spikes. Moving into a hazard triggers it immediately.
- **Sources.** Terrain can also come with the encounter (a wave that starts with a burning slot) or from deaths (a bleeding corpse leaves a blood pool).

To decide when we design it:
- how long effects last (rounds, triggers, or the whole fight)
- whether a slot can hold more than one effect
- how large units on two slots interact with terrain
- how terrain shows up on screen and in the skill targeting
- what the AI does with it

### Scouting

Rooms already start hidden until they're among the next choices (see [Mission maps](#mission-maps)). Scouting would reveal more of the map ahead, as in DD2 ([research/path-maps.md](research/path-maps.md)).

- **Hidden rooms** show only that a room is there; you learn its type when you reach it or once it is scouted.
- **Ways to scout:** a watchtower room that reveals everything ahead, hero skills or quirks that scout, and Guild upgrades that reveal more at the start.
- **Regions or modifiers** that scout less (fog) or more.
- **Always revealed:** the elite rooms and the finale, so the big risks can still be planned around, as DD2 always shows the Lair.

To decide when we design it:
- how much starts revealed, and whether that depends on mission tier
- whether roads between rooms can be hidden as well as rooms
- whether unscouted events and fights pay or cost more

## Open / deferred

- **Theme and setting**, and with it all names.
- Town features after v1, roughly in DD1's priority: quirks, with their Abbey and Tavern side effects, and the Sanitarium; trinkets and the Nomad Wagon; diseases; region bosses, with DD1's per-region progress bar and dungeon levels; quest goals beyond winning every fight; town events; a dungeon map with supplies, light and camping (Survivalist).
- Relationships, Paths, combat items, skill loadouts.
- Real art, audio, controller support, multiple save slots.
- DD2 screen features waiting on mechanics or writing: the Flame emblem at the top, speech-bubble barks, right-click enemy and hero inspect sheets.
