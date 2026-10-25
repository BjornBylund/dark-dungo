# Darkest Dungeon combat mechanics: implementation reference

Researched on 2026-10-25 for the Godot project `darko-dungo`.
**Darkest Dungeon II (DD2) is the target model.** Part A covers DD2 in depth. Part B is a short Darkest Dungeon 1 (DD1) comparison appendix.

## How to read this document

Every claim is tagged with where it comes from and how much to trust it:

| Tag | Meaning |
|---|---|
| **(data)** | Read directly from DD2's own data tables (CSV exports of `StreamingAssets/Excel`, mirrored in a public mod repo [D-WB]) or from decompiled class signatures [D-AB]. Primary source, but note the version caveat below. |
| **(wiki)** | darkestdungeon.wiki.gg (the actively maintained wiki). Its editors cite game files and patch notes. |
| **(patch)** | Red Hook's official patch notes (mirrored on the wiki). Authoritative for *changes*. |
| **(fandom)** | darkestdungeon.fandom.com (older wiki fork). Used for cross-checks. |
| **(inferred)** | My reading of field names or structure where no source states the rule in words. Treat as a design suggestion. |
| **(conflict)** | Sources disagree. Both values are given. |
| **(unknown)** | Could not be confirmed anywhere. |

> **Version caveat (important).** The DD2 data dump [D-WB] was committed in Jan 2024. It matches the game around v1.x + *The Binding Blade* DLC (Dec 2023). Later updates changed some core numbers: *Infernal Pursuits* (Feb 2024), *Kingdoms* (Jan 2025), *Steadfast Stewards* (v2.02, Jul 2025) and *Steadfast Stewards pt.2* (v2.04, 2025). Where a later patch overrides the data, the **current** value is given first and the data value is noted.

---

## TL;DR: DD2 core formulas

```
round_speed  = SPD + rand(0..6)                     # re-rolled at the start of each round; extra enemy turns: -2 per extra turn
hit          = !(attacker Blind && rand < 0.5)  &&  !(target Dodge+ ? rand < 0.75 : target Dodge ? rand < 0.5)
               # no ACC/DODGE stats in DD2; each token is consumed whether the roll succeeds or not
crit         = attacker has Crit token  ||  rand < crit_chance
base_dmg     = crit ? (dmg_base + dmg_range) * 1.5  :  dmg_base + rand(0..dmg_range)
dmg          = base_dmg * (1 + Σ attacker dmg%) * (1 + Σ target dmg-received%)   # Strength +50% atk side; Block -50%/Block+ -75%/Vuln +50% def side
               then * 0.5 if attacker has Weak                                       # since v2.02 (Jul 2025) Weak is applied last
status lands = rand < effect.chance  &&  rand >= clamp(resist - pierce - (crit ? 0.20 : 0), min, max)
DoT          = per-instance damage at the START of the holder's turn, usually 3 turns; summed with Regen into one instance
deathblow    = on any damage while at 0 HP: survive if rand < clamp(DBR, 0.33, 0.90); heroes DBR base 60%, -10% per survived check (this battle)
stress       = 0..10; at 10: 80% Meltdown (HP -> 10%, stress -> 1) / 20% Resolute (heal 67%, stress -> 0)
```

---

# Part A: Darkest Dungeon II

## A1. Battlefield, ranks, size, corpses

- **Ranks.** Each side has 4 ranks, numbered 1–4. Rank 1 is closest to the enemy and rank 4 is furthest. **(wiki)** [W-CM2]
- **Size.** All heroes and most enemies are size 1. Some enemies are size 2 or more and occupy several ranks. An attack that covers several of a unit's ranks still affects it **at most once**: a size-2 enemy hit on both ranks takes damage once. **(wiki)** [W-CM2] Size is a per-class field (`m_Size`). The Ghoul, for example, is size 2. **(data)** [D-WB `shared_ghoul`]
- **Corpses exist in DD2, for heroes and enemies alike.**
  - Every actor class has a matching `*_corpse` class with its own max HP. Examples: Highwayman corpse 19 HP, Ghoul corpse 20 HP (size 2), Drummer corpse 10 HP, Plague Eater corpse 13 HP. Resistances are set per corpse. **(data)** [D-WB]
  - The wiki says corpses inherit the dead unit's resistances and have per-enemy HP. That contrasts with DD1's size-based corpse HP. Battle modifiers such as *Sturdy* and *Hale* also apply to corpses. **(wiki)** [W-CORPSE2]
  - Unlike DD1, a kill by DoT or a crit does **not** prevent the corpse. Only a few enemies leave none: Shambler tentacles, Weapon Rack, Spiked Barricade, Sacrificial, Cabin Boy, and most bosses. **(wiki)** [W-CORPSE2]
  - **Lifetime.** Corpse classes have `m_DeathRound = 3` **(data)**. A guide states that corpses disappear after "typically three rounds" [GS]. Treat as: the corpse decays after 3 rounds unless destroyed (HP → 0) or cleared by a corpse-clearing skill or item. **(inferred from data + guide)**
  - **Corpse properties (data).** On death, the corpse clears its buff, token and DoT containers (`m_ClearContainerTypes`). It ignores `TOKEN_ADD`, `BUFF_ADD` and `QUIRK_ADD`. It uses `SkillBlock corpse`, which blocks heal-tagged skills from targeting it and blocks `health_heal`, `dot_add` and `horror` effects on it. Corpses have no turns (e.g. `plague_eater_corpse`: `speed 0`, `speed_number_of_turns 0`; `m_IsTickTriggerValid False`). [D-WB]
  - Enemy AI can interact with corpses: eat them, burn them for buffs, or revive from them. Examples are Carrion Eater, Immolatist, Dinner Cart/Lord/Lady and Bishop. **(wiki)** [W-CORPSE2]
- **Rank collapse.** The wiki says a corpse "takes up a slot". By implication, units behind a dead unit move forward only once the corpse is gone, or immediately if no corpse is left. No source spells out the shift algorithm. **(inferred)** Suggested rule: when a slot empties, every unit behind it moves forward by the vacated size, keeping relative order. (This is DD1's well-known behaviour.)
- **Position effects.** Forward/Back move the user or an ally. Pull/Knockback move enemies. Shuffle moves the target to a random position. Moves can enable or disable skills because skills are rank-gated. **(wiki)** [W-CM2] `Immobilize` blocks all movement (see tokens).

## A2. Round and turn structure

### Initiative
- At the **start of each round**, each unit gets a hidden *round speed* = `SPD + random 0..6`. Units act from highest to lowest. **(wiki + data)** [W-CM2]
  - Data values are `m_TurnOrderSpeedRollRangeMin = 0`, `Max = 6` and `m_TurnOrderSpeedRollRound = True`, so the roll happens once per round. [D-WB `combat_rules`]
  - The patch notes call it a "d6", changed from a d8 on 2022-02-23 "to give greater credence to speed scores". The wiki says the actual range is 0–6. [P-2022-02-23]
  - The fields are floats (`Single`) [D-AB `CombatRules`]. Whether the roll is an integer or a continuous float is **(unknown)**.
- **Speed changes mid-round** (buff or debuff) take effect only from the **next** round, because the order is fixed at round start. **(wiki)** [W-CM2]
- **Ties.** The turn-order sort key has a separate `m_SpeedTieBreaker` field next to `m_SpeedRoll` [D-AB `Battle.txt`]. How it is generated is **(unknown)**, probably random. DD1's "heroes first, then lower rank" rule is **not** confirmed for DD2.
- **Speed token.** It is consumed at round end and grants +100 SPD for the next round's roll, so the unit acts first unless another unit also has one. **(data + wiki)** [D-WB `token_data`, W-TOK]
- **Multiple turns per round.**
  - Enemies have a `speed_number_of_turns` stat. **(data)**
  - Each extra turn rolls its own round speed with a cumulative **−2 SPD** per extra turn (`m_TurnOrderSpeedRollPerExtraAction = -2`). **(data + wiki + patch 2022-09-26/10-11)**
  - Since 2023-03-16, monsters cannot get consecutive turns in the standard initiative order. This does not apply to special turns or turns changed by Speed/Daze tokens. **(patch)** [P-2023-03-16]
- **Turn types** (class `BattleTurnType`) are `ROLL` (normal initiative), `DYNAMIC` (inserted turns), `START_ROUND` and `END_ROUND`. The last two are round-start and round-end skills, such as the Drummer's "ORDER" skills (`m_Type,start_round`). **(data)** [D-AB, D-WB]
- **Ambush.** The turn order tracks an `AMBUSH_ROUND_INDEX` and `m_AmbushTeamIndex` [D-AB]. The visible effect of the *Ambush!* battle modifier is a free Shuffle of the hero party at combat start. **(wiki + data)** [W-BM]

### Extra actions vs free actions
- **Extra actions** (e.g. Jester's *Encore*, the *Oversprung Pocketwatch* trinket) do **not** trigger start- or end-of-turn effects. That means no DoT tick, no cooldown reduction and no status-duration reduction. **(wiki)** [W-CM2]
- **Free actions.** A skill marked "Does Not End Turn" (e.g. Abomination *Transform*) lets the unit act again. **Combat items** are used as a free action at the start of the hero's turn. **(wiki)** [W-CM2, W-ITEMS]

### What happens when (timing)
| Event | Timing | Source |
|---|---|---|
| Bleed/Blight/Burn ticks; Regen heals; Horror stress | **Start of the holder's turn**. DoT and Regen net into **one** damage or heal instance. | (data) `m_DurationType performer_turn_start` [D-WB dots]; (wiki) [W-CM2] |
| Most token durations (3) count down | **End of the holder's turn** (`performer_turn_end`) | (data) [D-WB tokens] |
| Stealth, Immobilize | 1 token removed at the end of the holder's turn (`m_DurationIsSingleRemove`) | (data) |
| Some buffs (Meltdown/Resolute buffs, Controlled Burn, Barnacles, Vestal blessings) | Count **rounds** (`round_end`) | (data) |
| Speed token | Consumed at round end; +100 SPD during the next round's roll | (data) |
| Stun / Daze | Consumed when the unit's turn comes: Stun skips the turn; Daze moves it to the end of the round | (data) `skip_turn`/`delay_turn` |
| Skill cooldowns | Reduced on the unit's normal turns, not on extra actions | (wiki) [W-CM2] |
| "Combat Start" / "Round Start" / "Turn Start/End" item, quirk and buff triggers | As named | (data) |

> **Duration semantics.** The wiki says most status effects last "three turns, including the current turn". Buffs and debuffs "typically need to be refreshed every other turn". **(wiki)** [W-CM2] DD2 tracks durations in several units: holder-turn, round, combat-end, until-next-Inn and infinite. Your engine should support at least **turn-based** and **round-based** timers.

## A3. Actions available on a turn

1. **Use one of the 5 equipped combat skills.** Heroes equip 5 (`m_EquippedCombatSkillLimit = 5`) **(data)** [D-WB hero_*].
2. **Move (Swap).** This is an always-equipped `*_move` skill: friendly-targeted, launchable from any rank, `m_IsMoveToTarget`. It swaps the hero with an ally at an allowed relative offset. **The allowed offsets differ per class (data):**

   | Hero | Allowed swap offsets (`m_TargetRelativeRanks`) |
   |---|---|
   | Highwayman, Grave Robber, Bounty Hunter, Man-at-Arms, Occultist | −2, −1, +1, +2 |
   | Jester | −3 … +3 |
   | Flagellant | −2, −1, +1 |
   | Runaway | −1, +1, +2 |
   | Plague Doctor, Vestal | −1, +1 |
   | Hellion, Leper | −1 only |
   | generic `move` | −1, +1 |

   The sign convention is **(inferred)**: negative = towards rank 1. The values are from the Jan-2024 data. Hellion and Leper were reworked in 2025, so their offsets may have changed.
3. **Pass.** The data defines always-equipped, hidden-unless-valid pass skills **(data)** [D-WB `pass_data`]:
   - `pass_stress`: the performer takes **+2 stress**.
   - `pass_heal`: only valid when the performer is under 25% HP. It heals 20%, gives +2 stress, and has cooldown 3.

   How these appear in the UI (e.g. only when no skill is usable) is **(unknown)**.
4. **Combat item** (free action, see A2).

### Skill attributes (hero and enemy skills share one schema)
| Field | Meaning | Example |
|---|---|---|
| `launch_ranks` | Ranks the user must stand in | Wicked Slice: 1,2,3 |
| `target_ranks` | Ranks that can be targeted | Wicked Slice: 1,2 |
| `m_IsFriendly`, `m_IsFriendlySelfTargetValid`, `m_IsOnlySelfTargetValid` | Ally targeting, self allowed, self only | Take Aim = self |
| `m_IsMultiHit` | Hits **all** valid targets in the listed ranks (AoE). The wiki writes this as `o-o..` (dashes join ranks hit together) | Ghoul Howl: ranks 1–4, multi |
| `health_damage`, `health_damage_range` | Damage = `base + rand(0..range)` | Ghoul Rend 4 + 0..2 → **4–6** |
| `crit_chance` | Base crit chance of the skill | Ghoul Rend 0.15 |
| `m_Cooldown` | Turns before reuse | Ghoul Howl 2; Highwayman Take Aim 2 |
| "uses" | Uses **per battle** (e.g. "Cause of Death … single use per battle") | [P-2025-07] |
| `m_Tags` | `melee` / `ranged` / `heal` / `move` (used by tokens such as *Denial of Arms*) | |
| `m_CanBeRiposted` | Whether a Riposte can answer it | |
| `token_ignores` | Ignores specific tokens (e.g. ignore Dodge, Stealth, Blind) | |
| `m_AllConditionIds` | Use conditions (e.g. `target_health_under_50pct`) | Drummer Focus Fire (weak) |
| `m_IsForced`, `m_IsBlockPass` | AI must use it when valid (see A10) | |
| `_u` variant | **Upgraded ("+") version**, bought with mastery; separate numbers and effects | `hwm_wicked_slice_u` |
| Paths | Each hero has ~4 paths that swap or modify skills | [W-HWM2] |
| Execution N | Bypasses up to N enemy Death Armor tokens (A8) | Wicked Slice: Execution 1 |

Sources: (data) [D-WB hero_hwm, shared_ghoul, lost_battalion_drummer]; (wiki) [W-SKILLDOC, W-HWM2, W-GHOUL2].
Skill numbers are patched often. For example, Wicked Slice is 6+0..4 in the 2024 data and 4–8 on the current wiki. **Treat specific skill numbers as content, not rules.**

## A4. Hit, crit and damage resolution (no accuracy stat)

**DD2 has no ACC or DODGE stats.** Hero stats are HP, SPD, stress max, and resistances (bleed, blight, burn, disease, stun, move, debuff, deathblow). **(data + wiki)** [D-WB hero_*, W-CM2] Hit/miss comes only from tokens. With no Blind on the attacker and no Dodge on the target, the attack always hits. **(fextralife EA page; consistent with data)** [FX]

Step by step:
1. **Guard redirect.** If the target has a Guard token, the attack goes to the guarding unit and one Guard token is consumed (`m_ConsumeTypes guard`). **(data)** See A7 for AoE.
2. **Blind (attacker).** 50% chance to miss. Consumed whether it triggers or not (`m_AlwaysRemove`); one token per attack. **(data)** The decompiled signatures pass a single `performerResultHit` into each target's calculation. This suggests one Blind roll per skill use, even for AoE. **(inferred)** [D-AB `SkillCalculation`]
3. **Dodge (target).** Dodge+ (75%) is consumed before Dodge (50%), one token per attack, consumed whether it triggers or not. Rolled per target. Blind and Dodge stack multiplicatively. **(data + wiki + fandom)** [D-WB tokens, W-TOK, F-TOK, PCG]
4. **On a miss.** Strength and Weak tokens are still consumed (`m_RemoveTypes on_damaging_miss`). So is the Crit token. **Block, Block+ and Vulnerable are *not* consumed on a miss.** **(data; Block also confirmed by a guide [PCG])**
5. **Crit.** A Crit token (consumed) guarantees a crit. Otherwise roll the skill's `crit_chance` plus modifiers. **(data + wiki)** [W-CRIT2]
   - Since Feb 2024, non-damaging skills can crit from their own crit chance. They then gain the 20% resistance pierce and the stress-relief triggers. **(patch)** [P-2024-02-02]
6. **Base damage.** `base + rand(0..range)`. On a crit, use **max × 1.5**. If the range minimum is 0 (e.g. Winded) and the roll gives 0 on a crit, max is used instead. **(wiki + patch)** [W-CRIT2, P-2025-SS2]
7. **Modifiers.**
   - All attacker-side % modifiers are **summed**. Examples: Strength +50%, trinkets, quirks, buffs.
   - All defender-side "damage received" % modifiers are **summed**. Examples: Block −50%, Block+ −75%, Vulnerable +50%.
   - The two sums are **multiplied**: `dmg = base × (1+Σatk) × (1+Σdef)`. **(wiki, worked example: 2.3 × 1.5 × 1.5 × 18 = 93.15)** [W-CM2, W-TOK]
   - **Weak** was an additive −50% on the attacker side (data `health_damage_dealt_percent −0.5`). **Since v2.02 (Jul 2025) it is applied after all other modifiers (×0.5).** **(patch)** [P-2025-07]
   - Flat "+N DMG" bonuses exist and are scaled by Strength etc. (e.g. Leper "flat +7 DMG … also affected by Strength"). **(patch)** [Last Light notes]
   - **Rounding is (unknown).** HP is stored as a float with `RoundHp`/`RoundHpUp` helpers [D-AB `ActorInstance`]. Suggestion: round the final damage to the nearest integer, with a minimum of 1 on a hit that has a non-zero base.
8. **Consume** Block/Block+ (higher priority first) and Vulnerable on a *damaging* hit, one token each per attack. **(data)**
9. **Apply on-hit effects** (statuses, moves, tokens) with resist rolls (A5).
10. **Riposte.** If a target with a Riposte token was attacked by a skill with `m_CanBeRiposted`, it counter-attacks with its class's special Riposte skill and consumes one token. At most **one** riposte triggers per attack: the frontmost target with Riposte. **(wiki + data)** [W-TOK]
11. **Stress triggers** from crits (A9). **Deathblow checks** for targets on Death's Door (A8).

## A5. Status effects and resistances

### Resistance roll
- Resistances (data `resist_data`):

  | Resist | Applies to | Max | Crit pierce |
  |---|---|---|---|
  | stun | Stun and Daze tokens | none | 0.2 |
  | bleed, blight, burn | Their DoTs | none | 0.2 |
  | disease | Diseases | 0.95 | 0.2 |
  | debuff | Debuff buffs and negative tokens (Blind, Weak, Vulnerable, Taunt, Immobilize…) | none | 0.2 |
  | move | MOVE and CAPTURE effects | none | 0.2 |
  | death | Deathblow | 0.90 (heroes min 0.33) | none |
  | stress | Stress damage | 1.0 | none |

  "Pierce" is the stat `resistance_ignore`, which skills, items and buffs grant. A crit adds **20% pierce** (`m_CritMod = −0.2`). **(data + wiki)** [D-WB, W-CM2, W-CRIT2]
- **Formula (inferred from data structure; consistent with wiki wording):**
  ```
  eff_resist = clamp(resist - pierce - (is_crit ? 0.2 : 0), resist.min, resist.max)
  applies    = rand() < effect.m_Chance  &&  (effect.m_IgnoreResist || rand() >= eff_resist)
  ```
  DD2 does **not** use DD1's subtractive "skill chance − resist" model. Most effects have `m_Chance = 1` and only the resistance matters. Some have explicit chances (e.g. "Combo (33%)").
  - A resistance of 100% or more makes the unit immune (no max cap for most resists). **(inferred)**
  - Self-applied negative tokens are generally not resistable. **(wiki)** [W-TOK]
- **Combo** is not a "negative" token, so it **cannot be resisted**. **(fandom + data: no `vs_resistance` tag)** [F-TOK]
- **Vulnerable** was made non-resistable in EA (2022-07-19 patch). The 2024 data tags it `vs_resistance_debuff`, which makes it resistable again. Current behaviour is **(conflict)**. Data is newer, so assume resistable.

### Damage over time (Bleed, Blight, Burn)
- All three work the same way: damage at the **start of the holder's turn**, default **3 turns**. Each type has its own resistance. Regions and enemy factions lean towards one type. **(wiki + data)** [W-DOT2]
- **Per-tick values** (data `dots_data`; the skill tooltip "Bleed 3" means 3 per turn):

  | Size | very small | small | medium | large | very large | massive | super massive |
  |---|---|---|---|---|---|---|---|
  | Damage per tick | 1 | 2 | 3 | 4 | 5 | 6 | 10 |

  All have duration 3.
- **Stacking.**
  - Each application adds a separate **instance** (`m_DotAddId` plus `m_DotAddAmount`), each with its own duration. All instances, including Regen (HoT) instances, are summed into **one** net damage or heal instance at turn start. **(data structure + wiki)** [W-CM2, template DoT2TickDesc]
  - Independent per-instance expiry is **(inferred)** from the data structure. It matches DD1's documented behaviour.
- DoT damage **ignores Block and Vulnerable** and most damage modifiers. **(wiki + data `m_Ignore*Modifications`)**
- DoTs are not triggered by extra actions and are removed at combat end. **(wiki)**
- **Crit and DoT.** A crit gives the DoT +20% pierce. Crits used to add **+2 turns** to DoT duration (`m_CritDotExtraDuration = 2`). **This was removed in v2.02 (Jul 2025).** **(patch)** [P-2025-07]
- The *Infectious* battle modifier gives enemies' DoTs +1 duration. **(data + wiki)** [W-BM]
- "DOT bombs" (e.g. Plague Doctor's *Cause of Death*) deal a share of the remaining DoT at once. They usually ignore multipliers and remove the DoTs. **(wiki)** [W-DOT2]
- **Death's Door.** A unit on Death's Door whose net DoT exceeds its Regen gets a deathblow check at turn start. **(wiki)** [W-CM2]

### Other statuses
- **Horror.** Stress-over-time instances (data): large = +1 stress per tick; medium = +1 at 75%; small = +1 at 50%. 3 turns, ticks at turn start. **(data)**
- **Regeneration.** A HoT that nets against DoT. It is not affected by "Healing Given" but is affected by "Healing Received" (not "…from Skills"). **(wiki)**
- **Buffs and debuffs.** Stat changes with durations. There is **no general way to remove buffs or debuffs** (unlike tokens). **(wiki)** [W-CM2]
- **Stun recovery.** After a Stun is consumed (turn skipped), the unit gets a temporary Stun RES buff until its next turn start (`turn_skip_effects stun_temp_resist_buff`).
  - **Current value: +50%** (Kingdoms update, Jan 2025: "increased from +40% to +50%… Heroes and monsters alike"). **(patch)** [P-2025-01]
  - The 2024 data and the fandom wiki show the older +40%.
- **Disease.** Some enemy attacks have a % chance to add a disease, e.g. "random disease 5%". Disease RES applies, max 95%. **(data)**
- **Healing crits.** Almost all heals have a fixed **5%** crit chance for **×1.5** healing (`m_CritChance 0.05, m_CritMultiplier 0.5`). **(data + wiki)** [W-CRIT2]

## A6. Token reference (DD2)

General rules:
- **Limit** = max stacks.
- **Consume** = what uses up a token. Normally **one token per event** (`m_ConsumeLimit 1`).
- Duration counts down at the **holder's turn end** unless noted.
- **Negate:** applying token X while the target has its opposite Y removes both, so they never co-exist.
- **Invert:** some skills convert tokens into their opposite.
- Removing a token also removes its variants (removing Dodge removes Dodge+ too).
- Token removal and stealing pick **randomly** among eligible tokens (since v2.02).

Sources: (data) [D-WB `token_data`]; (wiki) [W-TOK]; (fandom) [F-TOK]; (patch) as noted.

### Positive

| Token | Effect | Consumed / removed | Limit | Duration | Negates | Inverts to |
|---|---|---|---|---|---|---|
| **Crit** | Next applicable skill (attack or heal) is a guaranteed crit; combat items also consume it | Next skill use, also on miss, block or non-damaging use | 2 | 3 turns | none | Weak |
| **Dodge** | 50% to evade the next attack | Next attack against the holder, success or failure | 3 | 3 turns | none | Blind |
| **Dodge+** | 75% to evade the next attack; consumed before Dodge | As Dodge | 3 | 3 turns | none | Blind |
| **Block** | −50% damage from the next **damaging** hit | Next damaging hit (not on a miss) | 3 | 3 turns | Vulnerable | Vulnerable |
| **Block+** | −75% damage from the next damaging hit; consumed before Block | As Block | 3 | 3 turns | Vulnerable | Vulnerable |
| **Strength** | Next attack +50% damage (attacker-side additive) | Next damage calculation, also on miss | 2 | 3 turns | Weak | Weak |
| **Riposte** | Counter-attack the next damaging attack received, using the class's own Riposte skill (e.g. HWM/MAA 3–6 dmg, 5% crit) | When it triggers; only the frontmost riposter triggers per attack | 3 | 3 turns | none | none |
| **Guard** (shows as *Guarded* on the protected unit) | Next attack aimed at the unit goes to the guardian | One per redirected attack. Removed if the guardian dies or is captured. A unit can guard or be guarded by at most one unit; a guarded unit cannot guard; a new conflicting Guard replaces the old one. | 3 | 3 turns | none | none |
| **Speed** | Acts first next round (+100 SPD at the next roll) | At round end, turned into the SPD buff for the next round | 1 | 1 | Daze | Daze |
| **Stealth** | Cannot be targeted directly by most enemy skills while other targets exist; still hit by AoE | 1 removed at the holder's turn end, whatever it did | 2 | single-remove | the boss "Seen/Focus" token | Taunt |

Notes on positive tokens:
- Stealth was retagged as a positive token in the UI in v2.02 and can be stolen or copied. [P-2025-07]
- Stealth stacking to 2, with one consumed per turn, dates from 2022-10-11. [P-2022-10-11]

### Negative (resisted by Debuff RES, or Stun RES for Stun and Daze)

| Token | Effect | Consumed / removed | Limit | Duration | Negates | Inverts to |
|---|---|---|---|---|---|---|
| **Stun** | Lose the next action; afterwards +50% Stun RES until the next turn start (A5) | When the turn is skipped | 1 | until consumed | none | Speed |
| **Daze** | Next action delayed to the **end of the round**. Adding Daze to a Dazed unit turns it into Stun. Stun overrides Daze. | When the turn comes | 1 | until consumed | Speed | Speed |
| **Blind** | 50% to miss the next attack | Next attack, success or failure | 2 | 3 turns | none | Dodge |
| **Weak** | Next attack deals half damage (×0.5 after all other modifiers since v2.02; additive −50% before) | Next damage calculation, also on miss | 2 | 3 turns | Strength | Strength |
| **Vulnerable** | +50% damage from the next damaging hit (defender-side additive) | Next damaging hit | 2 | 3 turns | Block, Block+ | Block |
| **Taunt** | Enemies must target this unit if able | Consume type `forced_target`: one token per forced targeting **(inferred from data)**; also removed when guarding | 3 | 3 turns | none | Stealth |
| **Immobilize** | Cannot move or be moved | 1 removed at the holder's turn end | 3 | single-remove | none | none |

### Other, special and system tokens

| Token | Effect | Notes |
|---|---|---|
| **Combo** | No effect by itself. Many skills consume it for bonus effects ("When target has Combo: …") | Limit 1; 3 turns; not resistable; removed by the consuming skill ("end combo") |
| **Permanent Immobilize** | As Immobilize, cannot be removed | Heroes: 5 rounds (*General's Dream*); enemies: whole combat |
| **Death Armor** (enemy) | Absorbs one deathblow (A8) | Limit 3; lasts the whole combat |
| **Chosen Target / Marked for Death** | +30% damage from Bullseye Barrett only | Lasts the whole combat. **DD2 has no generic Mark status**: the DD1 Mark role is split between Taunt (aggro) and Combo (setup). |
| Class-specific | Flagellant Pain/Pain+/Toxic, Hellion Winded (−33% DMG and −3 SPD per token, max 3, whole combat), Occultist Unchecked Power, Runaway Controlled Burn, Vestal Consecrations/Conviction, Duelist stances | [W-TOK] |
| Enemy-specific | Order, Benediction, Corpulent, Fodder, Worship, Barnacles, boss tokens such as the "Denial" skill locks | [W-TOK] |

### Duration detail (conflict)
- The fandom wiki says all tokens of one type "disappear 3 turns after the **first** one is applied", which implies a shared timer per type that new stacks do not refresh. [F-TOK]
- wiki.gg only says "three turns, including the unit's current turn". [W-TOK]
- The data has one `m_DurationAmount` per token type, which does not settle the question.
- Recommendation: one shared timer per token type, started by the first stack and not refreshed. **(inferred)**

## A7. Special states (Guard, Riposte, Stealth, Taunt)

- **Guard** (see token table).
  - Redirects attacks and their effects to the guardian. The guardian's own tokens (Block, Dodge, Riposte) apply.
  - Whether Guard redirects **AoE** attacks that also hit the guardian is not documented for DD2. An EA-era page says Guard "does not protect from AoE attacks". **(unknown for current build)** [FX]
- **Riposte.**
  - Token-based, limit 3. Each trigger consumes one token. The counter uses the unit's own `Riposte` skill (own damage, crit and effects).
  - A unit without a defined riposte skill cannot gain Riposte.
  - Only the frontmost riposting target triggers per attack. **(wiki + data)**
- **Stealth.**
  - Excluded from single-target enemy selection unless it is the only valid target.
  - AoE can hit it. Some skills ignore or remove Stealth.
  - One stack falls off per holder turn. **(wiki + data + patch)**
  - 2024 fix: Taunt no longer overrides target calculation when an AoE targets only stealthed units. [Infernal Pursuits hotfix]
- **Taunt.** Forces enemy targeting onto the taunter **if the skill can reach it**: an enemy whose skill cannot target the taunter's rank is not forced. **(wiki/community)** [W-TOK; Steam/Q23 discussion]
- **Mark (DD1-style):** not present in DD2 (see the token table).

## A8. Death's Door, deathblows, death

### Heroes
- At 0 HP a hero enters **Death's Door (DD)**. Any further damage instance triggers a **deathblow check**.
  - Survival chance = **Deathblow RES** (DBR). **Base 60%** for most heroes (data `resistance,death,0.6`). Bounty Hunter and Flagellant have 75% in the 2024 data.
  - Base DBR was lowered from 75% to 60% on 2022-10-11. **(patch)** [P-2022-10-11]
- **Clamp:** DBR is limited to **33%–90%** (data `m_ResistMinOverrides death 0.33`; resist max 0.9; wiki agrees). **(data + wiki)** The fandom wiki says 5% minimum **(conflict, older)**.
- **Each survived check** gives −10% DBR until combat end (`deathblow_chance_shaping_heroes`, applied by `deaths_door_survive_effects`). **(data + wiki)**
- **On entering DD:**
  - −3 SPD (lasts while on DD).
  - **1 Weak token** (current). It was 2 Weak before v2.02. The 2024 data and the fandom wiki show 2. **(patch)** [P-2025-07]
  - Healing to ≥1 HP leaves DD and removes the SPD penalty but not the Weak token. **(wiki)** [W-DD2]
  - In Kingdoms mode, entering DD also adds Fatigue. **(wiki)**
- **Stress on DD:** the hero entering DD gains +1 stress at 50%; each ally gains +1 at 25%. **(data)** [D-WB stress_triggers]
- **DoT on DD:** DoT and Regen are summed into one instance, so one check per tick. **(wiki)**
- **Militia** have no DD and die at 0 HP. **(wiki)**
- Boss fights in Confessions apply a large DBR penalty (*Final Showdown*: −20%). **(patch + data)** [P-2022-10-11, D-WB battle_modifier]

### Enemies ("Death's Door v2", Sept 2023)
- Most enemies die at 0 HP. Some spawn with **Death Armor (DA)** tokens, 1 to 3 per enemy.
  - At 0 HP they enter DD, get Weak + −3 SPD, and each lethal hit consumes 1 DA instead of killing.
  - With no DA left, the next damage kills.
  - Healing an enemy off DD restores 1 DA (data: Ghoul `deaths_door_exit_effects add_1_deaths_door_armor`).
  - **(wiki + data + patch)** [W-DD2, P-2023-09-14]
- **Execution N** (skill attribute): if N ≥ the enemy's current DA and the hit would reduce it to 0 HP, it dies outright.
  - Execution from multiple sources does not stack; the highest applies.
  - A non-killing Execution hit still removes only 1 DA. **(wiki)**

### Death
- A dead unit becomes its corpse class (A1). Every ally gets +1 stress (100%). **(data)**
- In Confessions, hero death is permanent for the run. **(wiki)**

## A9. Stress (0–10), Meltdown, Resolute, relationships

- **Scale** 0–10 (`stress_max 10`). **(data + wiki)**
- **Stress RES** gives a chance to ignore a stress-damage instance; capped at 100%. **(wiki + data)**
- **Combat stress sources (data `stress_triggers`, exact):**

  | Trigger | Who | Stress | Chance |
  |---|---|---|---|
  | Receives a crit | target hero | +1 | 80% |
  | An ally receives a crit | each other hero | +1 | 15% |
  | Lands a crit | performer hero | −1 | 50% |
  | An ally lands a crit | each other hero | −1 | 5% |
  | Enters Death's Door | that hero | +1 | 50% |
  | An ally enters Death's Door | each other hero | +1 | 25% |
  | An ally dies | each other hero | +1 | 100% |

  Wiki numbers match [W-CRIT2]. Crit relief does not apply when hitting corpses. [P-2024-02-02]
- **Other sources:**
  - Enemy skills with explicit stress, often "+1" plus "+1 (25–50%)".
  - Horror.
  - Negative banter at 4–9 stress.
  - Quirks and trinkets.
  - Pass skill +2 (A3).
  - Retreat +2.
  - **(data + wiki)**
- **At 10 stress** (`overstress_data`, chances are base values that quirks and items modify):

  | Outcome | Chance | Effects |
  |---|---|---|
  | **Meltdown** | 80% | HP set **down to 10%** (no change if already ≤10%); **stress becomes 1** (`m_StressHealDownFromMax 9`); DBR −15% until next Inn; Stress RES +40% for 3 **rounds**; Affinity −3 with all party members; 40% chance of a meltdown quirk |
  | **Resolute** | 20% | Heal **67%** HP; **stress becomes 0**; DBR +15% until next Inn; Debuff RES +50% for 3 rounds; Stress RES +40% for 3 rounds; Affinity +2; 40% chance of a positive quirk |
  | **Toxic** (Flagellant only, 100%) | n/a | Toxic token; stress → 1; HP set to 30% (Scourge path 45%); clears skill cooldowns; DBR −10% until Inn; Affinity −2 |

  Sources: (data) [D-WB overstress]; (wiki) [W-STRESS2].
  - The post-event stress values (Meltdown → 1, Resolute → 0) come from the data fields `m_StressHealDownFromMax 9` and `10` (heal down from the max of 10). This reading of the field is **(inferred)**: no wiki states the resulting stress value.
  - The fandom wiki says Resolute heals 50% **(conflict; older)**.
  - Meltdown and Resolute are one-off events, not lasting states like DD1 afflictions. [P-2023-01-12]
  - Meltdowns can also be processed outside combat; patch notes reference out-of-combat meltdown fixes. Exact out-of-combat rules are **(unknown)**.
- **Relationships (brief).**
  - Each hero pair has affinity 0–20, starting at 9.
  - In combat, telegraphed actions shift affinity: healing, guarding, buffing, stress-healing, consecutive attacks on the same target. Affinity changes are telegraphed since 2023-01. [P-2023-01-12]
  - At each Inn, pairs may form a Positive relationship (Respectful, Hopeful, Amorous) or a Negative one (Suspicious, Envious, Hateful, Resentful). Chance by affinity: 0 → 90% negative; 20 → 90% positive.
  - Each relationship "blesses" or "curses" one skill per hero. Data examples: Respectful 50% gives the partner a Strength token; Suspicious adds Taunt + Vulnerable to the partner; cursed skills are force-equipped.
  - Positive pairs also have big act-outs (follow-up attacks, intercepting attacks, heals).
  - **(wiki + data)** [W-REL, D-WB skill_modifier]

## A10. Enemy AI (DD2)

What is known:
- The non-player controller class is **`ActorControllerRandom`**, alongside `ActorControllerInput` (player) and test controllers. Its interface is `SelectSkillId()`, `SelectTargetGuid()` and `CalculateIsSkip()`. **(data: decompiled signatures)** [D-AB]
- Enemy data has **no per-skill or per-target weights**. Enemy behaviour is shaped by:
  - launch and target ranks;
  - **cooldowns** (`m_Cooldown`, e.g. Ghoul Howl 2);
  - **use conditions** (`m_AllConditionIds`, e.g. "target HP < 50%", "not last man standing", "has Benediction ×2");
  - **forced skills** (`m_IsForced True`): the AI must use them when their conditions are met. Example: the Drummer's alternate *Focus Fire* fires on a hero under 50% HP instead of a random one. **(wiki note + data)** [W-DRUM, D-WB drummer]
  - **round-start and round-end skills** (`m_Type start_round`), used automatically;
  - **skill pairs** (`m_MatchingSkillIds`).
- **Targeting constraints** (data `ActorControllerBase` fields `forcedTargetActorGuids`, `stealthedPotentialTargetActorGuids`):
  - If any reachable target has **Taunt**, the AI must pick among taunters.
  - **Stealthed** units are excluded unless no other target exists.
  - Boss mechanics add their own focus tokens (e.g. "Seen").
- Patch notes describe targeting changes per skill ("Focus Fire is more likely to target Heroes at lower health", 2023-05-08). This implies per-skill target preference is set in data, not by a global brain. [P-2023-05-08]

**Recommended implementation (inferred):**
1. Build the list of valid skills: off cooldown, conditions met, launchable from the current rank, with at least one valid target.
2. If any forced skill is valid, use it.
3. Otherwise pick uniformly at random.
4. For the target: apply the Taunt filter, then the Stealth filter, then any skill-specific target condition, then pick uniformly at random.

Red Hook has not published DD2 weightings. A uniform pick is the most likely reading of "Random", but this is **(unknown)**.

## A11. Ambush, retreat, stalling, Flame (brief)

- **Battle modifiers** ("Enemy Advantage") roll per fight. Their chance rises with low Flame and with Loathing.
  - *Ambush!* gives a free Shuffle of the hero party at combat start (ignores Move RES).
  - Others: Elite (+20% HP, +20% DMG), Hastened (+2 SPD; data +4), Sturdy (2 Block+, +33% Move RES), Hale (+15% DoT RES), Impervious (+Stun/Debuff RES), Infectious (+1 DoT duration), Frenzied, Entropic, Prowling, Vengeful, Intimidating, Dormant.
  - **(wiki + data)** [W-BM, W-FLAME]
- **Retreat.** It was not available in standard Confessions combat for most of DD2's life. Since v2.02 it is an optional run mutator ("The Dam"), costing +2 Loathing and +2 stress to every hero. **(patch)** [P-2025-07] The 2024 data also defines retreat costs: torch −20, +2 stress per hero, 1 negative quirk. **(data)**
- **Stalling.** From round 3, if ≥3 heroes face ≤2 enemies and the party is not damaging them, a stall penalty applies: Flame −10. The stress penalty was disabled in Feb 2024. **(data + patch)** [D-WB combat_rules, P-2024-02-02]
- **Flame** (0–100) replaces DD1's torch.
  - High or low Flame gives confession-specific effects: party DBR ±3/6/9, round-start tokens (Blind, Vulnerable, Speed, Strength) on one side, and +15/33/100% Enemy Advantage chance at low Flame.
  - At 0 Flame a Cultist ambush happens.
  - **(wiki)** [W-FLAME]
- **End of battle.** `m_BattleEndMinHealthHealUpToPercent = 0.2` suggests heroes are healed up to at least 20% HP after a fight. **(data; meaning inferred)**

## A12. Things I could not pin down (DD2)

1. Turn-order **tie-breaking** (a `m_SpeedTieBreaker` field exists, generation unknown) and whether the 0–6 roll is an integer.
2. **Damage rounding**, and whether there is a minimum of 1.
3. Exact **enemy AI weights** (likely uniform random among valid choices; not confirmed).
4. Whether **token stacks share one timer** or each has its own (wikis disagree).
5. Whether **Guard redirects AoE** in the current build.
6. Whether **Vulnerable** is resistable now (EA patch said no; 2024 data says yes).
7. Whether **Taunt** loses one stack per forced attack (data consume type suggests yes; no wiki statement).
8. In-game presentation of the **Pass** skill.
9. Per-hero **swap ranges** after the 2025 Hellion and Leper reworks.
10. Exact **out-of-combat meltdown** handling.

---

# Part B: Darkest Dungeon 1 comparison appendix (short)

Sources: wiki.gg DD1 pages, the official DD1 modding guide [MOD1], and data-mined monster brains [PR].

| Topic | DD1 rule | Differs from DD2? |
|---|---|---|
| Ranks and size | 4 ranks per side; large (2-rank) monsters, bosses up to 4; hit at most once per attack [W-CM1] | Same |
| Corpses | Monsters (not heroes) leave corpses. **No corpse if killed by a crit or by DoT**, or for "small" monsters. A corpse **decays at the end of the 4th round** after it appears. It has 0% Bleed/Blight RES and 200% Move/Debuff/Stun RES, no PROT or DODGE, and HP is "a portion" of the monster's max HP (exact formula unconfirmed). Random-target skills skip corpses. [W-CORPSE1] | DD2: heroes leave corpses too, crit/DoT kills still leave them, decay after 3 rounds |
| Initiative | `SPD + 1..8` each round; ties go to **heroes before enemies**, then **lower rank first** [W-CM1]. Multi-turn bosses roll each turn (community: "1d8 + SPD"). | DD2 uses `+0..6` and −2 per extra turn |
| Hit chance | `ACC − DODGE`, plus a hidden **+5** after all modifiers. A displayed ≥95% always hits; every attack has at least 5%. A hidden **+4 ACC** per consecutive miss after the first. Rules file: `cutoffAlwaysHit 0.95`, `consecutive_miss_reduction_acc_buff 0.04`. Practical form: `p = clamp(ACC−DODGE, 0, 95) + 5`. [W-CM1] | DD2 has no ACC or DODGE |
| Damage | Hero damage = weapon range × (1 + skill DMG mod), then other modifiers; monster damage = skill range. PROT is a % reduction, **capped at 80%**. DoT ignores PROT; a few skills ignore PROT. [W-CM1] | DD2 has no PROT (Block tokens instead) |
| Crit | **150% of max damage**. Status chance +20%. Bleed/Blight last 50% longer (rounded up), usually +2 turns. Hero crit = weapon CRIT + skill CRIT mod. Heals: fixed 12% (single target) or 5% (multi-target) crit chance, ×2 heal, −4 stress. [W-CRIT1] | Same ×1.5; DD2 heals crit ×1.5 at 5% |
| Crit stress | Receiving a crit: **+10** stress, and each ally has a 50% chance of +5. Landing a crit: −3 to self, and each ally has a 25% chance of −3, plus a class crit buff. Killing a monster: 50% chance of −3. [W-CRIT1, W-STRESS1] | DD2: ±1 on a 0–10 scale |
| Status vs resist | **Subtractive**: `P(apply) = skill_chance − target_resist` (+20% on crit). Skill chances often exceed 100%. Self-moves always succeed. [W-MOVE1, W-DEBUFF1] | DD2 uses a separate resist roll with pierce |
| Resist growth | +10% per Resolve level to Stun, Blight, Bleed, Move, Debuff and Trap; Disease and Deathblow do not grow. Hero stun RES capped at 160%. [W-RESOLVE, W-STUN1] | none |
| Stun | Skip the next turn. On recovery: **+50% Stun RES** buff until the next turn start, stacking (+100%…) while the unit stays stunned. A 2016 forum post says +40% **(conflict)**. Stun cancels Guard and Riposte. [W-SE1, W-STUN1] | DD2: +50% (since 2025), non-stacking token |
| Bleed/Blight | Tick at the **start of the holder's turn**. Default 3 turns. Stacks **individually** (tooltip shows totals). Ignores PROT. Death by DoT leaves no corpse. A DoT tick on Death's Door forces a deathblow check. [W-SE1, W-DOT1] | Same idea |
| Burn (DD1 DLC *The Wildlander*, Runaway) | **Not resistable.** Ticks at **turn end**. Deals its stack value, then halves (rounded down). Additive stacking. Crit adds +50% (rounded up). Spreads on death ("Wildfire"). [W-DOT1] | DD2 Burn behaves like Bleed |
| Buffs/debuffs | Default 3 "rounds", in practice decremented at the **end of the holder's turn**. Stack indefinitely, each instance on its own timer. Trap debuffs last ~12. [W-BUFF1, W-DEBUFF1] | DD2 uses capped tokens and turn- or round-based buffs |
| Mark | Cannot be resisted (the skill can still miss); 3 turns. No effect by itself; bonus damage for "vs marked" skills. AI preference: marked-target weight 2/3/4 against random-target weight 1, i.e. **66.7% / 75% / 80%** on Apprentice / Veteran / Champion. [W-MARK1, PR] | DD2 uses Taunt and Combo instead |
| Guard | Redirects direct attacks and their effects to the guard, which uses its own DODGE and PROT. ~3 turns. An AoE that also hits the guard ignores the redirect. Stunning the guard ends it. No guard chains. [W-GUARD1, W-SE1] | DD2 uses a token |
| Riposte | Counter on being targeted by a damaging attack, **even if dodged**. Fixed riposte ACC (HWM 85, MAA 90, Duelist 100), weapon damage. Not while stunned; not from DoT. [W-RIP1] | DD2 uses a token |
| Stealth | Cannot be targeted directly. Multi-target skills hit stealthed units only if they also target a non-stealthed one. Enemies that start stealthed lose it after 2 rounds. [W-STEALTH1] | DD2 has 1–2 stacks with per-turn decay |
| Death's Door | DBR base **67%** (Flagellant 73%), **cap 87%**. Penalties: −10 ACC, −25% DMG, −5 SPD, +33% stress. Recovery debuff until quest end: −2 ACC, −5% DMG, −1 SPD, +10% stress. [W-DD1] | DD2: 60%, −10% per survived check, 33–90% |
| Stress | 0–200 scale. **Resolve check at 100**: base **25% Virtue / 75% Affliction** (`affliction_base_onset_chance` 0.75 [MOD1]), −5% Virtue per level under the dungeon level, clamped 1–95%. Virtue sets stress to **45** (another page says 40–45). **200 = heart attack**: to Death's Door, or death if already on it (ignores DBR); stress → 170. A Virtuous hero at 200 loses the virtue and stress → 0. [W-STRESS1, W-VIRT, W-HA] | DD2: 0–10, 80/20 |
| Affliction behaviour | Each turn, ~29–42% total "act-out" chance depending on the affliction: party stress, move, pass, random skill, attack ally, attack self, mark self. Never twice in a row for the same hero, nor back-to-back between heroes. Barks give 6 stress (party or one ally). Afflictions: −15% to all resists, −10% max HP, plus stat changes. Affliction weights: base 4, +2 per past occurrence. [W-AFF] | No DD2 equivalent; relationship act-outs instead |
| Monster AI | "Monster brain" with **skill desires** (weighted random among valid skills: random/specific/heal/status/ally-alive/performing-turn) and **target desires** (random_target, marked_target, health_target, stress_target, resistance_target, rank_target). Some desires are re-weighted per difficulty or "first action". [MOD1, PR] | DD2: "Random" controller with conditions and forced skills |
| Surprise | Unscouted fights: 10% each way. Scouted: 25% to surprise monsters, 0% to be surprised. Light modifies these (0 light: +40% heroes surprised). Max 65%. Surprised heroes are **shuffled** and cannot retreat in round 1. Surprised monsters **act last** in round 1. Shambler/Fanatic/camp ambush always surprise. [W-SURP] | DD2: "Ambush!" modifier (shuffle) |
| Retreat | ~70% success, +5% per failed attempt (community/wiki; a `combat_retreat_chance` exists in `rules.json` but its value was not seen). Costs 25 stress. Not allowed from some bosses. [W-RETR, MOD1] | DD2: optional mutator, +2 stress |
| Light (torch 0–100) | Radiant (>75): +25% to surprise monsters, +7.5 hero DODGE. 26–50: +20% stress, monster +5 ACC / +10% DMG. 0: +40% stress, monster +12.5 ACC / +12.5% DMG (25% on Darkest), +5% monster crit, +3% hero crit, more loot. [W-LIGHT] | DD2: Flame |
| Skills | 7 per class, **4 equipped**, **5 levels** each (ACC, DMG mod, CRIT and effects scale per level). Example: Crusader *Smite* launches from ranks 1,2, targets ranks 1,2, +0% DMG, ACC 85→105, CRIT 0→4%. Target syntax in data: plain ranks = choose one; `~` = all listed ranks (e.g. "1+2"); `@` = friendly; `?` = random listed rank. `.move` = back/forward amounts. `.per_battle_limit`. [W-CRUS1, MOD1] | DD2: 5 equipped, base and "+" versions, cooldowns |

Note: the fan-made Unity port of DD1 (Reinisch/Darkest-Dungeon-Unity) uses simplified formulas (e.g. initiative SPD + 0..2 plus a fraction; crit = rolled damage × 1.5). **It was deliberately not used as a source.**

---

# Implementation notes (pseudo-code, DD2 model)

```gdscript
# ---------- data ----------
# Unit: hp, max_hp, spd, size, rank, team, stress (heroes 0..10), resists{bleed,blight,burn,disease,stun,move,debuff,death,stress},
#       pierce{...}, tokens{type -> {count, turns_left}}, dots[], buffs[], cooldowns{skill->n}, uses_left{skill->n},
#       death_armor (enemies), turns_per_round, is_corpse, corpse_rounds_left
# Skill: launch_ranks, target_ranks, friendly, self_only, multi_hit, dmg_base, dmg_range, crit_chance,
#        cooldown, uses_per_battle, tags, can_be_riposted, token_ignores, conditions, forced, execution, effects[]

# ---------- round ----------
func start_round():
    order = []
    for u in living_non_corpse_units():
        for k in range(u.turns_per_round):
            spd = u.spd + (100 if u.consumed_speed_token_last_round_end else 0)
            order.append({unit=u, key=spd + randi_range(0, 6) - 2*k, tie=randf()})   # roll may be float in the original (unknown)
    order.sort_custom(func(a, b): return a.key > b.key or (a.key == b.key and a.tie > b.tie))
    forbid_consecutive_monster_turns(order)        # since 2023-03 (re-insert the later turn elsewhere)
    run_start_round_skills()                        # e.g. Drummer ORDER skills

func take_turn(u, is_extra_action := false):
    if not is_extra_action:
        tick_dots_and_regen(u)                      # one net instance; may trigger a deathblow check
        if u.dead: return
    if u.tokens.stun: consume(u, "stun"); u.add_buff("stun_res_+50%", until="own_turn_start"); return
    if u.tokens.daze: consume(u, "daze"); move_turn_to_round_end(u); return
    # combat item = free action here (heroes)
    act(u)                                          # skill | move (swap) | pass
    if not is_extra_action:
        tick_cooldowns(u); tick_token_durations_turn_end(u)   # stealth & immobilize: -1 stack

func end_round():
    convert_speed_tokens_to_next_round_bonus()
    tick_round_based_buffs(); decay_corpses()       # corpse lasts 3 rounds
    check_stall()                                   # round>=3, >=3 heroes vs <=2 enemies, no damage -> Flame -10

# ---------- attack ----------
func resolve(attacker, skill, primary_target):
    targets = skill.multi_hit ? all_valid_in(skill.target_ranks) : [primary_target]
    blind_miss = false
    if attacker.has("blind") and not skill.ignores("blind"):
        blind_miss = randf() < 0.5; consume(attacker, "blind")           # one roll per skill use (inferred)
    crit = consume_if(attacker, "crit") or randf() < attacker.crit_mod + skill.crit_chance
    for t in targets:
        t = redirect_if_guarded(t, skill)                                # consumes 1 Guard
        dodged = false
        if not skill.ignores("dodge"):
            if t.has("dodge_plus"): dodged = randf() < 0.75; consume(t, "dodge_plus")
            elif t.has("dodge"):    dodged = randf() < 0.50; consume(t, "dodge")
        if blind_miss or dodged:
            consume_all(attacker, ["strength", "weak"]); continue        # Block/Vuln NOT consumed on a miss
        if skill.is_damaging():
            base = (skill.dmg_base + skill.dmg_range) * 1.5 if crit else skill.dmg_base + randi_range(0, skill.dmg_range)
            atk = 1.0 + attacker.dmg_pct_sum() + (0.5 if consume_if(attacker, "strength") else 0.0)
            dfn = 1.0 + t.dmg_recv_pct_sum()
            if t.has("block_plus"): dfn -= 0.75; consume(t, "block_plus")
            elif t.has("block"):    dfn -= 0.50; consume(t, "block")
            if t.has("vulnerable"): dfn += 0.50; consume(t, "vulnerable")
            dmg = base * atk * max(dfn, 0.0)
            if consume_if(attacker, "weak"): dmg *= 0.5                  # v2.02+: Weak applied last
            apply_damage(t, roundi(dmg), skill)                          # rounding: unknown
        for e in skill.effects: try_apply(e, attacker, t, crit)
        maybe_riposte(t, attacker, skill)                                # first riposter only
    stress_triggers_on_crit(attacker, targets, crit)                     # +1@80% / -1@50% etc.

func try_apply(e, src, t, crit):
    if randf() >= e.chance: return
    if e.ignore_resist or e.is_self_negative: return e.apply(t)
    r = t.resists[e.resist_type] - src.pierce[e.resist_type] - (0.2 if crit else 0.0)
    r = clamp(r, RES_MIN[e.resist_type], RES_MAX[e.resist_type])      # death 0.33..0.90, disease <=0.95
    if randf() >= r: e.apply(t)                                          # tokens respect limits, negation, priority

func apply_damage(t, dmg, skill):
    if t.at_deaths_door:
        if t.is_enemy:
            if skill.execution >= t.death_armor and t.death_armor_lethal(): return kill(t)
            if t.death_armor > 0: t.death_armor -= 1; return
            return kill(t)
        if randf() < clamp(t.resists.death, 0.33, 0.90):
            t.add_buff("dbr_-10%", until="combat_end")
        else: kill(t)
        return
    t.hp -= dmg
    if t.hp <= 0:
        if t.is_hero or t.death_armor > 0:
            t.hp = 0; enter_deaths_door(t)      # -3 SPD, +1 Weak (heroes), stress triggers
        else: kill(t)                           # becomes corpse (if the class has one); +1 stress to each hero ally if a hero

func on_stress_change(h):
    if h.stress >= 10:
        if randf() < 0.8 + h.meltdown_mod: meltdown(h)   # hp=min(hp,10%); stress=1; DBR-15 (inn); StressRes+40 (3 rds); affinity -3; 40% quirk
        else: resolute(h)                                # heal 67%; stress=0; DBR+15 (inn); DebuffRes+50 & StressRes+40 (3 rds); affinity +2

# ---------- enemy AI ----------
func ai_choose(e):
    valid = skills_off_cooldown_with_conditions_and_targets(e)
    forced = valid.filter(func(s): return s.forced)
    skill = forced.pick_random() if forced else valid.pick_random()     # uniform pick = inferred
    targets = valid_targets(skill)
    taunters = targets.filter(func(t): return t.has("taunt"))
    if taunters: targets = taunters; consume_one(taunt)                  # consume rule inferred
    visible = targets.filter(func(t): return not t.has("stealth"))
    if visible: targets = visible
    return [skill, targets.pick_random()]
```

### DD1 deltas, if you ever need them
```
round_speed = SPD + randi_range(1, 8); tie: hero > enemy, then lower rank
hit = randf()*100 < clamp(ACC - DODGE + 4*consecutive_misses, 0, 95) + 5
dmg = ceil?(roll(range) * (1+dmg_mods) * (1 - min(PROT, 0.8)))   # rounding unconfirmed
crit dmg = max * 1.5; status P = skill_chance - resist (+0.2 on crit)
DD: survive if randf() < min(DBR, 0.87); heart attack at 200 stress
resolve at 100: 25% virtue (± level penalty, clamp 1–95%)
```

---

# Sources

### DD2: data and code (primary, data-mined)
- [D-WB] DD2 `StreamingAssets/Excel` CSV exports, mirrored in a mod repo (Jan 2024 data): https://github.com/woodbrick/darkest-dungeon-2
  - Files used: `combat_rules_data_export.Group.csv`, `token_data_export.Group.csv`, `dots_data_export.Group.csv`, `resist_data_export.Group.csv`, `overstress_data_export.Group.csv`, `stress_triggers_data_export.Group.csv`, `actor_status_data_export.Group.csv`, `pass_data_export.Group.csv`, `move_data_export.Group.csv`, `skill_block_data_export.Group.csv`, `skill_modifier_data_export.Group.csv`, `battle_modifier_data_export.Group.csv`, `buff_data_export.Group.csv`, `effect_data_export.Group.csv`, `condition_data_export.Group.csv`, `hero_*_data_export.Group.csv`, `shared_ghoul_data_export.Group.csv`, `lost_battalion_drummer_data_export.Group.csv`, `plague_eater_corpse_data_export.Group.csv`
- [D-AB] Decompiled DD2 class and field signatures (Cecil dump, no method bodies): https://github.com/syyzit/dd2-autobattler/tree/master/_tools/cecil-scan/dump (`Battle.txt`, `CombatRules.txt`, `SkillCalculation.txt`, `ActorControllerBase.txt`, `ActorControllerTypes.txt`, `ActorInstance.txt`)

### DD2: wikis
- [W-CM2] https://darkestdungeon.wiki.gg/wiki/Combat_Mechanics_(Darkest_Dungeon_II)
- [W-TOK] https://darkestdungeon.wiki.gg/wiki/Tokens
- [W-CRIT2] https://darkestdungeon.wiki.gg/wiki/Critical_Hit_(Darkest_Dungeon_II)
- [W-DD2] https://darkestdungeon.wiki.gg/wiki/Death%27s_Door_(Darkest_Dungeon_II)
- [W-CORPSE2] https://darkestdungeon.wiki.gg/wiki/Corpse_(Darkest_Dungeon_II)
- [W-STRESS2] https://darkestdungeon.wiki.gg/wiki/Stress_(Darkest_Dungeon_II)
- [W-DOT2] https://darkestdungeon.wiki.gg/wiki/Damage_over_Time_(Darkest_Dungeon_II)
- [W-REL] https://darkestdungeon.wiki.gg/wiki/Relationships
- [W-BM] https://darkestdungeon.wiki.gg/wiki/Battle_Modifiers
- [W-FLAME] https://darkestdungeon.wiki.gg/wiki/Flame
- [W-ITEMS] https://darkestdungeon.wiki.gg/wiki/Combat_Items
- [W-HWM2] https://darkestdungeon.wiki.gg/wiki/Highwayman_(Darkest_Dungeon_II)
- [W-SKILLDOC] https://darkestdungeon.wiki.gg/wiki/Template:HeroSkill2/doc
- [W-DRUM] https://darkestdungeon.wiki.gg/wiki/Drummer
- [W-GHOUL2] https://darkestdungeon.wiki.gg/wiki/Ghoul_(Darkest_Dungeon_II)
- [F-TOK] https://darkestdungeon.fandom.com/wiki/Tokens
- [F-DD2] https://darkestdungeon.fandom.com/wiki/Death%27s_Door_(Darkest_Dungeon_II)
- [F-STRESS2] https://darkestdungeon.fandom.com/wiki/Stress_(Darkest_Dungeon_II)
- [FX] (Early Access era, low weight) https://darkestdungeon2.wiki.fextralife.com/Combat, https://darkestdungeon2.wiki.fextralife.com/Status+Effects

### DD2: official patch notes (Red Hook, mirrored on wiki.gg)
- [P-2022-02-23] https://darkestdungeon.wiki.gg/wiki/23_February_2022_Patch (initiative d8 → d6)
- [P-2022-07-19] https://darkestdungeon.wiki.gg/wiki/19_July_2022_Patch (Vulnerable not resistable, EA)
- [P-2022-10-11] https://darkestdungeon.wiki.gg/wiki/11_October_2022_Patch (stealth stacking, base DBR 75 → 60, extra-action initiative penalty, boss DBR modifier)
- [P-2023-01-12] https://darkestdungeon.wiki.gg/wiki/12_January_2023_Patch (Meltdown/Resolute, affinity redesign)
- [P-2023-03-16] https://darkestdungeon.wiki.gg/wiki/16_March_2023_Patch (no consecutive monster turns)
- [P-2023-05-08] https://darkestdungeon.wiki.gg/wiki/May_8_2023_Patch (1.0 release notes)
- [P-2023-09-14] https://darkestdungeon.wiki.gg/wiki/14_September_2023_Patch (Death Armor / Death's Door v2)
- [P-2024-02-02] https://darkestdungeon.wiki.gg/wiki/Infernal_Pursuits_Retail (non-damaging skill crits, stall stress disabled)
- [P-2025-01] https://darkestdungeon.wiki.gg/wiki/Kingdoms_Release (stun recovery buff 40 → 50%)
- [P-2025-07] https://darkestdungeon.wiki.gg/wiki/Steadfast_Stewards_Retail_Release (v2.02: Weak last, DD Weak 2 → 1, no crit DoT +2, retreat mutator, random token removal)
- [P-2025-SS2] https://darkestdungeon.wiki.gg/wiki/Steadfast_Stewards_2_Retail_Release (v2.04: 0-damage crit fix)
- Last Light (2024-04) notes: https://darkestdungeon.wiki.gg/wiki/Last_Light

### DD2: other
- [GS] Corpse timer (~3 rounds): https://www.gameskinny.com/tips/darkest-dungeon-2-how-to-remove-corpses/
- [PCG] Dodge vs Block consumption: https://www.pcgames.de/Darkest-Dungeon-2-Spiel-62188/Tipps/Guide-Roguelite-1419274/2/

### DD1
- [MOD1] Official *Darkest Dungeon Modding Guide* (Red Hook, Steam): https://steamcommunity.com/sharedfiles/filedetails/?id=819597757
- [PR] PizzaRat Review (data-mined monster brains and target desires): https://pizzarat105.github.io/PizzaRatReview/dd_map_test.html
- [W-CM1] https://darkestdungeon.wiki.gg/wiki/Combat_Mechanics_(Darkest_Dungeon)
- [W-CRIT1] https://darkestdungeon.wiki.gg/wiki/Critical_Hit_(Darkest_Dungeon)
- [W-SE1] https://darkestdungeon.wiki.gg/wiki/Status_Effects_(Darkest_Dungeon)
- [W-DD1] https://darkestdungeon.wiki.gg/wiki/Death%27s_Door_(Darkest_Dungeon)
- [W-STUN1] https://darkestdungeon.wiki.gg/wiki/Stun_(Darkest_Dungeon)
- [W-MOVE1] https://darkestdungeon.wiki.gg/wiki/Move_(Darkest_Dungeon)
- [W-DEBUFF1] https://darkestdungeon.wiki.gg/wiki/Debuff_(Darkest_Dungeon)
- [W-BUFF1] https://darkestdungeon.wiki.gg/wiki/Buff_(Darkest_Dungeon)
- [W-MARK1] https://darkestdungeon.wiki.gg/wiki/Mark
- [W-GUARD1] https://darkestdungeon.wiki.gg/wiki/Guard_(Darkest_Dungeon)
- [W-RIP1] https://darkestdungeon.wiki.gg/wiki/Riposte_(Darkest_Dungeon)
- [W-STEALTH1] https://darkestdungeon.wiki.gg/wiki/Stealth_(Darkest_Dungeon)
- [W-CORPSE1] https://darkestdungeon.wiki.gg/wiki/Corpse
- [W-DOT1] https://darkestdungeon.wiki.gg/wiki/Damage_over_Time_(Darkest_Dungeon)
- [W-STRESS1] https://darkestdungeon.wiki.gg/wiki/Stress_(Darkest_Dungeon)
- [W-AFF] https://darkestdungeon.wiki.gg/wiki/Affliction
- [W-VIRT] https://darkestdungeon.wiki.gg/wiki/Virtue
- [W-HA] https://darkestdungeon.wiki.gg/wiki/Heart_attack
- [W-LIGHT] https://darkestdungeon.wiki.gg/wiki/Light_Meter
- [W-SURP] https://darkestdungeon.wiki.gg/wiki/Surprise
- [W-RETR] https://darkestdungeon.wiki.gg/wiki/Retreating
- [W-RESOLVE] https://darkestdungeon.wiki.gg/wiki/Resolve_Level
- [W-CRUS1] https://darkestdungeon.wiki.gg/wiki/Crusader_(Darkest_Dungeon)
