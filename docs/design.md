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
- **Stress** 0–10 with mid-combat Meltdown (80%) or Resolute (20%) at 10.
- **Death's Door**: heroes at 0 HP are on Death's Door; further damage rolls deathblow resistance (60% base, −10% per survived check, clamped 33–90%). A failed roll **defeats** the hero rather than killing them (see [Campaign](#campaign)). Enemies die at 0 HP unless they have Death Armor.
- **Hero kit**: 5 skills each, plus Swap and Pass. Recover (DD2's `pass_heal`) appears below 25% HP. DD2 cooldowns and per-battle limits apply.
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

- **One unique hero per class.** The cast is the 8 classes below; you start with the original 4 at level 0.
- **Recruiting:** from week 2 one new hero arrives at the Stagecoach each week (Warden, Plaguebearer, Minstrel, Penitent, in that order). Hiring is free, and an unhired hero waits at the Stagecoach. The Stagecoach upgrade makes arrivals start at level 1, 2 or 3 so late heroes can catch up.
- **No permadeath.** A failed deathblow **defeats** the hero: they leave the fight and take no further part in the mission. Back in town they are **Wounded** and sit out the next week, unless you pay to treat them at once. They keep their levels, gear and skills.
- **Between missions** heroes return at full HP. Stress carries over until relieved at the Abbey. Idle heroes lose 1 stress per week.

### Weeks and missions

- **One mission is one week.** The week advances when the party returns, whether it won, retreated or wiped. Then: Abbey and wound treatments finish, idle heroes lose stress, a new hero may arrive, and the mission board refreshes.
- **Mission board:** 3 missions per week, each with a **tier** (Apprentice level 1, Veteran level 3, Champion level 5) and a **length** (short 2 fights, medium 3, long 4). Veteran missions appear once a hero reaches level 2, Champion once a hero reaches level 4.
- **A mission is a chain of fights** drawn from a pool of enemy groups. Between fights you choose **Continue** or **Retreat**. HP, stress and Death's Door carry from fight to fight; the DD2 end-of-battle heal (up to 20% HP) still applies.
- **Party selection:** up to 4 heroes, rank 1 first in the order picked. Heroes who are Wounded or busy at the Abbey can't go. Heroes at least 2 levels above the mission level refuse it ("will not go"). Heroes more than one level below it start the mission with +2 stress per level short: level 0 is fine for Apprentice, level 2 for Veteran, level 4 for Champion.
- **Nobody fit to go:** when every hero is Wounded or at the Abbey and nobody waits at the Stagecoach, the board offers **Wait out the week**, which ends the week without a mission. It keeps a wiped party that can't afford treatment from locking the campaign; DD1 never needs it because its Stagecoach always has recruits.
- **Enemy tiers:** Veteran enemies have +25% HP and damage; Champion enemies +50% HP and damage and +5% crit.

### Rewards

| | Short | Medium | Long |
|---|---|---|---|
| Gold (Apprentice; Veteran ×1.5, Champion ×2) | 3,000 | 4,500 | 7,500 |
| XP (Apprentice; Veteran ×2, Champion ×4) | 2 | 3 | 4 |
| Bust or Portrait (Apprentice / Veteran / Champion) | 2 / 2 / 3 | 2 / 3 / 5 | 4 / 6 / 9 |
| Deed or Crest (Apprentice / Veteran / Champion) | 3 / 4 / 6 | 5 / 6 / 9 | 9 / 12 / 18 |

- **Gold:** half is split evenly across the fights and paid as each is won; the other half is paid on completion.
- **Heirlooms:** each mission shows one heirloom type, paid on completion in the amount above.
- **XP** only for completing the mission.
- **Retreat:** keep the gold from fights already won; no completion gold, heirlooms or XP; +2 stress per hero.
- **Party wipe:** the mission fails. No rewards at all, not even gold from fights won, and every hero is Wounded.
- **Starting resources:** 5,000 gold, no heirlooms.

### Hero growth

- **Levels 1–6** at 2 / 8 / 14 / 24 / 36 / 48 total XP. Each level gives +10% to stun, bleed, blight, burn, move and debuff resistance, and raises the gear and skill caps.
- **Blacksmith:** weapon and armour ranks 2–5 for 750 / 1,750 / 3,000 / 6,000 gold, needing hero level 1 / 2 / 3 / 5 and the matching Blacksmith upgrade.
  - Each weapon rank above 1: +10% damage, +1% crit, and +1 speed at ranks 3 and 5.
  - Each armour rank above 1: +20% of base HP.
- **Guild:** skill ranks 2–5 for 250 / 750 / 1,250 / 2,500 gold, same level gates, needing the matching Guild upgrade. Each rank above 1: +10% damage or healing, +1% crit, +10% resistance pierce on its effects.

### Buildings

| Building | Service (gold) | Upgrades (heirlooms) |
|---|---|---|
| **Stagecoach** | Hire arriving heroes (free) | Arrivals start at level 1 / 2 / 3: 9 Busts + 12 Crests, 12 + 16, 15 + 20 |
| **Guild** | Skill ranks | Max rank 2 / 3 / 4 / 5: 6 Portraits + 14 Crests, 15 + 38, 24 + 60, 33 + 84 |
| **Blacksmith** | Weapon and armour ranks | Weapon and armour each, max rank 2 / 3 / 4 / 5: 8 Deeds + 8 Crests, 20 + 21, 32 + 35, 44 + 49 |
| **Abbey** | Stress relief, wound treatment | Ladder below |

- **Abbey activities:** three, removing 4 / 5 / 6 stress for 1,000 / 1,250 / 1,500 gold. Prices ×1.4 for heroes of level 3–4 and ×1.8 for level 5–6. The hero is busy for that week. One slot per activity at first. No side effects for now.
- **Abbey upgrades** (Busts + Crests), applying to all three activities:
  1. more relief, 6 / 7 / 8 stress (4 + 5)
  2. prices −15% (8 + 10)
  3. 2 slots each (11 + 14)
  4. more relief, 7 / 9 / 10 stress (15 + 19)
  5. prices −15% more (19 + 24)
  6. 3 slots each (23 + 29)
- **Wound treatment:** 750 gold (same ×1.4 / ×1.8) to heal a Wounded hero for this week's mission.
- All buildings are open from the start. DD1's gradual unlocking, the Tavern as a separate building and the discount upgrade lines come later.

### New classes

| Class | Role | Ranks | Build |
|---|---|---|---|
| **Warden** | Bodyguard | 1–2 | Guards allies, Riposte, Daze, a Block bash |
| **Penitent** | Self-harming berserker | 1–2 | Hurts itself for power, stronger at low HP, bleeds whole ranks |
| **Plaguebearer** | Alchemist | 2–4 | Blight bombs on ranks 1+2, stun gas on ranks 3+4, cures DoTs |
| **Minstrel** | Morale and tempo | 2–4 | Party stress relief, Speed and Crit tokens, a finisher that steps it back |

### Town screen and saving

- DD1 layout: a placeholder hamlet panorama with clickable buildings, a roster panel on the right, and a window per building. Top bar: week, gold and heirlooms.
- One autosave slot, written after every town action and every fight (`user://`, which is browser storage on the web build).
- A title screen offers Continue, New Campaign and the Combat Sandbox. Launch options skip it: `--continue`, `--new-campaign`, `--sandbox`. With `--autoplay` the town hires arrivals, treats the wounded, and embarks on its own, and the fights play themselves.

## Deviations from DD2

- `ai_weight` on skills is our extension. DD2 picks uniformly; leaving every weight at 1 does the same.
- **No permadeath.** A failed deathblow defeats and wounds a hero instead of killing them. Both DD games have permadeath.
- "Until next Inn" effects (Meltdown/Resolute deathblow changes) last until the end of the mission.
- Not implemented yet: relationships and affinity, quirks, diseases, combat items, Flame, battle modifiers, stalling penalties, retreating in the middle of a fight (you can only retreat between fights). Burn and the Speed, Daze, Guard and Immobilize tokens work in the engine but no v0 content uses them.

## Presentation & input

The combat screen follows DD2's, as measured in [research/darkest-dungeon-ui.md](research/darkest-dungeon-ui.md). Authored at 1920×1080; it scales.

- **Battlefield** in the top ~70% on a background scene (`SandboxDef.background`), fading to black below the ground line. Heroes on the left facing right, rank 1 nearest the centre; enemies mirrored. Figures are about 380 px tall (`UnitDef.sprite`, mirrored for enemies) or a coloured placeholder shape.
- **No names on the battlefield.** Under each unit: DoT icons, an HP bar without numbers, stress pips (heroes), and token icons with small diamonds for extra stacks. Hover a unit for its full stat sheet.
- **Death's Door:** empty HP bar with a pulsing red frame, red tint, skull in the token row. **Corpses:** dark placeholder mound with a brown-grey HP bar.
- **Top:** ragged black band with the round counter and a turn-order queue of diamond portraits; the acting unit is rightmost.
- **Bottom HUD** on black, shown on hero turns only:
  - left: hero portrait and name, and the selected skill's details in DD2's order (numbers, Target, Self, conditional bonuses);
  - centre: skill name, rank pips, 5 skill icons, then Swap, Recover and Pass diamonds; under them the HIT / DMG / CRIT preview against the focused target;
  - right: target panel with HP, speed and resistances, lighting up the ones the skill rolls against.
- **Targeting:** blue brackets under valid enemy targets (green for allies), a translucent box on the focused one, gold squares on the tokens the attack would use up. The acting unit gets a gold bracket and amber glow.
- **Attacks cut to a letterboxed close-up:** HUD hidden, scene tinted with dark ink edges, attacker and targets re-staged up to 1.5× size, skill name in gold. Self and party skills stay on the battlefield.
- **Pop-ups:** red damage (the unblocked number struck through when Block reduced it), orange "Critical!", grey Dodge, Miss and Resist, green heals, token and DoT icons with their names, stress in white.
- Wave title before round 1. Fonts: Grenze Gotisch for display text, Gelasio for body text (both SIL Open Font License).
- Combat log showing every roll (L, a dev overlay hidden by default) and a 2× speed toggle (S).
- Mouse first: click a skill, valid targets highlight, click a target. Keyboard: 1–8 pick a skill, Left/Right/Tab move the target, Enter/Space confirm, L log, S speed, R restart. Controller later.

## Content v0

Names are placeholders; the theme/setting is undecided. Rank notation: "From 1–2 → Enemy 1–3" means usable from ranks 1–2 against enemies in ranks 1–3; "1+2" hits both ranks at once. Resistances, crit chances and corpse HP are in the `.tres` files.

### Heroes

**Vanguard**, front-line tank. Ranks 1–2, 40 HP, speed 2. Swap ±1.

| Skill | From → targets | Effect |
|---|---|---|
| Shield Bash | 1–2 → Enemy 1–2 | 3–6 damage, Stun |
| Cleave | 1–2 → Enemy 1+2 | 3–5 damage each |
| Hold the Line | Self | Block+, Taunt ×2 |
| Shield Ally | 1–2 → ally (not self) | Block ×2 |
| Rally | Any → party | −1 stress to every hero; once per battle |

**Cutthroat**, bleed and Combo skirmisher. Ranks 1–3, 32 HP, speed 6. Swap ±1 or ±2.

| Skill | From → targets | Effect |
|---|---|---|
| Slice | 1–3 → Enemy 1–2 | 4–7 damage, Bleed 2 × 3 turns |
| Twin Strike | 1–2 → Enemy 1–3 | 3–5 damage, applies Combo; vs Combo: spends it for +50% damage instead |
| Lunge | 3–4 → Enemy 1–2 | 5–8 damage, self moves forward 2 |
| Fade | Self | Dodge+, Stealth ×2; cooldown 1 turn |
| Hamstring | 1–3 → Enemy 1–4 | 2–3 damage, Bleed 3 × 3 turns, Vulnerable |

**Marksman**, back-row ranged. Ranks 3–4, 30 HP, speed 4. Swap ±1.

| Skill | From → targets | Effect |
|---|---|---|
| Aimed Shot | 3–4 → Enemy 2–4 | 5–9 damage, 15% crit |
| Volley | 3–4 → Enemy 3+4 | 2–4 damage each |
| Blinding Shot | 2–4 → Enemy 1–4 | 2–4 damage, Blind |
| Expose | 2–4 → Enemy 1–4 | Vulnerable and Combo, no damage |
| Point Blank | 1–2 → Enemy 1 | 6–10 damage, self moves back 1 |

**Mender**, healer and support. Ranks 3–4, 28 HP, speed 3. Swap ±1.

| Skill | From → targets | Effect |
|---|---|---|
| Mend | 3–4 → ally | Heal 4–6 |
| Purge | 2–4 → ally | Remove bleed, blight, burn and negative tokens; heal 2 |
| Ward | 2–4 → ally | Block ×2 |
| Soothe | 3–4 → ally | −2 stress |
| Hex | 1–4 → Enemy 1–4 | 2–4 damage, Blight 2 × 3 turns, Weakness |

### Enemies

| Enemy | Ranks | HP | Speed | Skills |
|---|---|---|---|---|
| Ghoul (melee) | 1–2 | 26 | 3 | **Claw**: 4–7 damage to hero ranks 1–2, Bleed 1 × 3. **Gnaw**: 2–4 damage and +1 stress to hero rank 1 |
| Bone Spearman (melee, blocks) | 1–3 | 24 | 4 | **Thrust**: 5–8 damage to hero ranks 1–3. **Brace** (when it has no Riposte): self Block and Riposte ×2. Ripostes with **Counter Thrust** (2–4) |
| Spitter (blight) | 2–4 | 15 | 6 | **Spit**: 1–2 damage, Blight 3 × 3, hero ranks 2–4. **Skitter** (from 2–3): self moves back 1, gains Dodge |
| Cultist (stress and debuffs) | 3–4 | 18 | 5 | **Whisper**: +2 stress to any hero. **Curse**: 2–4 damage plus Blind or Weak |
| Brute (large, 2 ranks) | 1–2 | 75 | 2 | **Smash**: 8–12 damage to hero rank 1, knock back 1. **Sweep**: 4–7 damage to hero ranks 1+2. **Roar** (when it has no Strength): +1 stress to all heroes, self Strength. 1 Death Armor |

### Sandbox run

- Starting order: Vanguard (1), Cutthroat (2), Marksman (3), Mender (4).
- Wave 1 "Ghoul Pack": Ghoul, Ghoul, Spitter, Cultist.
- Wave 2 "Bone Line": Bone Spearman, Ghoul, Spitter, Cultist.
- Wave 3 "The Brute": Brute (ranks 1–2), Cultist, Spitter.
- Between waves nothing is restored except DD2's end-of-battle cleanup above. HP, stress and Death's Door carry over.

### Changes from the approved draft, and why

- **Mender's Hex is usable from rank 1** (was 2–4). With the Mender as last hero standing in rank 1, neither side could act and the fight never ended.
- **Cultist's skill is called Curse** (was Hex), so the log doesn't show two different skills named Hex.
- **Enemy HP and damage went up** (Ghoul 20→26 HP, Claw 3–6→4–7; Spearman 18→24, Thrust 4–7→5–8; Spitter 12→15; Cultist 14→18, Curse 2–3→2–4; Brute 60→75, Smash 6–10→8–12, Sweep 3–6→4–7) and the **Brute got 1 Death Armor**. With the draft numbers a scripted sensible player won every run.
- **Hold the Line gives Taunt ×2 and Fade gives Stealth ×2.** Each Stealth stack drops at the holder's turn end and each redirected attack spends a Taunt, so a single stack would barely last.

### Balance snapshot

`tests/test_simulation.gd` plays 200 full runs with scripted players and prints:

- Sensible player (heals the hurt, calms the stressed, otherwise hits hardest on the weakest foe): wins ~96% of runs, losing ~1.1 heroes per run.
- Random player: wins ~6% of runs.

A human should land between the two. Retune once it has been played.

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
- **Pushing enemies into effects.** Knockback, pull and swap become attacks: the Brute's Smash knocking a hero back into fire, or the Vanguard pulling an enemy onto spikes. Moving into a hazard triggers it immediately.
- **Sources.** Terrain can also come with the encounter (a wave that starts with a burning slot) or from deaths (a bleeding corpse leaves a blood pool).

To decide when we design it:
- how long effects last (rounds, triggers, or the whole fight)
- whether a slot can hold more than one effect
- how large units on two slots interact with terrain
- how terrain shows up on screen and in the skill targeting
- what the AI does with it

## Open / deferred

- **Theme and setting**, and with it all names.
- Town features after v1, roughly in DD1's priority: Abbey and Tavern side effects with quirks and the Sanitarium; trinkets and the Nomad Wagon; diseases; regions and bosses; town events; gradual building unlocks; discount upgrade lines; a dungeon map with supplies, light and camping (Survivalist).
- Relationships, Paths, combat items, skill loadouts.
- Real art, audio, controller support, multiple save slots.
- DD2 screen features waiting on mechanics or writing: the Flame emblem at the top, speech-bubble barks, right-click enemy and hero inspect sheets.
