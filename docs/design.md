# Darko Dungo — Design

Living record of agreed decisions. Anything not written here is either "do what Darkest Dungeon 2 does" or still open (see the end).

## Platform & tooling

- Godot 4.7.2, standard (non-.NET) build, statically typed GDScript.
- Git repository. Tests run headless through a small hand-rolled runner (`godot --headless --script ...`); no test add-on.

## Scope

- **v1: the campaign.** A DD1-style town loop around the combat: recruit a fixed cast, pick a party of 4, run missions of a few fights, and spend gold and heirlooms on the heroes and buildings. Details under [Campaign](#campaign).
- **The combat sandbox** (a fixed party against 3 waves) stays as a test mode, started with `-- --sandbox`.
- Out of scope for v1: dungeon map, quirks, diseases, supplies, Paths. See [Open / deferred](#open--deferred).

## Architecture

- **Combat core** (`src/core/`) is pure logic: plain GDScript classes (no nodes), a seeded RNG so any fight replays exactly from its seed, and an event stream ("X used Y on Z, crit, 7 damage, Bleed applied") as its only output.
- **Presentation** (`src/ui/`) renders those events and sends the player's choices back to the core. It never decides outcomes.
- **Content** (`content/`) — heroes, enemies, skills, waves — is data, stored as Godot Resources (`.tres`), not code. Edit them in the [balance tool](#balance-tool) or the Godot inspector.
- Combat takes a party in and hands it back out (HP, stress, Death's Door, deaths, long-lasting buffs), so it plugs into whichever game loop is chosen later.

## Combat model

- **Mirror Darkest Dungeon 2.** Where DD2 has a rule, copy it number for number. Reference: [research/darkest-dungeon-combat.md](research/darkest-dungeon-combat.md). All DD2 numbers live in `src/core/rules.gd` and `src/core/tokens.gd`.
- **Stress** 0–10 with Meltdown (80%) or Resolute (20%) at 10. In a fight it happens on the spot; on a mission map, as soon as an event pushes a hero to 10 or when a hero sets out at 10 (the map opens with a "Setting out" panel). Round-based buffs from one outside a fight count down in the next fight.
- **Death's Door**: heroes at 0 HP are on Death's Door; further damage rolls deathblow resistance (60% base, −10% per survived check, clamped 33–90%). A failed roll **defeats** the hero rather than killing them (see [Campaign](#campaign)). Enemies die at 0 HP unless they have Death Armor.
- **Hero kit**: each class has its DD2 kit of 11 skills and a hero takes 5 into a fight (see [Skill loadouts](#hero-growth)), plus Swap and Pass. Recover (DD2's `pass_heal`) appears below 25% HP. Cooldowns and per-battle limits apply.
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

- **One unique hero per class.** The cast is 7 of DD2's heroes (see [Heroes](#heroes)); you start with 5 at level 0: the Crusader, Grave Robber, Vestal, Man-at-Arms and Plague Doctor.
- **Recruiting through bosses:** there is no Stagecoach. Beating a region's boss for the first time lets one hero join: you choose from those who haven't, and they join at level 1. Two heroes are left to join (Jester, Flagellant), so the third region's boss has no one left to bring. See [Region bosses](#region-bosses).
- **No permadeath.** A failed deathblow **defeats** the hero: they leave the fight and take no further part in the mission. Back in town they are **Wounded** and sit out the next week, unless you pay to treat them at once. They keep their levels, gear and skills.
- **Between missions** heroes return at full HP. Stress carries over until relieved at the Abbey. Idle heroes lose 1 stress per week.

### Weeks and missions

- **One mission is one week.** The week advances when the party returns, whether it won, retreated or wiped. Then: Abbey and Tavern visits and wound treatments finish, idle heroes lose stress, and the mission board refreshes.
- **Regions**, like DD1's Ruins, Weald, Warrens and Cove: three placeholder places, each with its own enemy groups and finale. **The Graveyard** has skeletons and cultists, **the Burrows** ghouls and spitters, and **the Chapel** cultists and the Brute (`content/regions/`).
- **Regions open one at a time,** in that order. Only the Graveyard is open at the start; beating a region's boss for the first time opens the next one, and the mission results say so. On the expedition map a closed region shows dimmed, with the boss that opens it ("Opens when The Gravelord falls").
- **Missions:** 2 per open region each week, or 4 while only the first is open, so 4 to 6 to choose from. Each has a **tier** (Apprentice level 1, Veteran level 4, Champion level 7: the tiers spread over hero levels 1–10) and a **length** (short, medium, long). At least one is at the highest unlocked tier and, once Veteran is unlocked, at least one is still Apprentice. Veteran missions appear once a hero reaches level 3, Champion once a hero reaches level 6.
- **A mission is a map** of rooms to pick a route through, like a Slay the Spire act or DD2's roads, longer for longer missions. Its goal is to reach the end and win the region's finale, or its boss on a boss mission. See [Mission maps](#mission-maps). DD1's other quest goals (Explore, Gather, Activate) stay deferred.
- **Party selection:** up to 4 heroes, rank 1 first in the order picked. Heroes who are Wounded or busy at the Abbey can't go. Heroes at least 3 levels above the mission level refuse it ("will not go"), except Champion missions, which any hero takes. Heroes more than one level below it start the mission with +2 stress per level short: level 0 is fine for Apprentice, level 3 for Veteran, level 6 for Champion.
- **Nobody fit to go:** when every hero is Wounded or busy in town and no recruit is waiting to join, the board offers **Wait out the week**, which ends the week without a mission. It keeps a wiped party that can't afford treatment from locking the campaign; DD1 never needs it because its Stagecoach always has recruits.

### Region bosses

After DD1's region progress and bosses:

- **Unlocking:** every mission **completed** in a region fills its **boss progress**, by its length: short 25%, medium 35%, long 50% (so 4, 3 or 2 missions); retreats and wipes don't count. When it's full, the region's **boss mission** appears on the board, by its region, as a skull shield on a blood-red field. It stays there, week after week, until beaten.
- **Where it shows:** on the expedition map, a bar under each open region's name fills blood-red towards a skull, with the chosen quest's share shown ahead of it in pale gold; it becomes "Boss awaits", then "Conquered". The quest details list the share ("+35% boss progress"), and the mission results the new total.
- **A boss mission** is a **long** map (20 columns) that ends at the region's boss instead of its finale. It pays a long mission's gold and XP and **double** heirlooms.
- **The first win** against each region's boss lets a new hero join (see Recruiting), and opens the next region. A window in town offers the choice of hero.
- **Coming back harder:** after a win the region's progress starts again from empty, and when it's full again its boss returns a tier harder: Apprentice, then Veteran, then Champion. Later wins pay but bring no recruit. After the Champion boss the region is **conquered**.
- **The bosses**, each with escorts, built from mechanics the engine already has. They were tuned so fresh level-0 random parties won about 40–46% at Apprentice against the old bot. With the value-based bot, random loadouts and parties lined up by their skills' ranks, the balance tool's Quick sweep at Base now gives the Gravelord 92%, the Maw 65% and the Hollow Saint 48% (target 40–46%, in `content/balance_targets.tres`):

| Region | Boss | Kit |
|---|---|---|
| Graveyard | **The Gravelord** (2 ranks), with a Bone Spearman and a Cultist | Bone Storm on every rank, Grasp of the Grave (heavy, Weak), Raise the Dead (Strength for all), Death Knell (stress to all) |
| Burrows | **The Maw** (2 ranks), with two Spitters | Gorge (heavy, Bleed), Swallow (Stun), Retch (Blight on the back ranks), Ravenous Howl (stress to all) |
| Chapel | **The Hollow Saint** (rank 4, acts twice), behind the Brute and a Cultist | Sermon of Despair (+2 stress to all), Smite (heavy, Vulnerable), Wailing Choir (every rank), Hallowed Ward (Block for all), Saint's Mercy (heals) |
- **Enemy tiers:** Veteran enemies have +25% HP and damage; Champion enemies +90% HP, +75% damage and +5% crit (up from +50% and +50% when talents came in, so missions stay about as hard: at the same XP, heroes with their talents finish about 10 points more often than before talents, at either tier).

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

Tuned so that a fresh level-0 party lost about 50–60% of its HP to an elite, against about 30% to a normal fight and 45% to a finale, with the old bot. The value-based bot loses less at Base: about 51–55% to elites, 19–29% to normal fights and 31–40% to finales.

### Hero growth

- **Levels 1–10** at 2 / 5 / 8 / 12 / 17 / 22 / 28 / 34 / 41 / 48 total XP: level 10 takes the XP level 6 took when that was the most, so the campaign keeps its length. Each level gives +6% to stun, bleed, blight, burn, move and debuff resistance (+60% at 10, as at the old 6), and raises the gear and skill caps.
- **Talents:** a point at levels 2, 4, 6, 8 and 10, each spent on one of that row's three talents. Each class has its own 15 (`content/talents/<class>/`): row 1 sets a style (damage, health or healing), rows 2 and 4 work with the class's skills, row 3 is staying power, row 5 a capstone. They are made like trinkets (stats, stats with a condition, triggers), so they need no combat rules of their own, and work like trinkets that can't come off.
  - Chosen on the hero sheet's **Talents** tab, which opens by itself while a point waits; the roster shows a gold diamond on the portrait, and the mission results say so. Rows can be chosen in any order. A click picks a talent and **Choose** confirms it.
  - Choosing is for good, except at the **Guild**, which clears all of a hero's talents for 1,000 gold (×1.4 at levels 4–6, ×1.8 at 7–10) so the points can go elsewhere.
  - In a fight, a hero's details list their trinkets and talents.
- **Blacksmith:** weapon and armour ranks 2–5 for 750 / 1,750 / 3,000 / 6,000 gold, needing hero level 1 / 3 / 5 / 8 and the matching Blacksmith upgrade.
  - Each weapon rank above 1: +10% damage, +1% crit, and +1 speed at ranks 3 and 5.
  - Each armour rank above 1: +20% of base HP.
- **Guild:** skill ranks 2–5 for 250 / 750 / 1,250 / 2,500 gold, same level gates, needing the matching Guild upgrade. Each rank above 1: +10% damage or healing, +1% crit, +10% resistance pierce on its effects.
- **Skill loadouts**: each class has more skills than a hero takes into a fight. A hero takes **5**, DD2's number, chosen from the skills they've learned. Every hero knows their class's 5 DD2 starting skills from the start, and learns the other 6 at the Guild for 500 gold each (×1.4 at levels 4–6, ×1.8 at 7–10); a new skill is equipped straight away while a slot is free. Only learned skills can be trained. The 5 are chosen in town (the hero's sheet or the Guild) or on the mission map between rooms (the Skills button), and apply from the next fight.

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
| **Nomad Wagon** | week 2 | Sells trinkets, buys back unworn ones (see [Trinkets](#trinkets)) | Stock: one more trinket a week, 3 levels (3 Portraits + 6 Crests, 6 + 12, 10 + 20). Haggling: −10% prices per level, 5 levels (2 + 4 up to 12 + 24). Both ladders are ours |

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
- **Not yet:** the Sanitarium (needs quirks and diseases).

### Trinkets

DD2's ([research/darkest-dungeon-2-trinkets.md](research/darkest-dungeon-2-trinkets.md), current wiki values).

- **Wearing:** each hero wears 2, put on and taken off on their sheet in town. Hero trinkets are for one class. Nobody owns two of the same trinket, as in DD2.
- **Rarities:** DD2's Vague, Distant and Indelible, plus Ancestral. Drops weigh them by mission tier: Apprentice 10 : 6 : 2 (DD2's road-battle ladder), Veteran 3 : 6 : 3, Champion 0 : 6 : 4, so Vague ones fade out of harder dungeons and Indelible ones grow common.
- **Where they come from:**
  - caches and won elite fights, 50% each;
  - every completed mission, one;
  - region bosses, a boss trinket not owned yet (Footman's Grog, Reverberating Redoubt, Kitchen Knives, Carved Bodkin) or Ancestor's Coat;
  - the Nomad Wagon.

  Trinkets found on the way are lost if the party falls; a retreat keeps them.
- **What they do:** passive stats (damage, crit, speed, max HP, resistances, healing, damage taken, DoT dealt and received), stats with a condition (`If Stealth: +20% damage`, `If Target has Bleed`, `If HP < 20%`, one skill only), and triggers on combat events (`Apply on Hit`, `Gain When Hit`, `Apply to Attacker When Hit`, `Gain on Miss`, `Turn Start: If First in Turn Order`, `Each Hero on Combat Start`, `Target: <skill>`, `When Moving`, `On Entering Death's Door`, on a resist). Each line keeps DD2's chance, and `X or Y` lines give at most one.
- **The 81:** 20 hero trinkets (the Crusader's Pilfered Wealth needs Relics), the 12 stat trinkets in all three tiers (Minor, plain, Greater), 11 token-trigger trinkets, 5 region trinkets (any dungeon here), 4 rare Indelibles, 4 boss trinkets and Ancestor's Coat. Lines tied to systems we don't have (Flame, Relics, item tags, Disease, Horror) are left out, and `Invert` lines remove instead.
- **Prices:** about 100 gold per DD2 Bauble: Vague 500, Distant 2,000–3,000, Indelible 5,000–6,500. The Wagon buys back for 25%; boss and Ancestral trinkets can't be sold.
- **Nomad Wagon:** opens in week 2 and sells 4 trinkets a week, none already owned, at the best tier the roster can take on.

### Dialogue scenes

Full-screen scenes in town, in DD's voice: a hero and the Ancestor narrating.

- **When:**
  - a new campaign opens with one scene of the five starting heroes arriving;
  - a recruit gets their own scene as they join;
  - each level a hero gains brings a scene when the party is back in town.
- **What they say:** a mix of each hero's backstory and what has just happened.
  - Each hero's past comes a part at a time, levels 1 to 10. The recruits' join scene sets theirs up.
  - Before the first part, the hero looks back on the mission just finished: the boss, the region, a long road, a comrade who fell, their own stress, a bonded partner, or a particular hero beside them, who may answer. The best-fitting line plays.
  - The Ancestor greets the party home once, before the first of a mission's scenes.
- **Writing:** original, not DD's script. The heroes go by their class names, and the backstories are new.
- **Look:**
  - The hamlet darkened behind, the cast standing tall, and the speaker lit from below while the others stand in shadow. Two heroes face each other.
  - A framed text box with the speaker's name. Text types out.
  - Click, tap, Enter or Space shows the line, then moves on. Skip or Esc ends the scene.
- **Saving:** scenes waiting to play are saved, and a scene skipped part-way counts as seen. Quitting during one plays it again next time.
- **Content:** plain-text scripts in `content/dialogue/`; the format is documented at the top of `src/campaign/dialogue.gd`.

### Town screen and saving

- DD1 layout: a placeholder hamlet panorama with clickable buildings, a roster panel on the right, and a window per building. Top bar: week, gold and heirlooms, and **Embark**.
- **Building windows** open on a banner: the building's corner of the hamlet picture, what it is for, and the Services and Upgrades tabs.
  - Upgrades: each line is a card with its level, what it does now, the Upgrade button with its heirloom cost as icons (red where the estate is short), and its levels as a track of steps saying what each brings.
  - Blacksmith: the hero picker and the chosen hero's weapon and armour as cards, their ranks as the same steps, those past what the smiths can make locked.
  - Guild: the hero sheet's skill grid; choose a skill to learn it, train it or equip it.
  - Abbey and Tavern: each activity as a card with its relief, price and a seat per slot holding the hero there (click to bring them back), and Send for the hero picked; at the Abbey, the wounded with Treat.
  - Exchange: each trade as a card of heirloom icons with Trade.
- **Hero sheet**, DD1's character sheet, opened from the roster:
  - left: the hero standing in a card frame, their level with an XP bar to the next, stress pips, where they are this week, Tavern perks, and their bonds;
  - middle: max HP, speed, weapon and armour, the resistance row as the combat target panel shows it, and the class's 11 skills as an icon grid: equipped ones lit in gold, learned ones dimmed, unlearned ones dark with a padlock, the rank as diamonds. Click one to equip or unequip it; hover it to see what it does in the panel under the grid;
  - right: two trinket sockets (click one to take its trinket off) with what the worn trinkets do, and the estate's unworn trinkets the hero could wear;
  - phones stack the three in the scrolling window, and a tap on a skill shows it with an Equip or Unequip button.
- **Expedition screen**, DD1's quest map: Embark (or the noticeboard) opens a full-screen placeholder map of the land beyond the hamlet with one landmark per region. Each region's quests sit by its landmark as shields framed in the tier's colour (Apprentice green, Veteran orange, Champion red), with the mission level inside and one pip per length step. The chosen quest's region, title, level, goal and rewards show top left, the roster runs down the right, and the lineup and Embark button sit along the bottom. Embark goes straight to the mission map; DD1's provisioning shop is skipped because there are no supplies. Esc goes back to town.
- **Mission map screen:** the map drawn over one shared placeholder backdrop (dark ground in dead woods), the region's name in the header, and the reachable rooms glowing.
  - Corridors are worn earth paths, gently bowed: gold footsteps along the route taken, bright dashes on the ways on, the ones left behind faded. The first column's start at the party's campfire.
  - Rooms show their icon once revealed and a "?" until then (events are a scroll). Rooms passed through carry a gold check, and rooms left behind fade.
  - The party's token, the front hero's framed portrait on a pennant, stands over the current room (below it when the top band would hide it) and walks to each room chosen. A party panel shows HP and stress; the gold earned so far and Retreat sit beside it. Rest, cache and event rooms open as a panel over the map; fights go to the combat screen and come back.
- **Lineup:** DD1's embark slots: four slots, rank 4 on the left to rank 1 on the right as in combat. Each slot shows the hero standing there and their skills, with gold pips for the ranks each skill can be used from. Skills that can't be used from that rank are dimmed, and a hero with no attack from their rank is flagged in red. Click heroes to fill the slots from the front, drag to reorder or swap in a hero from the roster, and click a hero in a slot to take them out.
- One autosave slot, written after every town action and every fight on a mission (`user://`, which is browser storage on the web build).
- A title screen offers Continue, New Campaign and the Combat Sandbox, and from the project folder the [balance tool](#balance-tool). Launch options skip it: `--continue`, `--new-campaign`, `--sandbox`, `--balance`. With `--autoplay` the town takes any recruit waiting, treats the wounded, and embarks on its own, and the fights play themselves.

## Deviations from DD2

- `ai_weight` on skills is our extension. DD2 picks uniformly; leaving every weight at 1 does the same.
- **No permadeath.** A failed deathblow defeats and wounds a hero instead of killing them. Both DD games have permadeath.
- "Until next Inn" effects (Meltdown/Resolute deathblow changes) last until the end of the mission.
- Not implemented yet: relationships and affinity, quirks, diseases, combat items, Flame, Paths and skill mastery, battle modifiers, stalling penalties, retreating in the middle of a fight (you can only retreat between fights).
- The hero kits leave out Horror, Radiance's +2 DMG against Burn, and the Grave Robber keeping Combo while she holds a Crit token. Consecrations work as DD2's rank tokens.

## Presentation & input

The combat screen follows DD2's, as measured in [research/darkest-dungeon-ui.md](research/darkest-dungeon-ui.md). Authored at 1920×1080; it scales.

- **Battlefield** in the top ~70% on a background scene (`SandboxDef.background`), fading to black below the ground line. Heroes on the left facing right, rank 1 nearest the centre; enemies mirrored. Figures are about 380 px tall (`UnitDef.sprite`, mirrored for enemies) or a coloured placeholder shape.
- **No names on the battlefield.** Under each unit: DoT icons, an HP bar without numbers, stress pips (heroes), and token icons with small diamonds for extra stacks. Hover a unit for its full stat sheet.
- **Death's Door:** empty HP bar with a pulsing red frame, red tint, skull in the token row. **Corpses:** dark placeholder mound with a brown-grey HP bar.
- **Top:** ragged black band with the round counter and a turn-order queue of diamond portraits; the acting unit is rightmost.
- **Bottom HUD** in a framed bar below the units' tokens, shown on hero turns only:
  - left: the hero's framed portrait in colour, name, HP and stress, and the selected skill's details in DD2's order (numbers, Target, Self, conditional bonuses), then its limits (cooldown, uses per battle, an HP condition);
  - centre: skill name, rank pips, the 4 equipped skill icons, then Swap, Recover and Pass diamonds; under them the HIT / DMG / CRIT preview against the focused target;
  - right: target panel with HP, speed and resistances, lighting up the ones the skill rolls against.
- **Targeting:** blue brackets under valid enemy targets (green for allies), a translucent box on the focused one, gold squares on the tokens the attack would use up. The acting unit gets a gold bracket and amber glow.
- **Attacks cut to a letterboxed close-up:** HUD hidden, scene tinted with dark ink edges, attacker and targets re-staged up to 1.5× size, skill name in gold. Self and party skills stay on the battlefield.
- **Poses in the close-up:** the attacker shows that skill's **attack pose** and each target hit shows its **hurt pose**; a missing pose means the normal sprite. Poses go by convention in the unit's own art folder, named after its class, next to its `sprite.png`: `art/characters/<class>/<skill id>.png` and `art/characters/<class>/hurt.png`, so real art can replace them one file at a time. `tools/make_poses.gd` generates placeholders from the normal sprites (leaning into the blow with motion lines and the skill's icon, or recoiling and flushed red): an attack pose for every hero skill and a hurt pose for every unit. Enemy attack poses aren't generated yet.
- **Pop-ups:** red damage (the unblocked number struck through when Block reduced it), orange "Critical!", grey Dodge, Miss and Resist, green heals, token and DoT icons with their names, stress in white.
- Wave title before round 1. Fonts: Grenze Gotisch for display text, Gelasio for body text (both SIL Open Font License). Gelasio renders as a multi-channel distance field, because rasterised at a scaled window size it clipped the bottoms of some lines.
- **Atmosphere** on every screen, over the picture and under the UI (`src/ui/atmosphere.gd`): dark corners, film grain, a torch-like flicker in combat, and the hamlet's lit windows and lamps glowing and guttering.
- Combat log showing every roll (L, a dev overlay hidden by default) and a 2× speed toggle (S).
- Mouse first: click a skill, valid targets highlight, click a target. A hero's turn starts with no skill chosen, so the first clicks can look around; clicking the chosen skill again lets go of it. Keyboard: 1–8 pick a skill, Left/Right/Tab move the target, Enter/Space confirm, Esc close the details or let go of the skill, L log, S speed, R restart. Controller later.
- **Unit details**, DD2's inspect sheet: clicking any unit that isn't a target of the chosen skill (or right-clicking any unit) opens a panel over the other side of the battlefield, the unit marked with pale brackets. It shows the portrait, rank, HP, speed and stress, the resistance row, tokens, DoTs, Regen and passing buffs with what each does, bond bonuses, and the unit's skills with their rank pips (hover one for its details). It follows the fight as events play, and closes for close-ups and when the unit leaves.

### Mobile and touch

The web build plays on phones and tablets with touch. Mouse and keyboard on desktop stay exactly as they are; touch behaviour turns on with a touchscreen, and the phone layout on small screens.

- **Platform:** the same web build (GitHub Pages) in mobile browsers. Native Android and iOS apps come later.
- **Landscape only.** Held upright, the game shows "Turn your phone sideways".
- **Phone layout** on screens shorter than about 600 CSS pixels: roughly twice the text size and full-size touch targets (about 44 CSS pixels), with each screen rearranged to show less at once. Town building windows go full-screen with scrolling lists, and combat shows skill details only when asked. Tablets keep the normal layout, where text comes out around 13 CSS pixels.
- **Tap to look, tap again to act** in place of hover:
  - **Map:** tapping a room shows what it holds, with a Go button.
  - **Combat:** tapping a target shows its stats and the damage preview; tapping it again, or Confirm, uses the skill. Tapping any other unit opens its details over half the screen.
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

The cast is seven of Darkest Dungeon 2's heroes with their DD2 kits: base stats and all 11 combat skills each, Wanderer path, unmastered, at current values (including the Steadfast Stewards Pt. 2 patch), from [research/darkest-dungeon-2-heroes.md](research/darkest-dungeon-2-heroes.md). The DD1 Arbalest has no DD2 version and is gone. The files keep the old placeholder ids (`content/heroes/vanguard.tres` is the Crusader). Each file lists DD2's 5 starting skills first, then the 6 that DD2 unlocks at the Shrine of Reflection, learned here at the Guild. Exact numbers are in the `.tres` files and each skill's tooltip.

| Class (file) | HP | Speed | Swap | Starting skills | Learned at the Guild |
|---|---|---|---|---|---|
| **Crusader** (vanguard) | 40 | 2 | ±1 | Smite, Stunning Blow, Zealous Accusation, Inspiring Cry, Rallying Cry | Reap, Battle Heal, Bulwark of Faith, Holy Lance, Radiance, Tenacity |
| **Grave Robber** (cutthroat) | 29 | 5 | ±1 or ±2 | Pick to the Face, Thrown Dagger, Flashing Daggers, Poison Dart, Absinthe | Dead of Night, Repartee, Lunge, Shadow Fade, Pirouette, Glint in the Dark |
| **Vestal** (mender) | 41 | 2 | ±1 | Hand of Light, Illumination, Judgement, Divine Grace, Consecration of Fortitude | Ministrations, Mace Bash, Sanctuary, Consecration of Light, Divine Comfort, Mantra |
| **Man-at-Arms** (warden) | 42 | 2 | ±1 or ±2 | Crush, Rampart, Defender, Bolster, Hold the Line | Bellow, Stand Fast, Retribution, Courageous Abandon, Command, Strategic Withdrawal |
| **Plague Doctor** (plaguebearer) | 30 | 4 | ±1 | Noxious Blast, Blinding Gas, Incision, Battlefield Medicine, Ounce of Prevention | Emboldening Vapours, Plague Grenade, Indiscriminate Science, Cause of Death, Disorienting Blast, Magnesium Rain |
| **Jester** (minstrel) | 29 | 4 | ±1 to ±3 | Razor's Wit, Fade to Black, Slice Off, Battle Ballad, Inspiring Tune | Play Out, Harvest, Echoing March, Finale, Solo, Encore |
| **Flagellant** (penitent) | 50 | 3 | forward 1–2, back 1 | Punish, Fester, Deathless, Endure, Lash's Gift | Acid Rain, More! MORE!, Suffer, Sepsis, Undying, Necrosis |

Class rules:

- **Vestal:**
  - **Conviction:** she gains 1 at each turn start, up to 3. Judgement, Mace Bash, Divine Grace and Mantra grow stronger at 2 and 3, and spend all of it at 2 or more. Without Paths, the gain is wired to her class (DD2 puts it on her Wanderer path).
  - **Consecrations:** they bless a hero rank for 3 rounds. Whoever stands there gains Block or Dodge (Fortitude) or Strength (Light) at each turn start, and a new Consecration replaces the old.
- **Flagellant:**
  - **Toxic:** at max stress he turns Toxic instead of melting down or turning resolute. His stress drops to 1, his HP is set to 30%, his cooldowns reset, and he gains a Toxic token (up to 3) that Blights anyone who hits him by 2 per token.
  - **Pain:** More! MORE! gives him Pain each time he is hurt, until the end of his next turn. At his turn end he heals 10% per Pain token, then the tokens go.
  - **Death's Door:** he isn't made Weak there.
  - **Costs:** many of his skills cost him HP or stress.
- **Man-at-Arms:** he has his own Riposte attack (3–5).

The kits brought these mechanics to the combat engine:

- **Ignored tokens:** Block, Dodge, Guard or Stealth, of which one stack is still spent.
- **Combo payoffs:** extra crit, resistance piercing, and effects that only work against Combo.
- **Tier tokens.**
- **Corpse skills.**
- **Effects over time:** Regen, and timed stat buffs and debuffs, such as speed, piercing, healing received, can't-gain-Block, and pulls each turn.
- **Turn and position:** extra turns (Encore), Shuffle, and taking over DoTs.
- **Unusual damage:** damage from the target's remaining DoTs (Cause of Death), heals scaling with tokens, and stress relief on a kill.

**Placeholders:** the skill icons are copies of older ones, and the attack poses are generated.
### Enemies

| Enemy | Ranks | HP | Speed | Skills |
|---|---|---|---|---|
| Ghoul (melee) | 1–2 | 26 | 3 | **Claw**: 4–7 damage to hero ranks 1–2, Bleed 1 × 3. **Gnaw**: 2–4 damage and +1 stress to hero rank 1 |
| Bone Spearman (melee, blocks) | 1–3 | 24 | 4 | **Thrust**: 5–8 damage to hero ranks 1–3. **Brace** (when it has no Riposte): self Block and Riposte ×2. Ripostes with **Counter Thrust** (2–4) |
| Spitter (blight) | 2–4 | 15 | 6 | **Spit**: 1–2 damage, Blight 3 × 3, hero ranks 2–4. **Skitter** (from 2–3): self moves back 1, gains Dodge |
| Cultist (stress and debuffs) | 3–4 | 18 | 5 | **Whisper**: +2 stress to any hero. **Curse**: 2–4 damage plus Blind or Weak |
| Brute (large, 2 ranks) | 1–2 | 75 | 2 | **Smash**: 8–12 damage to hero rank 1, knock back 1. **Sweep**: 4–7 damage to hero ranks 1+2. **Roar** (when it has no Strength): +1 stress to all heroes, self Strength. 1 Death Armor |

### Sandbox run

- Starting order: Crusader (1), Grave Robber (2), Plague Doctor (3), Vestal (4), each with their first 5 skills.
- Wave 1 "Ghoul Pack": Ghoul, Ghoul, Spitter, Cultist.
- Wave 2 "Bone Line": Bone Spearman, Ghoul, Spitter, Cultist.
- Wave 3 "The Brute": Brute (ranks 1–2), Cultist, Spitter.
- Between waves nothing is restored except DD2's end-of-battle cleanup above. HP, stress and Death's Door carry over.

### Changes from the approved draft, and why

- **Cultist's skill is called Curse** (was Hex), so the log doesn't show two different skills named Hex.
- **Enemy HP and damage went up** (Ghoul 20→26 HP, Claw 3–6→4–7; Spearman 18→24, Thrust 4–7→5–8; Spitter 12→15; Cultist 14→18, Curse 2–3→2–4; Brute 60→75, Smash 6–10→8–12, Sweep 3–6→4–7) and the **Brute got 1 Death Armor**. With the draft numbers a scripted sensible player won every run.

### Balance snapshot

**The bot.** Every simulated fight, `--autoplay` and the map auto-player use `AutoPlayer.best`. It scores every usable skill on every target by the HP it is worth and picks the best. The scoring counts:
- damage, plus the share of the enemy's threat it wears down, and kills
- healing where HP is missing, more on Death's Door, and stress relieved
- Block, Dodge, Stealth and Guard by the hits they are likely to stop (Guard only when the guard is the sturdier one)
- Stun, Blind and Weak by the enemy turns they spoil; Vulnerable and Combo by the party's next hits
- buffs, debuffs, DoTs after resistance, and costs like self-damage, stress, or moving out of range
- moves and swaps by the attacks they open up against living enemies
- ending the fight, which a kill of the last enemy is worth well above its costs

Past round 20 everything but damage, costs included, counts for a third, so long fights end instead of turning into a stand-off of defending.

It replaced a "sensible" bot that only healed allies under 50%, calmed stress of 5 or more, and otherwise hit hardest. That bot never used tokens, Guard, moves or Combo, so kits built on them looked weak.

`tests/test_simulation.gd` plays full sandbox runs with the bot and a random player as a guard against stalemates. A human should land between the two.

`scripts/balance.ps1` plays whole missions with random parties of the cast and the map auto-player. With level-1 heroes at Apprentice they finish about 71% of short missions, 63% of medium and 43% of long (heroes without trinkets). The old bot finished 46%, 28% and 20%. None of 720 missions had a fight reach the 60-round cap. The sweep's rare stalls are a lone hero left at rank 1 with no attack from there, against an enemy that heals faster than it's hurt. Veteran and Champion missions with unupgraded heroes are far lower, which is intended: they need levels and gear.

## Balance tool

A dev app inside the game (`src/balance/`) for designing and balancing heroes, enemies, bosses and items. It opens with `-- --balance`, or from a title-screen button that only shows when running from the project folder, and is left out of exports. Desktop only.

- **Why in the game, not an editor plugin:** the Godot editor isn't part of the workflow. All of it is GDScript on the real content and combat code.
- **What it edits:** every field of the heroes, enemies (bosses included), trinkets and talents, and every encounter's lineup. Forms are built from each resource's exported fields, so new fields, and new kinds of equipment later, get an editor without extra work. `campaign_rules.gd`, events and regions are out of scope, except listing content in the campaign.
- **Editing:** a table per kind (Heroes, Enemies, Encounters with a Fight / Elite / Finale / Boss filter, Trinkets, Talents) beside a form for the selected one. A hero's form links its talent files, three per row; a talent is edited in its own form, from the Talents table. Units expand into their skills. Undo and redo cover the session; git is the long-term history. Save writes the changed `.tres` files only, and a file saved unchanged comes out byte-identical. Quitting or leaving with unsaved changes asks first.
- **New content:** Duplicate copies a hero, enemy, encounter or trinket (not a talent, which belongs to a row of three) with its own skills and effects (art and listed units are shared) and a new id. List in campaign puts it in Starting Heroes or Recruits, a region's fights, elites, finales or boss, or the trinket list. Ids lock once saved, because saves refer to them. Deleting stays manual.
- **Numbers on paper** (`BalanceStats`), live as you edit, sortable, tinted by rank within their group:
  - **Heroes and enemies:** HP, speed, size, resistances, the most expected damage in one turn, damage, heal and stress per round, the best chance a stun or move sticks, and the ranks used and reached.
  - **Skills:** the damage roll, crit, cooldown and uses, expected damage per use (crits, every target, DoTs after resistance), and the per-round numbers with its cooldown.
  - **Encounters:** totals of HP, damage and stress per round, the best stun, and average speed.
  - **Trinkets:** rarity, class, price, whether listed, and their effects in words.
  - **Talents:** class, the level whose row holds them, effects in words and flavour; dimmed when no hero's rows hold them.
  - **Assumptions:** base heroes (level 0, rank-1 skills, the first 5 skills) against Apprentice enemies, over a 6-round fight. A unit uses its best ready skill each turn, so cooldowns and use limits count. Resisted effects are measured against the other side's average resistance. Effects that need a token or tier tokens (Stun vs Combo) don't count.
- **Sweeps** (`BalanceSweep`, ▶ Run): simulated fights of the content on screen, saved or not, played by [the bot](#balance-snapshot) at one preset.
  - **The sweep:** 100 fights per encounter (Quick). Each is a random party of four with five random skills each, at least one of them an attack when the hero has any, lined up by the average rank their skills are used from. At presets with trinkets, each hero also wears two random trinkets they may wear, drawn with the tier's drop odds. At presets with talents, each takes a random talent on every row their level opens, drawn with dice of their own so the rest of the fight draws as it would without.
  - **Paired fights** for every hero skill (20 pairs at Quick), trinket (16 pairs) and talent (16 pairs), on random elites, finales and bosses. Each pair is the same party, seed and encounter, once with it and once without: the skill is swapped for another of the hero's, the trinket taken off, the talent swapped for another of its row (the choice a player makes), whatever the preset's level. The difference in wins and in party HP lost is what it is worth. HP lost is the sharper of the two, since most fights are won.
  - **Fixed seeds:** each fight's seed comes from what it measures and its number, so runs of the same content share their dice, and differences come from the changes.
  - **Run size:** Quick is about 10,700 fights in about 25 s. Thorough plays 4 times as many, in about a minute and a half.
  - **Worker processes:** GDScript slows down on several threads in this build (two threads take 5 times as long as one), so the fights run in headless Godot processes (`tools/balance_worker.gd`), one per processor but two. The sweep saves its copy of the content to `user://balance_runs/`, each worker rebuilds the same plan from it, and the app reads their results back.
- **Results** sit in columns before the numbers on paper. Hovering a cell gives its margin of error.
  - **Heroes:** win rate with them against the cast's average, their HP lost and deaths.
  - **Skills:** with against without, and how often the bot picked them.
  - **Enemies:** win rate and HP lost in fights against them, and their skills' use.
  - **Encounters:** win, HP lost, stress, deaths, rounds and their target.
  - **Trinkets:** with against without.
  - **Talents:** with against another of their row, on their hero.
  - **Out of date:** results grey out once anything is edited, and come back when undo returns to the content they were run on. Each change gives the content a new state; undo gives the old one back.
  - **Pin:** keeps a run, and later runs show their change against it.
- **Presets and targets** live in `content/balance_targets.tres`, edited from the Targets button and left out of exports.
  - **Presets:** Base (level 0, rank-1 gear and skills, no trinkets or talents), Apprentice (level 1, trinkets), Veteran (level 5, rank 3, two talents, Veteran enemies), Champion (level 9, rank 5, four talents, Champion enemies). Each preset can leave talents out.
  - **Default targets at Base:** bosses won 40–46%; HP lost 25–35% to normal fights, 50–60% to elites and 40–50% to finales.
  - **Flags:**
    - an encounter outside its target
    - a hero more than 5 points from the cast's average win rate
    - a skill, trinket or talent whose win difference strays more than 8 points, or whose HP-lost difference strays more than 4, from its group's middle and beyond its margin of error
- **From the terminal:** `tools/balance_probe.gd` runs the same sweep and prints the encounters, heroes, and the skills, trinkets and talents that stand out.
- **Arena** (`BalanceArena`, the Arena tab): one hand-picked fight, played over and over by the bot.
  - **Setup:** up to four heroes in rank order, each with the skills they take (five at most), two trinkets and a talent per row (any row, whatever the preset's level, to try one early), against an encounter at a preset. Sliders set the party's starting HP and stress. The setup is kept in `user://balance_arena.json` between sessions.
  - **Live:** 200 fights (about 5 s) play on the main thread, a few each frame, and start again 0.4 s after any change, to the setup or to the content in the form. The fights use the content as it stands, so they need no copy.
  - **Results:** win rate with its margin, HP lost, deaths, rounds and stress, each hero's HP lost and deaths, and how often the bot used each skill. A line compares with the last run that finished before the latest change. More plays 1,000 fights.
  - **Watch** opens the fight in the real combat screen, played by the bot; **Play it** lets you play it yourself. The screen opens over the tool rather than replacing it, so unsaved edits and the undo history stay. It plays the fight with new dice each time (R again), and Esc (once any unit's details are closed and no skill is chosen) or the end panel goes back. The combat screen knows the Arena only as an object with `title`, `bot_plays` and `battle(seed)`, so the game doesn't depend on the tool, which isn't exported.

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
- Town features after v1, roughly in DD1's priority: quirks, with their Abbey and Tavern side effects, and the Sanitarium; diseases; quest goals beyond winning every fight; town events; a dungeon map with supplies, light and camping (Survivalist).
- Relationships, Paths, combat items, skill loadouts.
- Real art, audio, controller support, multiple save slots.
- DD2 screen features waiting on mechanics or writing: the Flame emblem at the top, speech-bubble barks.
