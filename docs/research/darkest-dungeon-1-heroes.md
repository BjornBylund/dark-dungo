# Darkest Dungeon 1 heroes: rank-1 combat kits for eight classes

Researched on 2026-10-27 for the Godot project `darko-dungo`. Our heroes are taking these **Darkest Dungeon 1 (DD1, 2016)** class names and their 7 combat skills. This document gives the raw DD1 numbers to translate from: base stats at Resolve level 0 with rank-1 weapon and armour, and every combat skill at skill rank 1. It covers the Crusader, Grave Robber, Arbalest, Vestal, Man-at-Arms, Plague Doctor, Jester and Flagellant (*Crimson Court* DLC). Higher ranks, camping skills, trinkets and quirks are left out. The translation into our DD2-style tokens is not done here.

## How to read this document

Every claim is tagged with its source:

| Tag | Meaning |
|---|---|
| **(wiki)** | darkestdungeon.wiki.gg hero pages, read as raw wikitext (the `CharacterInfobox` and `Heroability` templates). It reflects the current game (v1.x with DLC). |
| **(data)** | The current DD1 game files: each hero's `<hero>.info.darkest` plus the effect lines its skills use, from the game's `effects/*.effects.darkest`. These are copies in a third-party mod repository [D-V]; see the caveat below. |
| **(wiki+data)** | Both sources give the same value. Most rows are this. |
| **(data-2016)** | The 2016 snapshot in Reinisch's Unity port [D-U], also used by [darkest-dungeon-town.md](darkest-dungeon-town.md). Used here only to show how much changed since. |
| **(inferred)** | My own reading or arithmetic. Treat as a suggestion, not fact. |

**Conflict** marks places where sources disagree; both values are given. **Unconfirmed** marks things no source states.

> **About [D-V].** A Korean balance mod repository (GD-JM/darkest-dungeon-rebalance) keeps a read-only "vanilla sheet" per hero. Its generator script says the sheet is built from the game folder's backup of the official `.info.darkest` file, and that effect lines come from the game's own effect files. Each sheet ends with the full original file. The game version is not stated. The files contain *Crimson Court* district tags (`altar_of_light`) and the same numbers as today's wiki, so they look current (inferred). Every rank-1 number in them matches the wiki except one (see Conflicts).

> **About [D-U].** The 2016 snapshot is badly out of date for skills. Three examples (data-2016):
> - Stunning Blow was −75% damage; it is −50% now.
> - The Jester's Finale (`heroic_end`) was +150% damage from rank 1 only; it is +50% from ranks 1–2 with 140 accuracy now.
> - Shadow Fade was a stun attack; it is now a self-stealth skill.
>
> It is not used for any number below.

> **Source access.** wiki.gg loaded fine through WebFetch, but scripted downloads from it got HTTP 403. The GitHub files downloaded directly. Fandom was not consulted, because wiki.gg and the game data already agree on nearly every number.

### Notation used in the skill tables

- **Ranks** run 1 (front) to 4 (back), on both sides. **Launch** = the ranks the hero must stand in to use the skill. (wiki+data)
- **Target:** `E2/E3/E4` = one enemy chosen from those ranks. `E1+E2` = hits **both** at once. `all E` / `all A` = every enemy / every ally. `A1–A4 (one)` = one ally. "self" = the user only. (wiki+data; the data writes these as `234`, `~12`, `~1234`, `@1234` and an empty target.)
- **DMG** = damage modifier on the hero's weapon damage. +0% = full weapon damage; −40% = 60% of it (inferred). "none" = the skill deals no damage (−100% in both sources).
- **ACC** = the skill's base accuracy. Every hero's weapon adds +0 at rank 1. (wiki+data)
- **Crit** = the skill's crit modifier. It adds to the hero's base crit from the stats table (inferred). "no crit" = the skill cannot crit (`is_crit_valid False` in the data; blank in the wiki).
- **(100% base)** = the status effect's base chance. The target's matching resistance is subtracted before the roll. (wiki Move page, which states it for Move; the same model for other statuses is inferred)
- **Durations** are in rounds ("rds"). "battle" = until the fight ends. (wiki+data)
- **Torch** = DD1's light meter, 0–100. It is party-wide.

> **Scale note.** DD1 stress runs 0–200: affliction or virtue at 100, heart attack at 200. This project uses 0–10, so divide DD1 stress numbers by 10 (Inspiring Cry's −5 stress is −0.5 here) (inferred).

---

## TL;DR: the numbers you will most likely need

```
Class          HP SPD Dodge PROT ACC Crit DMG   Move skill    Resist: Stun Blight Dis DthBlw Move Bleed Debuff Trap
Crusader       33  1    5    0    0   3%  6-12  back1 fwd1             40   30    30   67    40   30    30    10
Grave Robber   20  8   10    0    0   6%  4-8   back2 fwd2             20   50    30   67    20   30    30    50
Arbalest       27  3    0    0    0   6%  4-8   back2 fwd0             40   30    30   67    40   30    30    10
Vestal         24  4    0    0    0   1%  4-8   back1 fwd1             30   30    30   67    30   40    30    10
Man-at-Arms    31  3    5    0    0   2%  5-9   back2 fwd2             40   30    30   67    40   40    30    10
Plague Doctor  22  7    0    0    0   2%  4-7   back1 fwd1             20   60    50   67    20   20    50    20
Jester         19  7   15    0    0   4%  4-7   back3 fwd3             20   40    20   67    20   30    40    30
Flagellant     22  6    0    0    0   2%  3-6   back1 fwd3             50   30    40   73    50   65    30     0
                                                                          (all wiki+data; resistances in %)

Per-battle limits  = Bulwark of Faith 1, Toxin Trickery 1, Bolster 1, Blinding Gas 3,
                     Emboldening Vapours 2, Finale 1, Solo 2, Exsanguinate 3, Redeem 2   (wiki+data)
HP-gated           = Exsanguinate and Redeem: only while the Flagellant is at or below 40% HP (wiki+data)
Cannot target self = Defender, Reclaim, Redeem, Endure, Suffer                          (data)
Every class has exactly 7 combat skills; a hero equips 4 (data).
```

---

## 1. Crusader

Base stats: see TL;DR. Weapon "Battered Longsword", armour "Rusty Hauberk". (wiki+data)
- **Move skill:** back 1, forward 1, from any rank. (data; the wiki infobox has no move fields for him)
- **On crit:** +15% PROT to himself. (wiki)
- Religious. A new Crusader always has Smite. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self / party | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Smite | 1,2 | E1/E2 | +0% | 85 | +0% | +15% DMG if the target is Unholy | — | — | wiki+data |
| Zealous Accusation | 1,2 | E1+E2 | −40% | 85 | −4% | — | — | — | wiki+data |
| Stunning Blow | 1,2 | E1/E2 | −50% | 90 | +0% | Stun (100% base) | — | — | wiki+data |
| Bulwark of Faith | 1,2 | self | — | — | — | — | +20% PROT (battle); Mark self (battle); Torch +24 | 1 per battle | wiki+data |
| Battle Heal | 1–4 | A1–A4 (one) | heal 2–3 HP | — | — | — | — | — | wiki+data |
| Holy Lance | 3,4 | E2/E3/E4 | +0% | 85 | +6.5% | +15% DMG if the target is Unholy | Forward 1 | — | wiki+data |
| Inspiring Cry | 1–4 | A1–A4 (one) | heal 1 HP | — | — | Stress −5 | Torch +5 | — | wiki+data |

- Bulwark's buff, mark and torch apply on hit or miss. (data)
- Battle Heal and Inspiring Cry have no self-target ban, so he can target himself (inferred from the data).

## 2. Grave Robber

Base stats: see TL;DR. (wiki+data)
- **Move skill:** back 2, forward 2. (wiki+data)
- **On crit:** +10 Dodge to herself. (wiki)
- A new Grave Robber always has Shadow Fade. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Pick to the Face | 1,2,3 | E1/E2 | −15% | 90 | +1% | Ignores PROT | — | — | wiki+data |
| Lunge | 3,4 | E1/E2/E3 | +40% | 95 | +8% | +20% DMG if the target is Blighted | Forward 2 | — | wiki+data |
| Flashing Daggers | 2,3,4 | E2+E3 | −33% | 90 | −5% | −20% Bleed resist (100% base, 3 rds) | — | — | wiki+data |
| Shadow Fade | 1,2 | self | — | — | — | — | Back 2; Stealth (2 rds); +80% DMG and +4% crit (2 rds); +10 Dodge (4 rds) | — | wiki+data |
| Thrown Dagger | 2,3,4 | E2/E3/E4 | −10% | 90 | +8% | +25% DMG if Marked; +20% DMG if Blighted | +5 ACC (on hit; 4 rds) | — | wiki+data (duration wiki only) |
| Poison Dart | 2,3,4 | E1–E4 (one) | −60% | 95 | +7.5% | Blight 2/rd for 4 rds (100% base); −20% Blight resist (100% base, 3 rds) | — | — | wiki+data |
| Toxin Trickery | 1–4 | self | — | — | — | — | Cure own Blight and Bleed; +9 Dodge and +2 SPD (battle) | 1 per battle | wiki+data |

- Thrown Dagger's +5 ACC is applied once per use and only on a hit. The data line has no duration; the wiki says 4 rds. (data; wiki)

## 3. Arbalest

Base stats: see TL;DR. (wiki+data)
- **Move skill:** back 2, forward 0, so she cannot step forward. (wiki+data)
- **On crit:** +33% DMG against Marked targets. (wiki)
- A new Arbalest always has Sniper Shot. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self / party | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Sniper Shot | 3,4 | E2/E3/E4 | +0% | 95 | +5% | +50% DMG and +9% crit if Marked | — | — | wiki+data |
| Suppressing Fire | 3,4 | E3+E4 | −80% | 95 | −10% | −15 ACC and −15% crit (100% base, 2 rds) | — | — | wiki+data |
| Sniper's Mark | 3,4 | E2/E3/E4 | none | 100 | no crit | Mark (3 rds); −20 Dodge (100% base, 2 rds) | — | — | wiki+data |
| Bola | 3,4 | E1+E2 | −50% | 95 | +2% | Knockback 1 (75% base) | — | — | wiki+data |
| Blindfire | 1–4 | random enemy, E1–E4 | −10% | 75 | +0% | — | +3 SPD (hit or miss; 4 rds) | — | wiki+data (duration wiki only) |
| Battlefield Bandage | 3,4 | A1–A4 (one) | heal 2–3 HP | — | — | +20% healing received (3 rds) | — | — | wiki+data (duration wiki only) |
| Rallying Flare | 1–4 | all E | none | 95 | no crit | Hits Stealthed enemies and removes Stealth | Torch +3. Every other hero: Stun removed, Mark removed, 60% chance of Stress −1 | — | wiki+data |

- Sniper's Mark has no damage and cannot crit. (wiki+data)
- Rallying Flare ignores Stealth when targeting. Its ally effects skip the Arbalest herself. (data)

## 4. Vestal

Base stats: see TL;DR. (wiki+data)
- **Move skill:** back 1, forward 1. (data; the wiki infobox has no move fields for her)
- **On crit:** +25% to her healing skills. (wiki)
- Religious. A new Vestal always has Divine Grace. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self / party | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Mace Bash | 1,2 | E1/E2 | +0% | 85 | +0% | +15% DMG if the target is Unholy | — | — | wiki+data |
| Judgement | 3,4 | E1–E4 (one) | −25% | 85 | +5% | — | Heal self 3 HP (on hit) | — | wiki+data |
| Dazzling Light | 2,3,4 | E1/E2/E3 | −75% | 90 | +5% | Stun (100% base) | Torch +6 | — | wiki+data |
| Divine Grace | 3,4 | A1–A4 (one) | heal 4–5 HP | — | — | — | — | — | wiki+data |
| Divine Comfort | 2,3,4 | all A | heal 1–3 HP each | — | — | — | — | — | wiki+data |
| Illumination | 1,2,3 | E1–E4 (one) | −75% | 90 | no crit | Hits Stealthed enemies and removes Stealth; −20 Dodge (100% base, 4 rds) | Torch +5 | — | wiki+data (duration wiki only) |
| Hand of Light | 1,2 | E1/E2/E3 | −50% | 85 | +1% | +15% DMG if the target is Unholy | +6 ACC and +25% DMG (hit or miss; 4 rds) | — | wiki+data (duration wiki only) |

- The wiki notes Illumination is the only damaging hero skill that can never crit. (wiki)
- Divine Comfort is the data's `gods_comfort`, Illumination is `gods_illumination`, and Hand of Light is `gods_hand`. (data)

## 5. Man-at-Arms

Base stats: see TL;DR. (wiki+data)
- **Move skill:** back 2, forward 2. (wiki+data)
- **On crit:** −33% stress taken. (wiki)
- A new Man-at-Arms always has Crush. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self / party | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Crush | 1,2 | E1/E2/E3 | +0% | 85 | +5% | — | — | — | wiki+data |
| Rampart | 1,2,3 | E1/E2 | −60% | 90 | +5% | Knockback 1 (100% base); Stun (100% base) | Forward 1 | — | wiki+data |
| Bellow | 1–4 | all E | none | 90 | no crit | −5 Dodge and −5 SPD (100% base, 3 rds); +5% crits received while Marked (100% base, 3 rds) | — | — | wiki+data (crit-received value wiki only) |
| Defender | 1–4 | A1–A4 (one, **not self**) | — | — | — | Guarded by him (3 rds) | +15% PROT (4 rds) | — | wiki+data (PROT duration wiki only) |
| Retribution | 1,2,3 | E1/E2/E3 | −75% | 85 | +2.5% | — | Mark self (2 rds); Riposte (3 rds) | — | wiki+data |
| Command | 1–4 | all A | — | — | — | +5 ACC, +4% crit, +15% DMG while Guarded (3 rds) | — | — | wiki (values) + data (targeting) |
| Bolster | 1–4 | all A | — | — | — | +5 Dodge (battle); −10% stress taken (battle) | — | 1 per battle | wiki+data |

- **Riposte attack** (from Retribution): −40% DMG, ACC 90, crit +0%, against any rank. It triggers when he is attacked, on a hit or a miss. (wiki+data)
- Defender first clears any existing Guard on both him and the target. (data)

## 6. Plague Doctor

Base stats: see TL;DR. (wiki+data)
- **Move skill:** back 1, forward 1. (data; the wiki infobox has no move fields for her)
- **On crit:** +20% chance on her Blight skills. (wiki)
- A new Plague Doctor always has Plague Grenade. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Noxious Blast | 2,3,4 | E1/E2 | −80% | 95 | +5% | Blight 5/rd for 3 rds (100% base); −5 ACC (100% base, 3 rds) | — | — | wiki+data |
| Plague Grenade | 3,4 | E3+E4 | −90% | 95 | +0% | Blight 4/rd for 3 rds (100% base) | — | — | wiki+data |
| Blinding Gas | 3,4 | E3+E4 | none | 95 | no crit | Stun (100% base) | — | 3 per battle | wiki+data |
| Incision | 1,2,3 | E1/E2 | +0% | 85 | +5% | Bleed 2/rd for 3 rds (100% base) | — | — | wiki+data |
| Battlefield Medicine | 3,4 | A1–A4 (one) | heal 1 HP | — | — | Cure Blight and Bleed | Cure own Blight and Bleed | — | wiki+data |
| Emboldening Vapours | 1–4 | A1–A4 (one) | — | — | — | +20% DMG and +3 SPD (battle) | — | 2 per battle | wiki+data |
| Disorienting Blast | 2,3,4 | E2/E3/E4 | none | 95 | no crit | Shuffle (100% base); Stun (100% base); clears all corpses on the enemy side | — | — | wiki+data |

## 7. Jester

Base stats: see TL;DR. (wiki+data)
- **Move skill:** back 3, forward 3. (wiki+data)
- **On crit:** +40% to his stress-healing skills. (wiki)
- A new Jester always has Harvest. (wiki+data)
- **Finale buffs:** most skills give him a self-buff that only boosts the skill Finale, for 8 rds. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Dirk Stab | 1–4 | E1/E2/E3 | +0% | 85 | +5% | Ignores Guard | Forward 1; Finale +30% DMG (8 rds, on hit) | — | wiki+data |
| Harvest | 2,3 | E2+E3 | −50% | 90 | +0% | Bleed 2/rd for 3 rds (100% base) | Finale +30% DMG (8 rds, on hit) | — | wiki+data |
| Finale | 1,2 | E1–E4 (one) | +50% | 140 | +5% | — | Back 3; −25 Dodge, −3 SPD and +100% stress taken (battle; cannot be cleared) | 1 per battle | wiki+data |
| Solo | 3,4 | all E (nothing applied to them) | none | 125 | no crit | — | Forward 3; Mark self (3 rds); +20 Dodge (4 rds); Finale +75% DMG and +8% crit (8 rds, on hit) | 2 per battle | wiki+data |
| Slice Off | 2,3 | E2/E3 | −33% | 95 | +8% | Bleed 3/rd for 3 rds (100% base) | Finale +30% DMG (8 rds, on hit) | — | wiki+data |
| Battle Ballad | 3,4 | all A | — | — | — | +5 ACC, +2% crit, +2 SPD (4 rds) | Finale +30% DMG and +8% crit (8 rds) | — | wiki+data (duration wiki only) |
| Inspiring Tune | 3,4 | A1–A4 (one) | — | — | — | Stress −8; −10% stress taken (duration **unconfirmed**) | Finale +30% DMG and +8% crit (8 rds) | — | wiki+data |

- Finale's self-debuffs cannot be removed by Medicinal Herbs. (wiki; the data marks them `buff_is_clear_debuff_valid false`)
- The wiki notes Solo is the only non-damaging skill that prevents enemy reinforcements. (wiki)

## 8. Flagellant (*Crimson Court* DLC)

Base stats: see TL;DR. (wiki+data)
- **Move skill:** back 1, forward 3. (wiki+data)
- **On crit:** +20% chance on his Bleed skills. (wiki)
- Religious. A new Flagellant always has Punish. (wiki+data)
- Only one Flagellant per party. (wiki+data)

| Skill | Launch | Target | DMG | ACC | Crit | On target | On self | Limit | Src |
|---|---|---|---|---|---|---|---|---|---|
| Punish | 1,2 | E1/E2 | +0% (**conflict**: wiki "100%") | 95 | +5% | Bleed 4/rd for 3 rds (100% base); −20% Bleed resist (100% base, 3 rds) | — | — | wiki+data |
| Rain of Sorrows | 1,2 | E3+E4 | −67% | 95 | +2% | Bleed 3/rd for 3 rds (100% base); −20% Bleed resist (100% base, 3 rds) | — | — | wiki+data |
| Exsanguinate | 1,2 | E1/E2 | +0% (**conflict**: wiki "100%") | 90 | +3% | Bleed 5/rd for 3 rds (100% base) | Heal 35% of max HP (on hit only); Exhaustion: −25% to his healing skills, −25% healing received, −3 SPD (3 rds) | 3 per battle; only at ≤40% HP | wiki+data |
| Reclaim | 1–4 | A1–A4 (one, **not self**) | — | — | — | Heal over time: 2 HP/rd for 2 rds | Bleed 3/rd for 3 rds (120% base, against his own Bleed resist) | — | wiki+data |
| Redeem | 1–4 | A1–A4 (one, **not self**) | heal 33% of the target's max HP | — | — | — | Heal 35% of max HP; Exhaustion (as Exsanguinate) | 2 per battle; only at ≤40% HP | wiki+data |
| Endure | 1–4 | A1–A4 (one, **not self**) | — | — | — | Stress −10 | Stress +10; +1 SPD (4 rds) | — | wiki+data (SPD duration wiki only) |
| Suffer | 1–4 | A1–A4 (one, **not self**) | — | — | — | Mark removed; its Bleed and Blight move to him | Takes those DoTs; Mark self (2 rds); −20% stress taken and +6% Death Blow resist (4 rds) | — | wiki+data |

His skills lean on class rules that live outside the skill lines:
- **At or below 40% HP:** +20% DMG and +7% crit. Exsanguinate and Redeem become usable. (wiki; the data has an `hp_reaction` at 0.40 and an HP range of 0–0.40 on both skills)
- **Death's Door:** every other party member heals 10% of max HP. He gets +5 ACC, +20% DMG, +2 SPD and +20% Stun, Bleed, Blight and Debuff resist. He gets no Death's Door recovery debuffs, but still gets heart-attack ones. (wiki; the data confirms the special buff set and the empty recovery list)
- **On death:** stuns all enemies (125% base) and heals the surviving party 10 HP. (wiki; the data has death reactions named "Flag Last Gift" and "Flag Last Insult", but their effect lines were not checked)
- Exhaustion cannot be removed by Medicinal Herbs. (wiki)

---

## Conflicts and gaps between the sources

- **Conflict: Flagellant damage, "100%" vs +0%.** The wiki's value field reads "100%" for Punish and Exsanguinate. Every other hero's full-damage skill reads "+0%" there. The data has `.dmg 0%` for both, the same as Smite or Crush. Most likely the wiki means "100% of weapon damage", which is the same thing (inferred). Use +0%.
- **Gap: effects with no duration in the data.** Some effect lines have no `.duration`. For these the wiki gives:
  - **4 rds** for plain stat buffs and debuffs: Thrown Dagger ACC, Blindfire SPD, Illumination Dodge, Hand of Light self-buff, Defender PROT, Battle Ballad, Endure SPD.
  - **3 rds** for named buffs: Punish and Rain of Sorrows bleed-resist debuff, Command, Battlefield Bandage, Exsanguinate and Redeem Exhaustion.

  The wiki pages also say "all buffs and debuffs last 3 rounds unless otherwise specified". So the 4-round values look like the engine's default for stat buffs, but no source says so (**unconfirmed**). Effects whose data line has a duration match the wiki every time.
- **Gap: named-buff values come from the wiki only.** Several effects point at named buffs (`buff_ids`) in a separate buff library, which was not read. Their numbers above are the wiki's:
  - −20% Bleed and Blight resist;
  - Bellow's +5% crits received while Marked;
  - Command's +5 ACC, +4% crit and +15% DMG while Guarded;
  - Bolster's −10% stress;
  - the Jester's Finale buffs, Finale's +100% stress and Inspiring Tune's −10% stress;
  - the Flagellant's Exhaustion and Suffer buffs.
- **Gap: move distances for three classes.** The wiki infoboxes for the Crusader, Vestal and Plague Doctor have no forward/back fields. Their move skills (1 back, 1 forward) come from the data only.

## Could not confirm

- The **default duration** of an effect with no `.duration` (see above). The 4-versus-3-round pattern is my reading of the wiki values.
- **Inspiring Tune's −10% stress** duration. Neither source gives one; the wiki's general 3-round rule would make it 3 rds.
- Whether the Jester's **Finale buffs stack** when the same skill is used twice in 8 rounds, and whether there is a cap. The wiki does not say.
- The **Flagellant's below-40% buff**: whether it lasts only while he stays below 40% HP. Also the exact numbers of his death reactions, which are wiki only.
- Bellow's "**+5% crits received while Marked**" is the wiki's wording. The underlying buff was not read, so the exact rule is unconfirmed.
- **Self-targeting** for Battle Heal, Inspiring Cry, Divine Grace, Battlefield Bandage, Battlefield Medicine, Emboldening Vapours and Inspiring Tune. These lack the data's explicit self-target ban, so they likely can target the user (inferred). The five skills listed under "Cannot target self" are certain (data).
- Whether **party-wide buffs** (Command, Bolster, Battle Ballad, Divine Comfort) include the user. The targeting reads as "all allies" (inferred).
- The **game version** of the [D-V] copies. It is not stated; it is only inferred to be current.

---

## Sources

### wiki.gg (raw wikitext of the hero templates)
- Crusader: https://darkestdungeon.wiki.gg/wiki/Crusader (earlier fetch reused)
- Grave Robber: https://darkestdungeon.wiki.gg/wiki/Grave_Robber_(Darkest_Dungeon)
- Arbalest: https://darkestdungeon.wiki.gg/wiki/Arbalest_(Darkest_Dungeon)
- Vestal: https://darkestdungeon.wiki.gg/wiki/Vestal_(Darkest_Dungeon)
- Man-at-Arms: https://darkestdungeon.wiki.gg/wiki/Man-at-Arms_(Darkest_Dungeon)
- Plague Doctor: https://darkestdungeon.wiki.gg/wiki/Plague_Doctor_(Darkest_Dungeon)
- Jester: https://darkestdungeon.wiki.gg/wiki/Jester_(Darkest_Dungeon)
- Flagellant: https://darkestdungeon.wiki.gg/wiki/Flagellant_(Darkest_Dungeon) (`/wiki/Flagellant` redirects here)
- Move (status chance minus resist; hero moves ignore Move resist): https://darkestdungeon.wiki.gg/wiki/Move_(Darkest_Dungeon) (earlier fetch reused)

### Game data [D-V] (current DD1 files, copied in a third-party mod repository)
- Repository: https://github.com/GD-JM/darkest-dungeon-rebalance
- Per-hero vanilla sheets, each ending with the full original `.info.darkest` and listing the effect lines its skills use: `heroes/<hero>/<hero>.vanilla.txt` for `crusader`, `grave_robber`, `arbalest`, `vestal`, `man_at_arms`, `plague_doctor`, `jester`, `flagellant`. The Flagellant's original is `dlc/580100_crimson_court/features/flagellant/heroes/flagellant/flagellant.info.darkest`.
- How the sheets are built (official file backup plus the game's effect files): `tools/make_vanilla_sheet.py`, `tools/effect_common.py`

### Game data [D-U] (2016 snapshot; comparison only)
- Hero info files: https://github.com/Reinisch/Darkest-Dungeon-Unity/tree/master/Assets/Resources/Data/Heroes/Info (`Crusader.bytes`, `GraveRobber.bytes`, `Arbalest.bytes`, `Vestal.bytes`, `ManAtArms.bytes`, `PlagueDoctor.bytes`, `Jester.bytes`; no Flagellant)
