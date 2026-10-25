# Darko Dungo — Design

Living record of agreed decisions. Anything not written here is either "do what Darkest Dungeon 2 does" or still open (see the end).

## Platform & tooling

- Godot 4.7.2, standard (non-.NET) build, statically typed GDScript.
- Git repository. Tests run headless through a small hand-rolled runner (`godot --headless --script ...`); no test add-on.

## Scope of v0: combat sandbox

- One scene: a fixed party of 4 heroes fights 3 enemy waves in sequence, then a win or lose screen with Restart.
- Out of scope for v0: dungeon map, town/hub, loot, progression, skill loadout UI, skill upgrades, Paths, combat items, trinkets, relationships, save/load.

## Architecture

- **Combat core** (`src/core/`) is pure logic: plain GDScript classes (no nodes), a seeded RNG so any fight replays exactly from its seed, and an event stream ("X used Y on Z, crit, 7 damage, Bleed applied") as its only output.
- **Presentation** (`src/ui/`) renders those events and sends the player's choices back to the core. It never decides outcomes.
- **Content** (`content/`) — heroes, enemies, skills, waves — is data, stored as Godot Resources (`.tres`), not code. Edit them in the Godot inspector.
- Combat takes a party in and hands it back out (HP, stress, Death's Door, deaths, long-lasting buffs), so it plugs into whichever game loop is chosen later.

## Combat model

- **Mirror Darkest Dungeon 2.** Where DD2 has a rule, copy it number for number. Reference: [research/darkest-dungeon-combat.md](research/darkest-dungeon-combat.md). All DD2 numbers live in `src/core/rules.gd` and `src/core/tokens.gd`.
- **Stress** 0–10 with mid-combat Meltdown (80%) or Resolute (20%) at 10.
- **Death's Door**: heroes at 0 HP are on Death's Door; further damage rolls deathblow resistance (60% base, −10% per survived check, clamped 33–90%). Dead heroes stay dead until Restart. Enemies die at 0 HP unless they have Death Armor.
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

## Deviations from DD2

- `ai_weight` on skills is our extension. DD2 picks uniformly; leaving every weight at 1 does the same.
- "Until next Inn" effects (Meltdown/Resolute deathblow changes) last until Restart, since there is no Inn yet.
- Not implemented yet: relationships and affinity, quirks, diseases, combat items, Flame, battle modifiers, stalling penalties, retreat. Burn and the Speed, Daze, Guard and Immobilize tokens work in the engine but no v0 content uses them.

## Presentation & input

- 2D side view at 1920×1080 (scales). Heroes on the left facing right, rank 1 nearest the centre; enemies mirrored on the right. Skill bar along the bottom.
- Placeholder art: coloured shapes with name, HP bar, stress pips and token chips. Hover a unit for its full stat sheet.
- The info panel shows what the selected skill does and a preview (hit chance, damage range, crit chance and crit damage) against the focused target.
- Each action plays a short close-up of actor and target with floating numbers and token pop-ups. 2× speed toggle.
- Toggleable combat log showing every roll, for balance work.
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

## Open / deferred

- **Game loop**: DD1-style hub and roster, DD2-style roguelike road, or something else. Decides whether HP and stress persist between fights outside the sandbox.
- **Theme and setting**, and with it all names.
- Relationships, progression (upgrades, Paths), combat items, trinkets, skill loadouts.
- Real art, audio, controller support, save/load.
