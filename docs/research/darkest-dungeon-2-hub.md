# Darkest Dungeon II hub and between-run progression: design reference

Researched on 2026-10-27 for the Godot project `darko-dungo`. The combat already mirrors Darkest Dungeon II (see [darkest-dungeon-combat.md](darkest-dungeon-combat.md)), and the town loop follows Darkest Dungeon 1 (see [darkest-dungeon-town.md](darkest-dungeon-town.md)). This document covers **Darkest Dungeon II's (DD2) progression outside combat**, as ideas for more town buildings and upgrades:

- the **Altar of Hope**, where Candles of Hope are spent between runs;
- the **Stagecoach** and its upgrades;
- the **Inn** and inn items;
- **combat items**;
- the **Kingdoms** mode, DD2's only mode with a persistent roster and upgradable buildings.

It ends with ideas for this project.

## How to read this document

Every claim is tagged with its source:

| Tag | Meaning |
|---|---|
| **(wiki)** | darkestdungeon.wiki.gg, the maintained wiki. **Default "truth"** where it gives a number, unless a later patch changed it. |
| **(patch)** | Red Hook's own patch notes and news posts (darkestdungeon.com, Steam announcements). Authoritative for *changes*. The Sept 2022 Altar of Hope notes were read in GameBanshee's reproduction, marked "(patch, via GameBanshee)". |
| **(fandom)** | darkestdungeon.fandom.com. Cross-check only. |
| **(community)** | Steam discussions and achievement guides. Anecdotal. |
| **(inferred)** | My own reading or arithmetic. Treat as a design suggestion, not fact. |

No DD2 game-data files were consulted, so the DD1 document's **(data)** tag does not appear. **Conflict** marks places where sources disagree; both values are given.

> **Version caveat.** DD2 is still being patched. The 2.04.84350 hotfix (6 April 2026) raised several Candle rewards. The wiki's Candles of Hope page still shows the old values (section 1.7). Treat other wiki numbers as possibly one patch behind.

> **Source access.** WebFetch summarises pages and dropped numbers, so most wiki.gg pages were read verbatim in the browser pane. wiki.gg's full-text search and SteamDB showed a Cloudflare check and were not used. darkestdungeon.com returned 404 to WebFetch but loaded in the browser. Fandom returned HTTP 402 to WebFetch but loaded in the browser. Recent Steam patch notes came from Steam's public news API.

> **Scale note.** DD2 stress runs 0–10 and DD2 HP and damage are on the same scale as this project's combat, so **DD2 numbers port 1:1**. That is unlike DD1's, which are divided by 10.

> **Terms.** A DD2 **run** (an "expedition") is about four **regions**, each a road of nodes ending at an **Inn**. "Lasts 1 region" means until the next inn. DD2 has four currencies:
> - **Relics** buy consumables;
> - **Baubles** buy equipment;
> - **Candles of Hope** buy meta-progression;
> - **Inn Materials** buy inn upgrades, in Kingdoms only.
>
> (wiki)

---

## TL;DR: the numbers you will most likely need

```
Candles of Hope  = meta currency. Per run: Valley 2; regions 1/2/3 = 12/24/36 (was 8/20/36);
                   lair bosses 8/16/24 (was 4/10/20); entering the Mountain 10 (was 6);
                   Confession boss 20; +2 per surviving hero. Nodes: 25-77% chance of +1.   (wiki + patch Apr 2026)
Altar of Hope    = Intrepid Coast (coach and node bonuses, 522 C), Living City (one track per hero,
                   53 or 61 C each), Working Fields (item pools, ~364 C), Timeless Wood (Memories),
                   plus cosmetics and The Dam (run modifiers). Full Altar ~1,570 C (inferred).    (wiki)
Item unlocks     = random within a tier; finish a tier to open the next. Candles per item:
                   trinkets 1/2/3, combat items 1/2/4, stagecoach items 2/3/4, inn items 1/2/4.    (wiki)
Stagecoach       = starts with 2 Wheels, 2 Armor. Wheels 1/2/3+: +20/33/50% traveling heal.
                   Armor 1/2/3+: Block at combat start 33%/66%/100% per hero.
                   Gear slots 1 -> 4, plus one Flame, one Trophy and one Pet slot.
                   Repair 8 Baubles per token (12 in Kingdoms).                                   (wiki)
Inn (Confessions)= ends every region. Heal to 25/50/100% HP and -1 to -3 stress, by inn.
                   Shop, Mastery Trainer, Wainwright; relationships are rolled on leaving.        (wiki)
Inn items        = usable only at inns. Buffs last 1 region (3 in Kingdoms).
                   Food: once per hero per region, +10..30% max HP.
                   Stress items: -1..-6 stress (the Jester's signature item -10).
                   Affinity items: 67/75/80% positive, else negative; a gain crits (x2) 10% of the time.
                   ~5% (8% for drink) chance of a themed quirk. No per-inn cap is documented.     (wiki)
Affinity         = 0-20 per pair, start 9. On leaving an inn: 9-13 -> 5% pos / 5% neg;
                   14-16 -> 33% pos; 17-19 -> 65%; 20 -> 90% (mirrored for low affinity).         (wiki)
Combat items     = 1 slot per hero, free action, stacks of 1-4. A full stack costs 12 Relics.     (wiki)
Kingdoms inns    = 5 trees: Barracks, Provisioner, Mastery Trainer, Wainwright, Physician.
                   Minor node 5, major 10, capstone 40 Inn Materials.
                   One advanced tree and one capstone per inn.
                   A hero stationed at an inn, per day: +20% HP, -1 stress, -10% fatigue.        (wiki)
Kingdoms defence = sieges count down in days; stationed heroes and militia defend.
                   A lost inn becomes a camp; every hero takes +10% fatigue, +2 stress and a 25%
                   chance to lose a positive quirk. Loss limit 60/50/40/30% of inns.             (wiki)
```

---

## 1. Altar of Hope (Confessions mode)

Every Confessions run "begins and ends at the Altar of Hope". It is DD2's only between-run hub: no roster, no gold, just Candles spent on permanent unlocks. (wiki) It replaced an earlier "Hope score" system in the Altar of Hope update, build 0.16.38304, on the experimental branch on 29 Sept 2022. The update reset item unlocks and hero availability and gave every player 20 Candles. (patch, via GameBanshee)

### 1.1 Areas at a glance

| Area | What it unlocks | Candles to complete |
|---|---|---|
| **The Intrepid Coast** | Stagecoach upgrades, bonuses on arriving at node types, coach skins, pets, Infernal Flames (1.2) | 144 + 131 + 92 + 155 = **522**, plus the Infernal Flame line (cost not given) (wiki; sum inferred) |
| **The Living City** | Heroes, hero paths, permanent hero stat buffs, hero trinkets, signature inn items (1.3) | 53 per starting hero, 61 per unlockable hero, 45 for the Bounty Hunter (wiki) |
| **The Working Fields** | Adds trinkets, combat items, stagecoach items and inn items to the loot and shop pools (1.4) | About **364** (inferred from item counts × tier costs) |
| **The Timeless Wood** | Memories: small passives that let a hero persist between runs (1.5) | Not stated |
| **The Mountain** (in the Altar) | Cosmetics: 3 weapon skins and 3 outfits per hero, one per path | Not stated (wiki) |
| **The Recollection** | Read-only list of everything unlocked | — (wiki) |
| **The Dam** | Toggles for run modifiers, added in 2025 (1.6) | No cost given; some toggles need acts beaten (wiki; patch Nov 2025) |

- The area names echo DD2's regions: Living City is the Sprawl, Timeless Wood the Tangle, Intrepid Coast the Shroud, Working Fields the Foetor. (wiki)
- **Skills are not bought at the Altar.** Each hero has 5 starting skills and 6 more, 11 in all. In Confessions the extra 6 unlock at **Shrine of Reflection** nodes during runs. Each skill can be **mastered** once with Mastery Points at an inn's Mastery Trainer. (wiki) The Bounty Hunter is the exception: his skills come from his Living City track. (wiki)
- **Rough total:** 522 (Coast) + 684 (Living City, base-game heroes: 4 × 53 + 7 × 61 + 45) + 364 (Fields) ≈ **1,570 Candles**. Add 159 for the three DLC or quest heroes. This excludes the Infernal Flame line, Memories and cosmetics. (inferred)

### 1.2 The Intrepid Coast: coach and node upgrades

The wiki gives only line totals, not per-step costs. (wiki)

| Line | Total | Upgrades |
|---|---|---|
| **Journey** | 144 | **Capability:** +1 stagecoach equipment slot (×3, so 1 → 4). **Packing:** +2 inventory slots (×3). **Scavenging:** more loot from road debris (×3). **Charity:** higher chance of Candles at map locations (×3). |
| **Resourcefulness** | 131 | Bonuses on arriving at a node type: **Wealth** (Valley Inn: +24 Relics, +20 Baubles; ×2). **Bartering** (Hoarder: +12 Relics). **Sanctuary** (Field Hospital: +10% HP, −1 stress). **Curiosity** (Academic's Study: free random combat item). **Efficiency** (Academic's Cache: free random item). **Refreshment** (Oasis: free Mineral-Rich Spring Water). **Invigoration** (Watchtower: all heroes +1 SPD until the next inn). **Respite** (Inn: free random inn item). |
| **Renown** | 92 | Nine cosmetic stagecoach skins |
| **Companionship** | 155 | The Pet slot plus 10 pets (section 2.5) |
| **The Infernal Flame** | ? | Nine "hard mode" Flames (section 2.4) |

- **Conflict (Wealth):** wiki.gg says "Valley Inn: +24 Relics, +20 Baubles (2 times)". Fandom says "Valley Hoarder: +12 Relics, +15 Baubles", then "+12 Relics, +20 Baubles". (wiki/fandom)
- **Conflict (max Wheels and Armor):** the Stagecoach page says the Altar raises max Wheels and Armor by 1 each. The Intrepid Coast page lists no such upgrade. (wiki)

### 1.3 The Living City: heroes, paths, stats, trinkets, signature items

Each hero has one track. Candles spent along it unlock:

- 3 hero-specific trinkets;
- 3 hero paths (sub-classes, on top of the default Wanderer path);
- permanent stat buffs;
- at the end, the hero's **signature inn item** (section 3.6).

(wiki)

| Hero | Unlock | Track total | Permanent stat buffs on the track |
|---|---|---|---|
| Highwayman | free | 53 | +5% Deathblow RES ×3; +10% Bleed, Stun and Disease RES |
| Man-at-Arms | free | 53 | +4 max HP; +5% Deathblow RES ×3; +10% Stun RES ×2 |
| Grave Robber | free | 53 | +1 SPD ×2; +5% Deathblow RES ×3; +10% Blight RES |
| Plague Doctor | free | 53 | +5% Deathblow RES ×3; +10% Blight, Disease and Burn RES |
| Hellion | 4 Candles | 61 | +5% Deathblow RES ×4; +4 max HP; +10% Disease RES |
| Runaway | 4 | 61 | +5% Deathblow RES ×3; +10% Burn RES ×2; +1 SPD |
| Jester | 4 | 61 | +5% Deathblow RES ×3; +10% Debuff and Burn RES; +1 SPD |
| Leper | 4 | 61 | +5% Deathblow RES ×3; +4 max HP ×2; +10% Move RES |
| Occultist | 4 | 61 | +5% Deathblow RES ×3; +10% Debuff, Disease and Burn RES |
| Vestal | 4 | 61 | +5% Deathblow RES ×3; +10% Stun, Move and Debuff RES |
| Flagellant | 4 | 61 | +3% Deathblow RES ×6 |
| Bounty Hunter | 5 (then hirable at inns) | 45 | No stats, paths or signature item; unlocks 6 skills and 3 trinkets instead |
| Duelist | *Binding Blade* DLC | 53 | +5% Deathblow RES ×3; +10% Burn, Blight and Bleed RES |
| Crusader | finish *The Lost Crusade* (*Binding Blade*) | 53 | +5% Deathblow RES ×3; +10% Stun, Bleed and Burn RES |
| Abomination | *Inhuman Bondage* DLC | 53 | +5% Deathblow RES ×3; +10% Move, Blight and Bleed RES |

(wiki)

- **Pattern:** every track is mostly death-door survival (+15–24% Deathblow RES) plus two or three +10% resistances. HP and speed are rare: +4 HP or +1 SPD, once or twice. These are small, safe buffs; the track's real reward is the trinkets, paths and signature item. (inferred)
- **Paths:** Wanderer is the default path. In Confessions a hero on the Wanderer path earns **2 Candles at the second inn**; the 2.04.84350 hotfix raised this from 1. (wiki + patch Apr 2026)
- **Conflict (unlock cost):** the wiki gives 4 Candles to unlock a hero. The 2.04.84350 hotfix says "Reduced Character Unlocked Candle cost from 8 to 5". It is unclear whether that line means hero unlocks or the in-run Bounty Hunter hire, so it is listed under Could not confirm. (wiki/patch)

### 1.4 The Working Fields: item pool unlocks

Each item category is split into **3 tiers**:

- Items unlock **at random within a tier**.
- **All items in a tier must be unlocked before the next tier opens.**
- An unlocked item joins the loot pool for future runs, and a copy goes straight into the inventory for the next run.

(wiki)

| Category | Candles per item (tier 1 / 2 / 3) | Items per tier (1 / 2 / 3) | Total |
|---|---|---|---|
| Trinkets | 1 / 2 / 3 | 30 / 25 / 18 | 134 |
| Combat items | 1 / 2 / 4 | 10 / 10 / 10 | 70 |
| Stagecoach items | 2 / 3 / 4 | 10 / 10 / 10 | 90 |
| Inn items | 1 / 2 / 4 | 10 / 10 / 10 | 70 |

(wiki costs; row counts and totals inferred from the wiki tables. The trinket tables include some DLC items.)

- **What sits in each tier** (wiki):
  - Tier 1: basic consumables (Healing Salve, Smelling Salts, Stale Bread, Whiskey Bottle) and road gear (Iron-Banded Wheels, Steel Plating).
  - Tier 3: party-wide or strongest effects (War Horn, Triage Kit, Holy Water, Roast Pig, Meditative Totem, Merchants' Guild Seal, Telescope).
- **End game.** Once the Altar is complete, leftover Candles buy random items for the next run, at prices that rise with each purchase:
  - trinkets 16 → 24 → 32;
  - combat items 6 → 8 → 12;
  - stagecoach items 16 → 24 → 32;
  - inn items 4 → 8 → 12 → 16 → 20 → 24.

  Candles can also **reroll a hero's quirks** at the Crossroads, for 6 → 9 → 12 → 16 → 20 → 24. (wiki)

### 1.5 The Timeless Wood: Memories

- A hero gains **one Memory slot** the first time they complete a Confession (a full run), up to **5 slots**. (wiki)
- A hero with at least one slot **persists**: they reappear at the Crossroads with name, cosmetics, skill loadout, paths, quirks and diseases intact. (wiki) Everyone else is a fresh hero each run. (inferred)
- After every run, won or lost, **up to 6 Memories are generated**. Each can go into any empty slot, including those of heroes who sat the run out. (wiki)
- Memories are lost on death, or when abandoning a run anywhere except at an inn. (wiki)
- **The 20 Memories** (wiki):
  - Stats: +10% max HP; +1 SPD; +5% crit; +10% damage; +10% stress RES; +10% Resolute chance; +10% healing given; +10% Debuff RES piercing; +1 Regeneration dealt.
  - Resistances: +15% Move, Bleed, Blight, Burn or Stun RES; +25% Disease RES; +10% Debuff RES.
  - Conditional:
    - heal 10% on entering Death's Door, once per region;
    - −1 stress when missed (25%);
    - +5% max HP for the run per food item eaten;
    - +1 Blight, Bleed or Burn dealt when a matching item tag is equipped.
- **Conflict:** the Timeless Wood page says players "spend Candles of Hope to apply Memories", but its body describes Memories as generated for free. The 2022 preview said survivors of the final boss "can gain one additional Memory". (wiki; patch, via GameBanshee)

### 1.6 The Dam: run modifiers

Toggles added to the Altar in 2025 (patch Nov 2025). The wiki says there are 4, then lists 6:

- **Retreat button.** Retreating costs +2 Loathing and +2 stress to all.
- **Selling to the Hoarder.** Needs Act 5 beaten.
- **The Mountain reachable from any inn**, with a trophy. Needs Act 5.
- **More battle modifiers.**
- **Extended Acts 1 and 2.** Needs both beaten.
- **Death can spawn without the Flagellant.** Needs Death beaten once.

(wiki)

### 1.7 Earning Candles of Hope

**Region and boss rewards.** These are banked when the party enters the inn after the region.

| Source | Wiki (current page) | Hotfix 2.04.84350 (6 Apr 2026) |
|---|---|---|
| The Valley (tutorial region) | 2 | — |
| The Sluice (optional mini-region) | 4 | — |
| 1st / 2nd / 3rd region completed | 8 / 20 / 36 | **12 / 24 / 36** |
| Lair (region boss) defeated | 4 / 10 / 20 | **8 / 16 / 24** |
| Entering the Mountain ("Facing your Failures") | 6 | **10** |
| Defeating the Confession boss | 20 | — |
| Each surviving hero at the end | 2 | — |
| Academic's Honorarium | — | 10 → 15 |
| Wanderer-path hero, at the 2nd inn | 2 | 1 → 2 |

(wiki; patch Apr 2026. **Conflict:** the wiki page still shows the pre-hotfix values.)

**Other sources:**

- **Nodes:** a chance of +1 Candle per node, raised in three steps by the Intrepid Coast's Charity line:
  - 25 / 30 / 35% at the Hoarder, Field Hospital, Academic's Cache, Watchtower, Oasis and The Desperate Few;
  - 40 / 45 / 50% at Resistance encounters, Oblivion's Ingress, Academic's Study and Shrines;
  - 67 / 72 / 77% at Lairs and Creature Dens.

  (wiki)
- **Region goals:** a 20% chance of 3 (57%), 4 (29%) or 5 (14%) Candles. (wiki)
- **Hero goals:** every Wanderer gives 2 at the second inn. (wiki)
- **Carrying:** goal and node Candles go into the **inventory** and must be carried to the end of the run. (wiki)
- **Ending early:** under the 2022 rules, ending at an inn keeps what you have, while a mid-region wipe or abandon reduces the total. Reaching the Mountain keeps everything, even on a loss. (patch, via GameBanshee)
- **Rough income** (inferred):
  - A full winning run after the hotfix: 2 + 12 + 24 + 36 + 10 + 20 + 8 ≈ **112**, plus lairs, nodes and goals, so roughly **120–150**.
  - A run that dies in region 2: about **15–25**.
  - The whole Altar is therefore about **10–15 winning runs**.

---

## 2. The Stagecoach

The party's vehicle; DD2's "town on wheels". It is upgraded at the Intrepid Coast, and equipped and repaired only at an inn's **Wainwright**. (wiki)

### 2.1 Wheels and Armor

| Tokens | Wheels: traveling heal bonus | Armor: at each combat start, per hero |
|---|---|---|
| 1 | +20% | Block (33% chance) |
| 2 | +33% | Block (66%) |
| 3 or more | +50% | Block (always) |

- **Start of a run:** 2 Wheels and 2 Armor. The Altar raises each maximum by 1 (but see the conflict in 1.2), and items raise them further. (wiki)
  - **Iron-Banded Wheels:** +2 max Wheels, +1 Wheel on entering each region. (wiki)
  - **Steel Plating:** the same for Armor. (wiki)
- **Damage:** some roads destroy one Wheel or Armor token. Repairs cost **8 Baubles** per token at the Wainwright (**12** in Kingdoms). (wiki)
- **Zero tokens:** once all Wheels or all Armor are gone, Pillagers may ambush the party. (wiki)
- **Kingdoms** starts with 3 of each. (wiki)

### 2.2 Slots

- **Equipment:** 1 slot at first; Capability adds 3 more, for 4. (wiki)
- **Special slots,** one item each (wiki):
  - **Flame**, the coach's lantern (2.4);
  - **Trophy**, won from lair bosses (2.6);
  - **Pet** (2.5).
- **Restrictions:**
  - Items can be swapped only at an inn and stay locked until the next inn. (wiki)
  - Pets and Infernal Flames can't be removed for the rest of the run. (wiki)
  - Flames and pets are bought only at the run's first inn. (wiki)
- **Inventory** is shared by all items. It grows with Packing (+2 ×3), the Storage Trunk (+3) and Spacious Storage Trunk (+6), and the Harvest Child's trophy (+25). Kingdoms starts at **33 slots**. (wiki) The Confessions base size is not documented.

### 2.3 Stagecoach equipment

About 45 items in seven "gear" families. Each costs 25 or 40 Baubles. (wiki)

| Family | What it does | Examples |
|---|---|---|
| **Road** | Wheels, Armor, Flame drain, regional buffs | Iron-Banded Wheels and Steel Plating (above); Iron Brazier (−33% Flame drain); **Carriage Lamps** (+33% Loathing RES); Wagon Jack (extra action after Repair); Almanacs (+2 SPD, +15% DMG, +10% stress RES in one region; all four give +10% max HP at the Mountain too) |
| **Medical** | Healing and passive cures | Medical Equipment (+20% traveling heal); Operating Table (10% chance to cure a disease after each location); producers (below) |
| **Food** | Food stacks and producers | Icebox (+2 food per loot; +1% Disease RES per food carried); Food Barrels (+10% Resolute while carrying 10+ food); Stew Pot; Griddle; Pot and Still |
| **Tinker's** | Producers and loot | Explosives Magazine; Tinker's Bench; Trapmaker's Kit; Blueprint Tubes (+1 to every producer); Assay Gear (+4 Relics per loot) |
| **Luxury** | Economy and relationships | Strongbox (+12 currency per stack); Merchants' Guild Seal (−20% all prices); Trinket Organizer; Tea Service (+6% positive relationship chance); Windchime (−1 stress to a random hero after each location) |
| **Scouting** | Reveal node types and routes | Telescope (+33% routes); Crows' Nest (+20% locations); maps that double one node type's scouting |
| **Generic** | Inventory | Storage Trunk (+3), Spacious Storage Trunk (+6) |

- **Producers** are the most "building-like" items: before each location they have a 20–25% chance to make consumables. For example (wiki):
  - Pot and Still → whiskey;
  - Alembic and Retort → concoctions and powders;
  - Chirurgeon's Mixing Kit → restoratives;
  - Mortar and Pestle → poultices;
  - Stew Pot → Invigorating Stew;
  - Griddle → Flapjacks.

  **Companion items** raise their output by +2 and their stack size by +6: Bottle Case, Medicine Chest, Compress Kit. (wiki)
- **Conflicts** (wiki vs wiki):
  - The Stagecoach Items page and the Working Fields page disagree on some prices: Collector's Chandelier and Pot and Still are 25 on one and 40 on the other.
  - Compress Kit: poultice stacking on one page, a copy of Bottle Case's text on the other.
  - "Operating Table" on one page is "Chirurgeon's Table" on the other.

### 2.4 The Flame: the coach's lantern

- **The meter:** the Flame runs 0–100, starts each region at 100, and drains while traveling. (wiki)
- **Bands:** Bright 100–76, Dim 75–51, Shadowy 50–26, Darkness 25–1, Black 0. Lower bands give enemies "Enemy Advantage", +15 / 33 / 100%, and cost Death's Door resistance. (wiki)
- **At 0:** a Cultist ambush. Below 30, Shambler ambushes are possible. (wiki)
- **Restoring it:** assistance encounters give +15–30; the "A Glimmer of Hope" combat item gives +15. (wiki)
- **The Flame slot** holds either:
  - the **Radiant Flame**: −25% Flame drain and 2–5 random buffs, growing with each consecutive failed run (a pity mechanic);
  - one of nine **Infernal Flames**: hard-mode lanterns, +15% Candles earned.

  (wiki)
- **No separate "lantern" upgrade exists** in current sources. The light-related upgrades are the Flame slot, Carriage Lamps, the Iron Brazier and the Moonlight Lantern (*Inhuman Bondage*; −33% drain, −50% max Flame, no Flame-out ambushes). (wiki)

### 2.5 Pets

- **Getting them:** in Confessions, pets are unlocked by Companionship and bought at the first inn. (wiki)
- **Most pets scale with one gear family:** they give a bonus per equipped coach item of that family. (wiki)
  - Orphan Wolf Cub: +5% stress RES per Luxury item, and +10% positive relationship chance.
  - Pygmy Pliskin: +10% healing received per Medical item, and a random hero heals 10% after each location.
  - Reanimated Rabbit: +1 SPD per Food item.
  - Unnatural Owlet: +5% Debuff RES piercing per Tinker's item, and producers make more.
  - Mucilaginous Slime: +5% Debuff RES per Road item, and more road debris.
  - Shrieker Chick: +2% crit per Scouting item, and +2 Baubles per loot.
- **Other pets** (wiki):
  - Larval Carrion Eater: heals on killing blows.
  - Crimson Tick: may produce a combat item on killing blows.
  - Shambler's Spawn: special; unlocks Cultist trinkets.
  - Purloiner Felid (*Inhuman Bondage*): gives the Cat Food combat item.
- **Design note:** this makes the coach a build. The pet rewards committing all four slots to one family. (inferred)

### 2.6 Trophies

Trophies come from lair bosses; each boss has 3 possible trophies. Examples (wiki):

- +25 inventory slots;
- +2 stacking for all combat items;
- −75% trinket prices;
- +100% scouting;
- +50% healing received, but −25% Death's Door RES.

Each is a strong, usually double-edged, run-long modifier. (inferred)

---

## 3. The Inn and inn items

### 3.1 What an inn is (Confessions)

Every region ends at an inn. (wiki) Each inn has three services and some other features:

- **Mastery Trainer:** spend Mastery Points to master skills.
- **Provisioner:** shop for trinkets, coach items, combat items and inn items.
- **Wainwright:** repair the coach and swap coach items.
- **The only place inn items can be used.**
- **Travelogue:** the region's quirks, diseases and deaths.
- **Region selection:** choose the next region from 2–3, each with a modifier and a goal.
- **Embark screen:** reveals the relationships formed on leaving.

Abandoning a run at an inn is a softer failure than dying: heroes keep their Memories. (wiki)

**Each of the ~23 inns has its own passive effect** (wiki):

- **Healing and stress:** most heal to 50% HP and remove 1 stress. The best (Butcher's Feast, Good Doctor, Roaring Hearth) heal to 100% and remove up to 3. The worst (Hag's Cauldron, Tempting Goblet) heal only to 25%; the Goblet adds +2 stress on entering the next region.
- **Themed extras:**
  - extra shop stock: Butcher's Feast (food), Station House (coach gear), Nomad's Wagon (trinkets);
  - half prices: Miller's Bounty (combat and inn items), Station House (coach gear), Nomad's Wagon (trinkets);
  - diseases cured: Good Doctor;
  - +2 Mastery Points: Olde Guild Hall;
  - quirk odds: Keening Well (more good), Limping Mule (more bad);
  - relationship odds: Roaring Hearth +20% positive and −20% negative; Hag's Cauldron −10% / +10%;
  - +20% damage for one enemy type, or +5% crit until the next inn.

### 3.2 Inn item rules

- **Where:** only at an inn (or a camp in Kingdoms). (wiki)
- **Effects:** HP, stress, affinity, region-long buffs, and removing diseases or quirks. (wiki)
- **Duration:** most buffs last **1 region** in Confessions and **3** in Kingdoms. Food lasts 1 region in both, with a few exceptions. (wiki)
- **Food** can be eaten by each hero **once per region**. The Roast Pig is deliberately not tagged as food, so it can be eaten on top of food. (wiki)
- **Targets:** one hero, two heroes (a pair), or the whole party. Many items list quirks that **block** them, such as Resolute blocking whiskey. (wiki)
- **Side effect:** most items have a **5% chance to add a quirk** from a themed pool; whiskey and The Wine have 8%. (wiki) This is DD2's version of DD1's Tavern and Abbey side effects. (inferred)
- **Where items come from:**
  - road loot;
  - combat rewards;
  - The Hoarder and Field Hospital nodes;
  - the inn's shop;
  - coach producers;
  - in Confessions, unlocking at the Working Fields for 1–4 Candles.

  (wiki)
- **Prices:** Relics, 8–16 for most; only some items show a price. (wiki)
- **How many per inn:** **no cap is documented** (see Could not confirm). A Steam post from May 2023 says the same item could be applied to one hero repeatedly and the buffs stacked. (community)

### 3.3 Inn items by category

The wiki's tags are No Tags, Book, Poultice, Restorative, Food, Concoction and Whiskey. The tables below regroup them by purpose (inferred).

- Pair = 2 heroes.
- "+/−" = positive / negative affinity pips.
- RS = "Round Start" token chance, for 1 region.

**Food (max HP for 1 region; once per hero per region)**

| Item | Target | Price | Effect |
|---|---|---|---|
| Slime Mould | 1 | — | +10% max HP; 5% Dysentery, 5% Robust quirk |
| Stale Bread | 1 | 8 | +20% max HP |
| Apples & Cheese | 1 | 12 | +20% max HP, +5% Debuff RES |
| Flapjacks (Griddle) | 1 | — | +20% max HP, +5% DoT RES |
| Steak & Spuds | 1 | 16 | +30% max HP, −1 SPD, +10% Move and Disease RES |
| Tinned Delicacies | 1 | — | +30% max HP, +10% to seven resistances |
| Invigorating Stew (Stew Pot) | Party | — | +20% max HP, +1 SPD, +10% Stun and Disease RES |
| Roast Pig (not tagged as food) | Party | — | −2 stress; +1 affinity for every hero pair |

**Drink (stress and affinity, with risk)**

| Item | Target | Effect |
|---|---|---|
| Whiskey Flask | Pair | +1 affinity; 8% quirk |
| Whiskey Bottle | Pair | −1 stress; 67%: +3 affinity, 33%: −2 affinity; 8% quirk |
| Whiskey Barrel | Party | −1 stress; 67%: +3 affinity, 33%: −2 affinity (each pair); 8% quirk |
| The Wine | Pair | −3 stress; +2 affinity; 8% quirk |

**Entertainment and games (pair or party affinity, small combat buff)**

| Item | Target | Effect |
|---|---|---|
| Playing Cards | Party | 75%: +1 affinity, 25%: −1 |
| Dartboard | Pair | −1 stress, +2% crit; 75%: +1 affinity, 25%: −1 |
| Boxing Gloves | Pair | −1 stress, RS Strength 5%; 75%: +1 affinity, 25%: −1 |
| Knotted Tug Rope | Pair | RS Strength 5% |
| Speed Bag | 1 | RS Dodge 5% |
| Candles & Chocolate | Pair | −1 stress; up to +3 affinity |
| Pipeweed | Pair | −2 stress, −1 SPD; +1 affinity |

**Books and songs**

| Item | Target | Effect |
|---|---|---|
| Book of Bawdy Tales | 1 | −6 stress; 8% Sunny Disposition quirk |
| Poetry | Pair | −4 stress; +1 affinity |
| Book of Creative Insults / My Time in the Desert | 1 | RS Taunt / RS Stealth 5% |
| Song of Amorous Ballads | Pair | 80%: +3 affinity, 20%: −1 |
| Songbook of Touching Dirges | Party | **+1 stress**; 80%: +2 affinity, 20%: −1 |
| Songbook of Rousing Tunes | Party | −1 stress, +2 SPD |

**Comfort, faith and tools**

| Item | Target | Effect |
|---|---|---|
| Whittling Tools | 1 | −3 stress |
| Mop and Bucket | 1 | RS Strength and Dodge 5%; 67%: −3 stress, **33%: +2 stress** |
| Meditative Totem | 1 | −2 stress; 67% remove the oldest negative quirk |
| Holy Beads / Blasphemous Idol | 1 | One random buff: RS Block, Dodge, Strength or Crit 5%, or +3 SPD |
| Armor Repair Kit / Whetstone | 1 | RS Block+ / RS Crit 5% |
| Ceremonial Drum | 1 | +40% Move RES |

**Medical (cures, resistances, healing)**

| Item | Target | Price | Effect |
|---|---|---|---|
| Leeches | 1 | — | Remove disease |
| Wild Tea | 1 | — | Remove a negative quirk; 25% also removes a positive one |
| Orbitoclast | 1 | — | Remove **all** negative quirks; −10% max HP |
| Stitching Kit | 1 | — | Heal 50% HP |
| Calming Incense | Pair | 8 | −2 stress |
| Poultices (Clarifying, Clotting, Impermeable, Soothing) | 1 | 8 | +40% Stun or +25% Bleed / Blight / Burn RES |
| Stimulating Poultice | 1 | 8 | +4 SPD |
| Restorative Herbs | 1 | 8 | +10% traveling heal, +20% healing received |
| Wax Inoculant | Party | 12 | +33% Disease RES |
| Nightshade Concoction | 1 | 12 | +20% Deathblow RES |

(wiki, Inn Items and Working Fields pages)

- **Conflict:** the wiki's Relationships page lists different numbers from the Inn Items page:
  - Whiskey Bottle −2 stress, 67/33 for ±1 pip;
  - Whiskey Barrel −2 stress, 75/25;
  - Amorous Ballads and Touching Dirges 75/25 for ±2;
  - Roast Pig targets 1 hero.

  The tables above follow the Inn Items page, which the Working Fields page mostly matches and which looks newer. (wiki vs wiki)

### 3.4 Affinity and relationships

- **Scale:** each hero pair has **affinity 0–20, starting at 9**. (wiki)
- **The roll:** on **leaving an inn**, each pair rolls for a relationship. (wiki)

| Affinity | 0 | 1–4 | 5–8 | 9–13 | 14–16 | 17–19 | 20 |
|---|---|---|---|---|---|---|---|
| Chance of a relationship | 90% negative | 65% negative | 33% negative | 5% negative, 5% positive | 33% positive | 65% positive | 90% positive |

- The first inn has −10% to both chances. (wiki)
- A relationship lasts **1 region** in Confessions and **5 days** in Kingdoms. (wiki)
- **Gaining affinity** (wiki):
  - Inn items. Every inn-item gain has a **10% chance to crit**, doubling it.
  - Combat support at low stress: buffing, healing or guarding a wounded ally, relieving stress, attacking an ally's target.
  - Matching node decisions: +1 each.
  - Random road events.
- **Losing affinity** (wiki):
  - Combat reactions at high stress.
  - Disagreeing at nodes: −1 to −2.
  - Random road events.
  - In Kingdoms, the pair loses 3 when a positive relationship ends.
- **Positive relationships** (wiki):
  - **Respectful:** gives Strength and Dodge+.
  - **Hopeful:** −1 stress.
  - **Amorous:** heals 10% and cleanses DoTs.

  Each gives the partner a "Blessed" skill, plus act-outs such as follow-up attacks, interceptions and stress heals.
- **Negative relationships** (wiki):
  - **Suspicious:** Taunt and Vulnerable.
  - **Envious:** +1 stress.
  - **Hateful:** Vulnerable; may hit the partner.
  - **Resentful:** Blind and Weak.

  Each forces an unremovable "Cursed" skill on the partner.
- **Design note:** inn items are the main way to steer the roll. That is why most pair items carry a 20–33% chance of *losing* affinity: a gamble, like DD1's Tavern. (inferred)

### 3.5 Deliverables

Some inn-category items are **deliverables**: picked up during a region and handed in at the next inn for a reward. (wiki) Kingdoms adds **Rumours**, sold by the Hoarder. Each points to a node type that holds an indelible trinket. (wiki)

### 3.6 Signature inn items

The last step of each Living City track unlocks a hero-only inn item. (wiki) Examples:

- **Oddly-Tuned Lute** (Jester): the party gets −10 stress and +10% stress RES.
- **Experimental Remedy** (Plague Doctor): the party heals 100%, with a 50% chance each to cure a disease and to remove a negative quirk.
- **Morbid Joke** (Highwayman): a pair gets 80%: +6 affinity, 20%: −4.
- **War Paint** (Hellion): Strength ×2 in ranks 1–2, or Taunt ×2 in ranks 3–4, at combat start.
- **Holy Hymnal** (Vestal): −1 stress at turn start while Consecrated.

In Kingdoms, a signature item for any living hero can drop or be bought for **32 Relics**. (wiki)

---

## 4. Combat items

### 4.1 Rules

- Each hero has **one combat item slot**, holding one stack. (wiki)
- Using an item is a **free action** at the start of the hero's turn; it doesn't use the turn. No per-turn limit is stated. (wiki)
- Items **can't be changed once a fight starts**, nor between Lair fights. (wiki)
- **Stack sizes** are 1–4. (wiki)
  - Strong items stack to 1: War Horn, Triage Kit, grenades.
  - Most stack to 2.
  - Weak ones stack to 4: Laudanum, A Glimmer of Hope, Linseed Oil.
- **Price:** **12 Relics divided by the stack size, per item**, so a full stack always costs 12. A few cost double, and the Bone Saw costs Baubles. (wiki)
- **Bigger stacks:** coach items add +1 to +6 stacking for their family, and the Leviathan's "Lashing Tides" trophy adds +2 to every combat item. (wiki)

### 4.2 How you get them

- Road debris; Scavenging and some pets raise the odds. (wiki)
- Fight rewards; Assistance encounters; Academic's Studies (free with Curiosity). (wiki)
- The Rummager quirk. (wiki)
- Shops: inn, Hoarder, Field Hospital. (wiki)
- Coach producers, before each location (2.3). (wiki)
- In Kingdoms, the inn's Barracks unlocks **Signal Flares**, which summon militia (5.4). (wiki)

### 4.3 Types

| Tag | Role | Examples (stack) |
|---|---|---|
| Restorative | Heals, buffs, cleanses | Healing Salve heal 12 (2); Adrenaline Tonic heal 18, +1 stress (2); Triage Kit heal 27 (1); Smelling Salts (2); Stimulants (2); Mineral-Rich Spring Water −3 stress, heal 5 (3) |
| Concoction | Cure one DoT or Horror | Antivenom, Burn Salve (2); Laudanum −1 stress (4) |
| Woven | Cure or Immobilize | Bandages (2); Fisherman's Net (2); Milk-Soaked Linen (4) |
| Powder | Resistances, Stealth | Ablative / Clotting / Neutralizing Powders +66% RES (2); Shimmering Powder (2); Chalk Dust; Pouch of Lye |
| Flammable | Flame and Burn setup | A Glimmer of Hope +15 Flame (4); Linseed Oil Flask (4) |
| Explosive | Area DoTs | Incendiary Cocktail 5 Burn (1); Greek Fire Grenade 3 Burn to all (1); Ichor Bomb; Spore Grenade |
| Trap (Serrated) | Bleed | Scrap Grenade, Spiked Ball (1); Bear Trap, Crow's Feet (2) |
| Noxious | Resistance shred | Toxic Ichor −33% DoT RES to all (2); Death Cap Spores (2) |
| Contraption | Control | Noisemaker (Taunt ×2, Block); Pyrotechnic Dazzler; Smoke Bomb; Thunderclap Grenade (shuffles enemies) |
| Weapon | A free extra attack | Makeshift Javelin 3–6, Knockback 3 (2); Bone Saw 6–12 + Bleed (1) |
| No tag | Party buffs, utility | War Horn: party Strength ×2 (1); Holy Water: remove all negative tokens (2); Ethereal Dust: reset cooldowns (2) |
| Reusable | Cooldown instead of being used up | Tropaeum (Combo, cooldown 5); Abandoned Buckler (Guarded ×2, cooldown 5); Stratagems (move an ally, cooldown 3) |

(wiki)

---

## 5. Kingdoms: DD2's persistent-roster mode

**What it is.** Kingdoms is a **free game mode**, not DLC. It released on PC on **27 Jan 2025**, the same day as the paid *Inhuman Bondage* DLC. (patch) Red Hook's announcement describes it as defending "a network of safe haven Inns", with resources spent "to upgrade heroes and also the Inns themselves, which can be improved via extensive upgrade trees". (patch, 10 Apr 2024)

**No "home inn".** There is **no single home inn**. A campaign is a grid of inns and camps joined by regions, on one of six map layouts, and **each inn is upgraded separately**. (wiki) The campaign starts at an inn with an underground tunnel. No source gives that inn special rules. (wiki; inferred)

**Three modules:** Hunger of the Beast Clan, Secrets of the Coven and Curse of the Court. Each has its own enemy faction, quest and items. (wiki)

### 5.1 Campaign structure

- **Days:** one stagecoach move between adjacent inns or camps is one day. Days can also be passed without moving. (wiki)
- **The roster:** 12 heroes are spread over the map (4–13 in Custom). Heroes not on the coach are **stationed** where they are. (wiki)
- **Losing:** the campaign is lost on any of (wiki):
  - the day limit;
  - the inn-loss limit;
  - too many hero deaths.

| Difficulty | Day limit | Escalation 2 / 3 on day | Sieges | Hero death | Inn loss limit |
|---|---|---|---|---|---|
| Radiant | 72 | 15 / 33 | Normal | Replaced by a new hero | 60% |
| Normal | 60 | 15 / 33 | Normal | Permadeath | 50% |
| Stygian | 50 | 10 / 28 | Increased | Permadeath | 40% |
| Blood Moon | 45 | 8 / 25 | Increased | Permadeath | 30% |

(wiki)

- **Escalation** is DD2's equivalent of DD1's week-based difficulty. (wiki)
  - **Level 1:** heroes get +20% damage, +15% max HP and +10% DoT RES; −33% Flame drain.
  - **Level 2:** 2 immediate sieges; enemies +20% damage, +25% HP; +50% road fights.
  - **Level 3:** 4 immediate sieges; enemies +40% damage, +50% HP; +100% road fights.
- **Respawn option:** the hero returns with a disease, loses 2–4 skill upgrades and re-locks 1–2 skills. The coach must visit where they died. (wiki)
- **Events:** each day may bring one event, from several dozen kinds. They work like DD1's town events, but daily (wiki; comparison inferred):
  - spawn sieges, inn treasures or kill contracts;
  - +20 Inn Materials;
  - all heroes −10 stress, full heal, or full fatigue heal;
  - militia +20% HP and damage;
  - delay sieges by 3 days;
  - road and scouting modifiers.

### 5.2 Inns: stationing and services

**Stationed heroes, per day at an inn** (wiki):

- heal 20% HP;
- −1 stress;
- −10% fatigue;
- for the next region: +20% max HP, +20% damage and +2 SPD. These buffs do not stack over several days.

**Camps** are weaker: heal up to 50% HP, −1 stress, −5% fatigue. A camp has no services, only hero swaps and inn items. Arriving gives a random inn item or pet, and leaving has a 20% chance of a night ambush. (wiki)

**Services.** Red Hook's notes say "Inn functionality" is reset in a Kingdoms campaign and "accessed in new ways as you play". (patch) In practice most services must be **built** at each inn (wiki):

- The shop starts with a smaller stock than in Confessions.
- Skills can only be unlocked, mastered or path-changed at an inn that has the matching Mastery Trainer upgrade.
- The Physician offers Field Hospital services at the inn. (wiki)
- Path changes cost 24 Relics. (wiki)
- The Hoarder node buys items at 20% of price. (wiki)

### 5.3 Inn upgrade trees (Inn Materials)

**How the trees work** (wiki):

- Each inn has **five trees**.
- Nodes generally cost **5 (minor)** or **10 (major)** Inn Materials. Only the top row is open at first, and children need their parent.
- Every tree except the Barracks has a **Basic** and an **Advanced** half. **An inn can buy Advanced nodes in one tree only**: the first one specialises the inn and locks the Advanced halves of the other four.
- The bottom major node unlocks a **Capstone** for **40**. **One capstone per inn.**
- **Minimum cost to reach each capstone,** excluding the 40: Barracks 70, Provisioner 50, Mastery 50, Wainwright 40, Physician 50. (community, TrueAchievements "Rebuilt" guide; the Barracks figure matches the wiki's node costs)
- A "Rebuilt" achievement asks for one of each capstone in a campaign, so it needs at least five inns. (community)

**Barracks: militia for sieges** (no specialisation lock)

| Node | Cost | Effect |
|---|---|---|
| I. Conscript Support | 5 | 2 Conscript Fighters and 2 Conscript Arbalisters join siege defences |
| Fighter / Arbalister Trinket I | 5 each | That militia type starts sieges with a Vague trinket |
| II. Signal Flare | 5 | Signal Flare (Conscripts) sold in the shop |
| III. Partisan Training | 10 | Militia become Partisans |
| Trinket II (×2) | 5 each | Distant trinket |
| IV. Signal Flare II | 10 | Partisan flares |
| V. Veteran Specialization | 20 | Militia become Veterans |
| Trinket III (×2) | 5 each | Indelible trinket |
| VI. Signal Flare III | 20 | Veteran flares |
| **Capstone: Ordnance Supply** | 40 | Adjacent regions: +100% Assistance scouting, −33% Enemy Advantage. Militia also start with a combat item and a second trinket. |

**Provisioner: the shop**

| Section | Nodes (cost) |
|---|---|
| Basic | I. More trinkets and coach items (10); −20% on those (5); II. More combat and inn items (10); −20% on those (5); III. More food (10); IV. More whiskey (10) |
| Advanced | V. Better food (10); VI. Better whiskey (10); VII. Better coach items and basic pets (10); special pets (10); VIII. Better combat and inn items (10); −30% on those (5); IX. Indelible trinkets (5) |
| **Capstone: Grand Bazaar** (40) | **+20 Inn Materials each time the coach arrives**; adjacent regions +100% Hoarder scouting, +2 Relics and +1 Bauble per loot; unique items in the shop |

**Mastery Trainer: skills and stats**

| Section | Nodes (cost) |
|---|---|
| Basic | I. Unlock hero skills (10); II. Master skills (10); III. Change paths (10); 2 × −25% path-change price (5 each) |
| Advanced | IV. Trainer's Texts: **hero stat upgrades** (10); V. Stationed heroes +5% crit for a region (10); VI. Offence items in the shop (10) |
| **Capstone: Training Grounds** (40) | +1 Mastery Point on arrival; adjacent regions +100% Resistance scouting, and Strength at the start of Resistance fights |

- Node II is titled "More Combat & Inn Items" on the wiki, apparently a copy error; its effect is "Can master hero skills". (wiki)
- Stat upgrades include lowering a hero's **fatigue cap** from 50% to 20–35%, depending on the hero. (wiki, Fatigue)

**Wainwright: the coach**

| Section | Nodes (cost) |
|---|---|
| Basic | I. Repairs −33% (10); 2 × Inn Storage +3 (5 each); II. Can equip trophies (10); III. Can equip a pet (10) |
| Advanced | IV. More coach items (10); Kennel, basic pets (5); coach items −25% (5); V. +1 Wheel and +1 Armor on arrival, and resting heroes +10% good relationship chance (10) |
| **Capstone: Stables** (40) | Adjacent regions: +40% location and route scouting, −33% Flame drain; enemies start road fights with Vulnerable and Weak |

**Physician: healing and treatment**

| Section | Nodes (cost) |
|---|---|
| Basic | I. Cure diseases (10); 2 × −25% cure price (5 each); II. Stationed heroes get an extra −10% fatigue, −1 stress and +10% HP per day (10) |
| Advanced | III. Quirk treatment: remove negative or positive quirks, lock positive ones (10); −25% removal (5); −25% lock-in (5); IV. The stationing bonus again (10); V. Heal fatigue, −10% for 8 Baubles (10); −25% price (5); VI. Healing items in the shop (10) |
| **Capstone: Trauma Centre** (40) | **Arriving heroes gain a positive quirk**; adjacent regions +100% Field Hospital scouting; heroes take −2 DoT damage |

(all trees: wiki, Kingdoms/Inns and Camps)

- **Design note: the specialisation lock is the key idea.** Every inn gets the cheap Basic tier of everything, but only one deep specialty and one capstone. With several inns, the map becomes a set of specialised towns. (inferred)

### 5.4 Inn Materials: where they come from

- **Looted** during regions. The Builder quirk gives +2 per loot, and the "Heavy Hitters" event gives +2 per loot. (wiki)
- **Assistance encounters:** selfish choices trade −12 Relics or −15 Flame for Inn Materials. (wiki, hero bark pages)
- **The "Surplus Supply" event:** +20. (wiki)
- **The Grand Bazaar capstone:** +20 per arrival at that inn. (wiki)
- **Inn treasures:** spawn on the map and are collected by visiting. A search excerpt of a 2025 patch note says level-2 treasures were raised from 20 to 30 Inn Materials. That page could not be opened (see Could not confirm). (community, search excerpt)
- **Siege victories:** pay "some currency". The amount is not stated. (wiki)

### 5.5 Defending the settlement: sieges

- **Who gets besieged:** enemies periodically besiege an inn, but never the one the coach is at. (wiki)
- **Countdown:** a siege counts down a number of days. At zero, a siege battle is fought by (wiki):
  - the heroes stationed there;
  - **Peasant Militia**, if the Barracks is upgraded.
- **Defending in person:** driving the coach to the inn starts the battle at once with the coach party. Militia fill the empty slots from the back. (wiki)
- **Losing an inn:** it becomes a **camp for good**. Every hero in the kingdom takes +10% fatigue and +2 stress, with a 25% chance to lose a positive quirk. Losing enough inns ends the campaign. (wiki)
- **Winning:** Mastery Points at once. Currency and sometimes a faction item are **stored at the inn** until the coach collects them. (wiki)
- **Militia** (wiki). Militia skip Death's Door and die at 0 HP.

| Unit | HP | SPD | Main attack | Other skills |
|---|---|---|---|---|
| Conscript Fighter | 27 | 2 | 2–4, 5% crit | Cover (Guarded ×2, Block ×2) |
| Conscript Arbalister | 27 | 3 | 4–7, 10% crit | 20% field heal ×3 |
| Partisan Fighter | 37 | 3 | 3–6, 5% crit | Leading Strike, Riposte |
| Partisan Arbalister | 32 | 4 | 6–9, 10% crit | 30% field heal |
| Veteran Fighter | 42 | 4 | 4–8, 10% crit | As Partisan |
| Veteran Arbalister | 40 | 5 | 8–11, 15% crit | 50% field heal; Windlass ignores Block |

- **Signal Flares** are combat items costing 4 / 8 / 16 Relics, by militia tier. They end the turn and summon one militia unit per **missing ally** into any non-lair fight. (wiki)

### 5.6 Managing the roster between trips

- **Stationing** (5.2) is the rest mechanic. (wiki)
- **Swift horse:** a hero off the coach can ride up to two regions a day to reposition or reinforce an inn. Two regions in a day costs +15% fatigue, +1–3 stress and a 5% disease chance. The Traveler quirk and the "Fleet-Footed" event waive this. (wiki)
- **Fatigue** pushes rotation: it cuts **max HP by a percentage**. (wiki) The page's own summary says it "encourages building a wide roster so that heroes can rest as needed".
  - **Cap:** 50%, which hero upgrades lower.
  - **Gained** by entering an inn or camp (+5/10/15/20%), Death's Door (+10%), Meltdowns (+5%) and lost inns (+10%).
  - **Removed** by stationing (−10% at an inn, −5% at a camp), Physician nodes, Field Hospitals (−10% for 8 Baubles), some items, and becoming Resolute (−15%).
- **Relationships** last 5 days. Ending a positive one costs the pair 3 affinity, which pulls pairs back toward neutral. (wiki)
- **Shared state** (wiki):
  - Inventory: 33 slots, with all coach gear slots open and 3 Wheels and 3 Armor.
  - Trophy and pet slots: locked until the Wainwright nodes are bought.
  - Inn Storage: per inn, +3 per Storage Containers node; base size not stated.
  - The Hoarder buys at 20%.

---

## 6. Ideas for a DD1-style town

Context from [design.md](../design.md):

- a fixed cast of 8 heroes, one per class, with no permadeath ("Wounded" instead);
- weeks, gold, and four heirloom types;
- the Stagecoach, Guild, Blacksmith and Abbey;
- positive-only bonds;
- mission maps with rest, cache, event and elite rooms.

Every sketch below is **(inferred)**.

**Prices.** A gold rate keeps DD2 prices comparable. Assume **1 Relic ≈ 50 gold**:

- an inn item (8–16 Relics) costs 400–800 gold;
- a full combat-item stack (12 Relics) costs 600 gold.

That is dearer per stress point than the Abbey (1,000 gold for −4 stress, about 250 per point), but costs no week in town.

**Heirlooms** follow DD1's pattern: Busts for care, Portraits for leisure and training, Deeds for gear and the coach, and Crests everywhere.

| # | Idea | Building or upgrade | DD2 source | Sketch for darko-dungo |
|---|---|---|---|---|
| 1 | **Inn items as a weekly menu** | New **Tavern** (Portraits + Crests) | 3.2–3.3 | Buy food, drink and games for heroes in town; effects apply to their next mission. Food: +20/30% max HP, once per hero per week. Drink: −1 to −3 stress plus bond points, with a 33% "bad night" (no bond gain, or later a bond loss). Pair games: +1 bond at 75%. A party feast like the Roast Pig. Unlike the Abbey, no lost week. Upgrades: more stock, better tiers, −20% prices. |
| 2 | **Bond steering** | Tavern upgrades or Abbey tracks | 3.4, 2.3 (Tea Service +6%, Leaf Suspension +4%), 5.3 (Wainwright V) | +X% bond-point chance for heroes leaving town, or a "rest together" slot that gives a chosen pair +2 bond. It feeds the bonds system that already exists. |
| 3 | **Combat items** | New **Quartermaster** (Deeds + Crests) | 4.1–4.3 | One item slot per hero; stacks of 1–4; a full stack about 600 gold. Upgrades: tiers of stock unlocked in order (Working Fields rule, 1.4); +1 stack size (Lashing Tides); −20% price (Guild Seal). It finally gives gold a per-mission sink like DD1's provisions. |
| 4 | **Coach armour and wheels** | Stagecoach upgrade lines (Deeds + Crests) | 2.1 | **Armour plating:** Block at the first fight's start, 33/66/100% per hero. **Wheels/suspension:** rest rooms heal +20/33/50% more. Optional wear: a road event knocks a level off until repaired for gold. |
| 5 | **Coach gear slots** | Stagecoach line: 1 → 4 slots | 2.2–2.3, 2.5 | Equip passive gear bought with gold: a still (one free drink per mission), a medical kit (+20% rest healing), a telescope (reveals hidden rooms, tying into design.md's scouting), a strongbox (+cache gold). A later pet slot that rewards one gear family. |
| 6 | **Room-arrival bonuses** | "Wayfarer" upgrades (Crests) | 1.2 Resourcefulness | Rest rooms +10% HP and −1 stress (Sanctuary); caches add a free consumable (Efficiency); event rooms grant +1 SPD until the mission ends (Invigoration). These upgrade the mission maps directly. |
| 7 | **Per-hero tracks** | A **Hall of Heroes** or Memorial (Busts + Crests) | 1.3 | With one persistent hero per class, a short track per hero: +4 max HP, +5% Deathblow RES ×3, +10% to two resistances, then a hero trinket or a **signature Tavern item** (3.6) at the end. DD2 sizes it at about half a run's income per hero. |
| 8 | **Mementos (Memories)** | Free, earned | 1.5 | A slot for each Champion mission or region finale a hero survives, up to 5. After each mission, offer a few small passives (+10% HP, +1 SPD, +15% one resistance) for empty slots. Fits a persistent cast with no extra currency. |
| 9 | **Specialisation trees** | Shape for any building's upgrades | 5.3 | Basic nodes (5 heirlooms) open to all; one Advanced branch per building; a capstone (40). For example, the Abbey picks a Meditation, Prayer or Penance specialty. This gives DD1's flat ladders real choices. |
| 10 | **Idle rest bonus** | Barracks or Inn upgrade | 5.2 | Heroes idle for a week get "Well-rested" for their next mission (+20% max HP, +20% damage, +2 SPD; not stacking), on top of today's −1 stress. A Physician-style upgrade adds −1 stress or clears Wounded faster. |
| 11 | **Fatigue** (optional) | Ties to the Sanitarium or Physician | 5.6 | Back-to-back missions cost −10% max HP, up to −50%; a week idle removes 10%; the Physician cures it for gold. It forces rotation through all 8 heroes. Only worth it if rotation isn't already pushed by stress and Wounded. |
| 12 | **Town defence** | **Watch** or Barracks (Deeds + Crests) | 5.5 | A DD1-style town event (like the Vvulf incursion): raiders besiege the hamlet for N weeks, idle heroes plus militia defend, and a loss closes a building for some weeks. Barracks upgrades militia from Conscript to Partisan to Veteran (stat table above). **Signal flares** fill empty party slots with militia, a fix for short-handed weeks instead of "Wait out the week". |
| 13 | **Unlocking shop stock** | Wagon or Quartermaster upgrades | 1.4 | Unlock items for gold or heirlooms in tiers: random within a tier, tier N+1 only after tier N, cost ×1/×2/×4. It spreads new content over the campaign. |
| 14 | **Campaign modifiers** | New-campaign screen, or a Watch toggle | 1.6, 2.4 | DD2's Dam and Infernal Flames: optional hard rules (no retreat; stronger elites) for +15% heirlooms. |

- **Cheapest high-value first steps:**
  - **1** (Tavern menu) and **3** (Quartermaster) add gold sinks and pre-mission choices using systems that already exist (stress, bonds, tokens).
  - **4** (armour and wheels) is two numbers on existing upgrade lines.
  - **9** is a shape, not content, and can be applied to the Abbey ladder already in design.md.

---

## 7. Could not confirm

- **Per-inn cap on inn items.** No source states one. Food is limited to once per hero per region. A May 2023 Steam post says items could be stacked on one hero. Not checked in game.
- **Per-step Candle costs** within Intrepid Coast lines and Living City tracks. The wiki gives only totals. Also unknown: the Infernal Flame line's cost, and whether Memories cost Candles.
- **Altar +1 max Wheels and Armor.** The Stagecoach page says it exists; the Intrepid Coast page doesn't list it.
- **"Lanterns" as a stagecoach upgrade.** Not found under that name. The closest are the Flame slot, Carriage Lamps, the Iron Brazier and the Moonlight Lantern (2.4).
- **Base inventory size in Confessions.** Only Kingdoms' 33 is documented. Older community guides say the Storage Trunk gives +4; the wiki says +3, and +6 for the Spacious version.
- **"Character Unlocked Candle cost from 8 to 5"** (hotfix 2.04.84350). It doesn't match the wiki's 4-Candle hero unlock; it may mean the in-run Bounty Hunter hire.
- **Whether the wiki's other Candle numbers predate the April 2026 hotfix.** Node chances, region goals and end-game prices may also have changed.
- **Inn Material amounts** per loot, siege victory and inn treasure, and what inn treasures contain. The "level-2 treasures 20 → 30" line comes only from a search excerpt of SteamDB patch notes 17327795, which showed a Cloudflare check.
- **Siege timer length; militia headcount after Conscript Support; base inn storage.**
- **Exact tree layout** of the Kingdoms upgrade trees: which minor nodes hang under which major. The capstone minimums are from one community guide.
- **Mastery Point income and the cost to master a skill.**
- **A "home inn" in Kingdoms.** No such concept found (5).
- **Fandom's "Pool of Reflection"** Altar location. It doesn't appear on wiki.gg or in the 2022 notes, and is probably outdated.
- **Escalating fatigue on entering inns** (+5/10/15/20%). The wiki lists the four values without saying what sets each.

---

## Sources

### wiki.gg (primary for current numbers)
- Altar of Hope: https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope
- The Intrepid Coast: https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope/The_Intrepid_Coast
- The Living City: https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope/The_Living_City
- The Working Fields: https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope/The_Working_Fields
- The Timeless Wood: https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope/The_Timeless_Wood
- Candles of Hope: https://darkestdungeon.wiki.gg/wiki/Candles_of_Hope
- Stagecoach: https://darkestdungeon.wiki.gg/wiki/Stagecoach_(Darkest_Dungeon_II)
- Stagecoach Items: https://darkestdungeon.wiki.gg/wiki/Stagecoach_Items
- Flame: https://darkestdungeon.wiki.gg/wiki/Flame
- Pets: https://darkestdungeon.wiki.gg/wiki/Pets
- Inn: https://darkestdungeon.wiki.gg/wiki/Inn
- Inn Items: https://darkestdungeon.wiki.gg/wiki/Inn_Items
- Relationships: https://darkestdungeon.wiki.gg/wiki/Relationships
- Combat Items: https://darkestdungeon.wiki.gg/wiki/Combat_Items
- Items (DD2): https://darkestdungeon.wiki.gg/wiki/Items_(Darkest_Dungeon_II)
- Items (Kingdoms): https://darkestdungeon.wiki.gg/wiki/Items_(Kingdoms)
- Mastery Points: https://darkestdungeon.wiki.gg/wiki/Mastery_Points
- Shrine of Reflection: https://darkestdungeon.wiki.gg/wiki/Shrine_of_Reflection
- Quirks (DD2; Builder, Traveler, fatigue quirks): https://darkestdungeon.wiki.gg/wiki/Quirks_(Darkest_Dungeon_II)
- Kingdoms: https://darkestdungeon.wiki.gg/wiki/Kingdoms
- Kingdoms/Inns and Camps: https://darkestdungeon.wiki.gg/wiki/Kingdoms/Inns_and_Camps
- Kingdoms/Difficulty: https://darkestdungeon.wiki.gg/wiki/Kingdoms/Difficulty
- Kingdoms/Fatigue: https://darkestdungeon.wiki.gg/wiki/Kingdoms/Fatigue
- Kingdoms/Events: https://darkestdungeon.wiki.gg/wiki/Kingdoms/Events
- Kingdoms/Modules: https://darkestdungeon.wiki.gg/wiki/Kingdoms/Modules
- Siege: https://darkestdungeon.wiki.gg/wiki/Siege
- Peasant Militia: https://darkestdungeon.wiki.gg/wiki/Peasant_Militia
- Hero bark pages (Inn Material node choices), e.g.: https://darkestdungeon.wiki.gg/wiki/Man-at-Arms_(Darkest_Dungeon_II)/Barks

### Red Hook patch notes and news (patch)
- "New FREE Game Mode 'Kingdoms' Coming in 2024!" (10 Apr 2024): https://www.darkestdungeon.com/news/new-free-game-mode-kingdoms-coming-in-2024
- "Kingdoms Game Mode + Inhuman Bondage DLC Available Now" (27 Jan 2025): https://www.darkestdungeon.com/news/kingdoms-game-mode-inhuman-bondage-dlc-available-now
- "Darkest Dungeon II - Kingdoms - Retail Release" patch notes (27 Jan 2025): https://www.darkestdungeon.com/news/darkest-dungeon-ii-kingdoms-retail-release
- Steam announcements via Steam's news API, including hotfix 2.04.84350 (6 Apr 2026, Candle changes) and the Nov 2025 post naming The Dam: https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1940340&count=40&maxlength=0&feeds=steam_community_announcements
- Altar of Hope update notes (Sept 2022, build 0.16.38304), as reproduced by GameBanshee: https://www.gamebanshee.com/xycku and https://www.gamebanshee.com/xyqwk
- Kingdoms and Inhuman Bondage press release (Game Developer): https://www.gamedeveloper.com/press-release/darkest-dungeon-ii-s-brand-new-free-game-mode-kingdoms-and-second-dlc-inhuman-bondage-launch-on-pc-january-27th

### Fandom (cross-check)
- Altar of Hope: https://darkestdungeon.fandom.com/wiki/Altar_of_Hope
- The Intrepid Coast: https://darkestdungeon.fandom.com/wiki/The_Intrepid_Coast

### Community
- TrueAchievements, "Rebuilt" guide (capstone minimum costs): https://www.trueachievements.com/a476431/rebuilt-achievement
- Steam, inn items stack on one hero (20 May 2023): https://steamcommunity.com/app/1940340/discussions/0/3830919351658124863
- Steam, Kingdoms skill unlocks need the inn upgrade (29 Jan 2025): https://steamcommunity.com/app/1940340/discussions/0/594013565133844659

### Not reachable
- SteamDB patch notes 17327795 (Cloudflare check): https://steamdb.info/patchnotes/17327795/
- wiki.gg full-text search (Cloudflare check)
