# Darkest Dungeon II hero kits: Crusader, Grave Robber, Vestal, Man-at-Arms, Plague Doctor, Jester, Flagellant

Researched on 2026-10-28 for the Godot project `darko-dungo`.
This is a companion to `darkest-dungeon-combat.md`. That document defines the token, DoT, Death's Door and stress rules used below.
This file is the **raw DD2 data** for seven heroes: base stats, class mechanics, and all 11 combat skills per hero (Wanderer path, unmastered, plus a one-line mastered delta).

## How to read this document

| Tag | Meaning |
|---|---|
| **(data)** | Read from DD2's own data tables in a **vanilla 2025 snapshot** [D-WB25]. Primary source. See the version note below. |
| **(wiki)** | darkestdungeon.wiki.gg hero pages. |
| **(patch)** | Red Hook's patch notes (wiki mirror, the official site, or patched.gg). Authoritative for *changes*. |
| **(inferred)** | My reading of field names or structure where no source states the rule in words. |
| **(conflict)** | Sources disagree. Both values are given. |
| **(unknown)** | Could not be confirmed. |

> **Data source and version (important).**
> - **Do not use the `master` branch of the woodbrick repo [D-WB] for hero numbers.** It is a **balance mod**: its commit log has entries like "balance dmg", "update hero hp" and "skill balance", plus a `backup/` folder. Examples: Grave Robber 38 HP / 6 SPD on master vs **29 / 5** vanilla, Flagellant 59 HP vs **50**, Pick to the Face 6–9 dmg vs **4–7**.
> - I compared the core token definitions (Block, Dodge, Strength, Weak, Vulnerable, Blind, Crit, Stun, Daze, Taunt, Stealth, Guard, Riposte, Combo, Speed, Immobilize, Death's Door Armor). They are identical between master and the vanilla snapshot except for UI and tag fields. So the token rules cited from [D-WB] in `darkest-dungeon-combat.md` still hold. That doc's hero-specific numbers from [D-WB] may be modded, though (e.g. its "HWM/MAA riposte 3–6 dmg"; vanilla MAA riposte is 3–5).
> - All data in this file comes from the repo's **`excel-files` branch, commit `8a6cb977` ("Initial commit: Excel game data files", 2025-12-30)** [D-WB25]. Later commits on that branch are the author's own balance edits and were not used. The snapshot's values match the wiki for every base stat and for almost every skill number (exceptions are marked).
> - **Game version of the snapshot: after v2.02, before v2.04.** It includes the v2.02 changes from *Steadfast Stewards* (Jul 2025): Plague Doctor HP 28 → 30, `m_CritDotExtraDuration = 0` and Cause of Death 100% / 125%. It **lacks** the v2.04.80601 changes from *Steadfast Stewards Pt. 2*: More! MORE! still has cooldown 1 and Radiance is the old version. Pt. 2 shipped Oct 29 2025 on PC per patched.gg and Nov 18 2025 on consoles per the official notes [P-SS2].
> - **Current values = snapshot + the Pt. 2 lines.** Where Pt. 2 changed a number, the table shows the **current** value first and the data value second. I found no later balance changes to these seven heroes. The 2026 builds through 2.04.85095 (Apr 28 2026) contain only hotfixes, modding fixes, candle changes and Hellion changes; the one Man-at-Arms entry is an animation fix [P-2026].

### Table conventions

- **Start?** "Start" = one of the 5 skills every hero has from the beginning. "Shrine N" = unlocked at the hero's Shrine of Reflection, chapter N. The 5 starting skills are the ones without an unlock id in the data, which matches each wiki page's starting-skill list. The data's `m_ProfileUnlockId = herostory_XX_0N` gives the chapter **(inferred mapping)**: chapters 1–4 unlock one skill each and chapter 5 unlocks two. A hero equips 5 skills at a time (`m_EquippedCombatSkillLimit 5`), plus the always-equipped Swap skill.
- **Launch / Targets** are DD2 ranks 1–4, with 1 at the front. "e1–2 one" = one enemy in rank 1 or 2. "e2+3 all" = the skill hits every listed rank (`m_IsMultiHit`). "ally" = another hero only. "ally/self" = any hero including the user. "self" = user only. **All Launch and Targets values are data-only.** The wiki shows ranks as icons, which I could not read.
- **DMG** = `health_damage` to `health_damage + health_damage_range`. This matched the wiki's ranges in every case checked.
- **DoT/HoT.** All skill DoTs last 3 turns and tick at the start of the holder's turn. Sizes: small = 2, medium = 3, large = 4, very large = 5, massive = 6 per tick. "Regen N" = heal N per turn for 3 turns. "Blight 3" means 3 per tick for 3 turns.
- **(nr)** = cannot be resisted (`m_IgnoreResist`). Moves the user makes on itself (Forward/Back) always ignore Move RES. Knockback and Pull on enemies are resistable.
- **Combo.** "vs Combo" = the bonus applies if the target holds Combo. "Ends Combo" = removes the target's Combo (limit 1). Pierce bonuses are "+30% X RES piercing vs Combo". In the data they are a −30% RES buff on the target that lasts only while the skill is calculated.
- **Heals.** Every heal effect has 5% crit chance and +50% on crit (`m_CritChance 0.05`, `m_CritMultiplier 0.5`). The Flagellant's Pain heal is the exception: it cannot crit. "Heal 20%" = 20% of the target's max HP.
- **"One of A / B".** These come from the `*_apply_limit_effects` lists with limit 1. The game picks one entry at random among those that can apply **(inferred)**. The wiki confirms the 50/50 for Consecration of Fortitude and the 85/15 for Battle Ballad+.
- **Cooldown / Limit.** `m_Cooldown` = turns before reuse; cooldowns tick on the hero's own turns (see the combat doc). `m_Limit` = uses per battle.
- **Source column.** `data` = [D-WB25]. `wiki` = the hero's wiki page gives the same numbers. `SS2` = changed by [P-SS2]; the current value is shown. `conflict` = see the note under the table.

---

## TL;DR

| Hero | HP | SPD | Starting 5 skills | Class mechanic |
|---|---|---|---|---|
| **Crusader** (DLC) | 40 | 2 | Smite, Stunning Blow, Zealous Accusation, Inspiring Cry, Rallying Cry | No class token. Combo payoffs (Smite +50% DMG, Stunning Blow stuns only vs Combo), Burn, the only heal-reduction debuff (Reap), cleanses and stress heal. |
| **Grave Robber** | 29 | 5 | Pick to the Face, Thrown Dagger, Flashing Daggers, Poison Dart, Absinthe | No class token. Many "if she has Stealth" bonuses; +50% crit vs Combo, and Combo is kept if she holds a Crit token; Execution. |
| **Vestal** | 41 | 2 | Hand of Light, Illumination, Judgement, Divine Grace, Consecration of Fortitude | **Conviction**: +1 at the start of each of her turns, max 3. Skills scale at 2 and 3 Conviction and then spend all of it. **Consecrations**: rank tokens that buff whoever stands in that rank for 3 rounds. |
| **Man-at-Arms** | 42 | 2 | Crush, Rampart, Defender, Bolster, Hold the Line | No class token. Guard/Block/Taunt tank with his own Riposte attack (3–5 dmg); Courageous Abandon scales with his Block tokens. |
| **Plague Doctor** | 30 | 4 | Noxious Blast, Blinding Gas, Incision, Battlefield Medicine, Ounce of Prevention | No class token. Blight/Bleed with Combo pierce, Blind/Daze, DoT cleanse and heals. |
| **Jester** | 29 | 4 | Razor's Wit, Fade to Black, Slice Off, Battle Ballad, Inspiring Tune | No class token on Wanderer. Combo builder, Bleed, ally repositioning, stress heal; Encore gives an ally an extra action. |
| **Flagellant** | 50 | 3 | Punish, Fester, Deathless, Endure, Lash's Gift | **Toxic** replaces Meltdown/Resolute: HP set to 30%, cooldowns reset, a Toxic token that Blights attackers. **Pain** tokens heal him at turn end. No Weak on Death's Door. Many skills cost him %HP or stress. |

---

## Rules shared by all seven heroes (data)

- **Stats every hero has** (data [D-WB25]):
  - stress max 10;
  - `deaths_door_chance` 1, so every hero gets Death's Door;
  - one action per turn;
  - Deathblow RES floor 33% (`m_ResistMinOverrides death 0.33`);
  - −10% Deathblow RES for the rest of the combat each time he or she survives a deathblow;
  - after skipping a turn to Stun: +50% Stun RES until the next turn start;
  - 10% HP healed between nodes, which is out of combat.
- **Overstress.** Meltdown/Resolute for everyone except the Flagellant, who has **Toxic** (see his section).
- **AI target tags.** `hard_target`: Crusader, Vestal, Man-at-Arms, Flagellant. `soft_target`: Grave Robber, Plague Doctor, Jester. Enemy brains use them as targeting preferences **(inferred)**.
- **No levels.** DD2 heroes have no level 1. The stats below are the base values. The wiki's "Upgraded" column is base plus permanent profile unlocks: data `*_ut_*` buffs with `m_UnlockId <hero>_N`, typically +5% Deathblow RES ×3 and +10% to a couple of resistances. I list them per hero for completeness. They are not part of a fresh hero.
- **Path variants.** Path variants (`*_p1/_p2/_p3`) and Act-Out skills are excluded throughout. Act-Outs are relationship-driven.

---

## 1. Crusader

**Stats** (data [D-WB25], wiki agrees [W-CRU2]): HP **40** · SPD **2** · Stun 30% · Blight 10% · Bleed 30% · Burn 30% · Move 30% · Debuff 20% · Deathblow 60% · Disease 30% · Swap: 1 forward / 1 back.
Profile upgrades (not base): +5% Deathblow ×3, +10% Stun, +10% Bleed, +10% Burn (data).

**Mechanics**
- **No hero-specific token or rule.** No token is tagged for the Crusader in the data, and the wiki lists none. **(data + wiki)**
- **Combo payoffs.** Smite deals +50% DMG vs Combo. Stunning Blow stuns *only* vs Combo. Both end Combo. Zealous Accusation (25%/33%) and Holy Lance+ (100%) apply Combo. **(data)**
- **Reap** lowers the target's healing received, including Regen. The wiki calls him the only hero who modifies healing received. **(data + wiki)**
- **Availability.** *The Binding Blade* DLC hero. In Confessions he is unlocked by the quest "The Lost Crusade" (data `m_ExpeditionUnlockId crusader_quest`); in Kingdoms he is available from the start. **(wiki + data)** His data lives in `dlc_dul_cru/`.
- Path variants (not covered): Aggressor, Templar, Banneret. [P-2025-07, P-SS2]

| Skill | Start? | Launch | Targets | DMG | Crit | Effects | Cooldown / Limit | Mastered | Source |
|---|---|---|---|---|---|---|---|---|---|
| Smite | Start | 1, 2 | e1–2 one | 5–7 | 5% | +50% DMG vs Combo; ends Combo | – | 7–9, crit 10% | data, wiki |
| Stunning Blow | Start | 1, 2 | e1–2 one | 3–5 | 5% | Stun **only if target has Combo**; ends Combo | – | 4–6, crit 10%; also removes all target Strength and Crit tokens | data, wiki |
| Zealous Accusation | Start | 1, 2 | e1+2 all | 1–2 | 5% | Burn 2; Combo 25% | – | 2–3; Burn 3; Combo 33% | data, wiki |
| Inspiring Cry | Start | 1–4 | ally/self | – | – | **Req:** target Stress ≥ 5 (50%). Target −2 Stress | CD 1 | also −1 Stress to the Crusader | data, wiki |
| Rallying Cry | Start | 1–4 | ally/self | – | – | **Req:** target has Blind, Weak or Vulnerable. Removes all Blind, Weak and Vulnerable from the target | CD 1 | no cooldown; also cleanses the Crusader | data, wiki |
| Reap | Shrine 1 | 1, 2 | e1+2 all | 4–5 | 5% | −20% healing received (3 turns) | – | 5–7; −33%; ends Combo; Crusader heals 15% per Combo target hit | data, wiki |
| Battle Heal | Shrine 2 | 1, 2 | ally/self | – | – | **Req:** target HP < 50%. Heal 20% | CD 2, limit 3 | heal 25% + self heal 10%; CD 1 | data, wiki |
| Bulwark of Faith | Shrine 3 | 1, 2 | self | – | – | Block ×2, Taunt ×2 (nr), Regen 2 | CD 2 | Taunt ×3, Regen 4 | data, wiki |
| Holy Lance | Shrine 4 | 3, 4 | e2–4 one | 4–7 | 10% | Burn 2; self Forward 1 | – | 5–9, crit 15%; Burn 3; Combo | data, wiki |
| Radiance | Shrine 5 | 1–4 | self | – | – | **Current (SS2):** Regen 2; +20% Burn RES piercing for all skills (3 turns); +2 SPD (3 turns); +2 DMG vs targets with Burn (3 turns). **Data (pre-SS2):** Regen 2; +20% Burn RES piercing for *ranged* skills only (4 turns) | CD 4 | **Current:** CD 3; Regen 4 for 4 turns; +20% pierce (4 turns); +4 SPD (4 turns); +2 DMG vs Burn (4 turns). **Data:** Regen 3; ranged pierce (4 turns); +30% DMG vs Burn (4 turns) | data, SS2, wiki (= current) |
| Tenacity | Shrine 5 | 1–4 | ally/self | – | – | Target Block ×2 | CD 2 | target also gets +10% Debuff RES (3 turns); Crusader gains Block and +10% Debuff RES | data, wiki |

Notes:
- **Inspiring Cry.** The data's condition id is `target_stress_over_40pct`, but its value is `stress_percent ≥ 0.5`, i.e. Stress 5+. The wiki also says 5+. **(data + wiki)**
- **Radiance** needs a timed flat-SPD buff and a "+2 DMG vs Burn" damage buff. The old version needed a skill-tag condition (`skill_is_ranged`).

**Engine dependencies:** heal-received modifier (Reap); timed SPD buff and flat damage buff (Radiance, current); resist-piercing buff; stress (Inspiring Cry); DLC hero.

---

## 2. Grave Robber

**Stats** (data [D-WB25], wiki agrees [W-GR2]): HP **29** · SPD **5** · Stun 20% · Blight 30% · Bleed 30% · Burn 30% · Move 20% · Debuff 30% · Deathblow 60% · Disease 30% · Swap: 2 forward / 2 back.
Profile upgrades (not base): +5% Deathblow ×3, +10% Blight, +1 SPD ×2 (data). The wiki's "Upgraded" column shows SPD 7 and Deathblow 75%.

**Mechanics**
- **No hero-specific token.** Her kit is built on generic tokens. **(data)**
- **Stealth synergy.** Stealth has limit 2 and one stack is removed at the end of her turn (combat doc). Many skills change when the Grave Robber holds Stealth: they ignore Dodge, Pirouette's self-debuff becomes a target debuff, Glint gains Execution 3, and Repartee+ gains a buff. Repartee and Glint remove Stealth. **(data)**
- **Combo crit.** Pick to the Face, Thrown Dagger and Poison Dart get +50% crit chance vs Combo. They then remove all Combo from the target **unless the Grave Robber holds a Crit token** (data `end_combo_if_performer_no_crit`; added in v2.02 [P-2025-07]).
- **Ignored tokens are still consumed.** When a skill ignores Block, Dodge or Guard, the data also removes one of that token from the target (`ignored_token_remove_1_*`). **(data)**
- **Execution N.** Execution N kills through Death's Door Armor when the enemy has ≤ N DA (combat doc A8). Used by Glint in the Dark.
- Path variants (not covered): Deadeye, Venomdrop, Nightsworn.

| Skill | Start? | Launch | Targets | DMG | Crit | Effects | Cooldown / Limit | Mastered | Source |
|---|---|---|---|---|---|---|---|---|---|
| Pick to the Face | Start | 1–3 | e1–2 one | 4–7 | 15% | Ignores Block and Block+; +50% crit vs Combo; Combo rule above | – | 5–9, crit 20%; on crit removes all target Block/Block+ | data, wiki |
| Thrown Dagger | Start | 2–4 | e2–4 one | 3–6 | 15% | Ignores Guard; ignores Dodge/Dodge+ if she has Stealth; +50% crit vs Combo; Combo rule | – | 4–8, crit 30% | data, wiki |
| Flashing Daggers | Start | 2–4 | e2+3 all | 3–5 | 15% | none | – | 4–6, crit 20%; ignores Dodge if she has Stealth | data, wiki |
| Poison Dart | Start | 2–4 | e1–4 one | 2–4 | 5% | Blight 2; **on crit the Blight lasts 5 turns (SS2)**; +50% crit vs Combo; Combo rule | – | 2–5, crit 10%; Blight 4 (5 turns on crit, SS2) | data, SS2, wiki |
| Absinthe (data `gr_artemisia`) | Start | 1–4 | self | – | – | Heal 33% **only if her HP < 33%**; Dodge ×3; Speed | limit 3 | Dodge+ ×3 instead of Dodge | data, wiki |
| Dead of Night | Shrine 1 | 1–4 | enemy corpse, one | – | – | **Req:** target is a corpse. Clears it, even on a miss. On hit: self heal 33% and Stealth ×1 | limit 3 | heal 50%, −1 Stress, Stealth ×2 | data, wiki |
| Repartee | Shrine 2 | 1–4 | self | – | – | Dodge ×3, Taunt ×2 (nr), then removes her own Stealth | CD 2 | Dodge+ ×3. If she had Stealth: buff (3 turns) giving 50% to gain Dodge each time an attack misses her | data; conflict (wiki) |
| Lunge | Shrine 3 | 3, 4 | e1–3 one | 5–8 | 20% | Self Forward 2; on crit Knockback 2; ignores Dodge if she has Stealth | – | 7–11, crit 30%; on crit Knockback 3; with Stealth ignores Dodge, Dodge+, Block and Block+ | data, wiki |
| Shadow Fade | Shrine 4 | 1, 2 | self | – | – | Stealth ×2; self Back 2 | CD 2 | + Strength | data, wiki |
| Pirouette | Shrine 5 | 1, 2 | e1+2 all | 4–7 | 10% | Self Back 3. **If she has no Stealth:** self Daze + Weak (nr) | CD 1 | 6–9, crit 15%. With Stealth the Daze + Weak go on the targets instead (resistable) | data, wiki |
| Glint in the Dark | Shrine 5 | 1–3 | e1–3 one | 4–7 | 5% | Ignores Stealth; Execution 1; removes the target's Stealth | – | 6–9, crit 10%; Execution 3 if she has Stealth | data, wiki |

Notes:
- **Repartee (conflict).** In the data the "+Dodge when missed" buff exists only on Repartee+ (`gr_repartee_dodge_manager_e`, condition: she has Stealth). The scraped wiki shows it on the base skill. Its upgraded row looks shuffled, so I trust the data.
- **Poison Dart.** The v2.02 change removed the generic "+2 DoT turns on crit" (data `m_CritDotExtraDuration 0`). SS2 then gave this one skill a crit duration of 5 turns. The snapshot predates SS2 and shows no crit duration. **(patch)**

**Engine dependencies:** corpses (Dead of Night); Death's Door Armor and Execution (Glint); Stealth targeting; "on missed as target" trigger (Repartee+); knockback on crit; a Combo-consumption check that depends on whether she holds a Crit token.

---

## 3. Vestal

**Stats** (data [D-WB25], wiki agrees [W-VES2]): HP **41** · SPD **2** · Stun 20% · Blight 20% · Bleed 20% · Burn 30% · Move 20% · Debuff 20% · Deathblow 60% · Disease 20% · Swap: 1 forward / 1 back.
Profile upgrades (not base): +5% Deathblow ×3, +10% Stun, +10% Move, +10% Debuff (data).

**Mechanics**
- **Conviction** (token `conviction`):
  - Limit **3**. It has no duration field, so it lasts until combat end (wiki: "until end of combat"). It is only consumed by skills. **(data + wiki)**
  - **Gain (Wanderer): +1 at the start of each of her turns.** This comes from buff `ves_conviction_generation` (`turn_start_effects add_1_conviction`), which is **attached to the path `ves_wanderer`**, not to the class. An engine without paths must hard-wire it to the Vestal. **(data)** The other paths gain it differently (wiki). The Reserve path also gains +1 per turn start (data).
  - **Tiers.** Mace Bash, Judgement, Divine Grace and Mantra check "≤ 1 / 2 / 3" Conviction.
  - **Spending.** After any of those skills, if she had **≥ 2**, **all** her Conviction is removed (`ves_pay_conviction_cost`: remove all tokens tagged conviction, condition ≥ 2). With 0–1 nothing is spent. **(data)**
- **Consecrations.** The data ids are `blessing_of_fortitude(_u)` and `blessing_of_light(_u)`, tag `vestal_blessing`; the wiki calls them Consecrations.
  - They are **rank tokens** (`m_IsRankToken`, `m_IsLockedTeamPosition`). The skill targets an ally (or herself); the token sits on that **rank** and buffs whichever hero stands there. **(data + wiki)**
  - They last **3 rounds** (`round_end`, 3), with limit 1 per rank. A new Consecration **replaces** the other kind: the `replace` lines replace Light with Fortitude and vice versa. **(data + wiki)**
  - **Fortitude:** at the start of the occupant's turn, gain one of Block / Dodge (50/50). **Fortitude+:** one of Block+ / Dodge+.
  - **Light:** at turn start gain Strength. **Light+:** one of Strength (75%) / Crit (25%). **(data + wiki)**
- Path variants (not covered): Confessor, Chaplain, Seraph.

| Skill | Start? | Launch | Targets | DMG | Crit | Effects | Cooldown / Limit | Mastered | Source |
|---|---|---|---|---|---|---|---|---|---|
| Hand of Light | Start | 1–3 | e1–3 one | 2–3 | 5% | Self Strength + Block | – | 3–4; also a random adjacent ally gains Strength | data, wiki |
| Illumination | Start | 1–4 | e1–4 one | none | 5% | Ignores Dodge, Dodge+ and Stealth; Daze; removes all Dodge, Dodge+ and Stealth from the target | – | + target cannot gain Dodge for 2 rounds (nr; anti-dodge skill block) | data, wiki |
| Judgement | Start | 3, 4 | e1–4 one | 3–5 | 5% | Conviction ≥ 2: +100% DMG. Conviction 3: Burn 3. Spends Conviction if ≥ 2 | – | 4–7; Burn 4 at 3 Conviction | data, wiki |
| Divine Grace | Start | 3, 4 | ally/self | – | – | **Req:** target HP < 33%. Heal 20% (Conviction ≤ 1) / 30% (2) / 40% (3). Spends Conviction if ≥ 2 | CD 2 | 30 / 40 / 50%; the 3-Conviction heal has 15% crit | data, wiki |
| Consecration of Fortitude (data `ves_blessing_of_fortitude`) | Start | 1–4 | ally/self (their rank) | – | – | Places Consecration of Fortitude on the target's rank (3 rounds) | CD 3 | Consecration of Fortitude+ | data, wiki |
| Ministrations | Shrine 1 | 3, 4 | ally/self | – | – | **Req:** target has Bleed, Blight or Burn, or is Stunned or Dazed. Removes all Bleed, Blight, Burn, Stun and Daze | CD 1 | + 30% RES (3 turns) for each type removed (Bleed / Blight / Burn / Stun) | data, wiki |
| Mace Bash | Shrine 2 | 1, 2 | e1–2 one | 4–6 | 5% | Conviction ≥ 2: ignores Block, Block+, Dodge, Dodge+ and Guard. Conviction 3: +100% DMG. Spends Conviction if ≥ 2 | – | 6–8, crit 10% | data, wiki |
| Sanctuary | Shrine 3 | 1–4 | ally (not self) | – | – | Target gets Guarded ×2 (she guards them); Vestal Block ×2 | CD 1 | + target −2 Stress if Stress ≥ 5 | data, wiki |
| Consecration of Light (data `ves_blessing_of_light`) | Shrine 4 | 1–4 | ally/self (their rank) | – | – | Places Consecration of Light (3 rounds) | CD 3 | Consecration of Light+ | data, wiki |
| Divine Comfort | Shrine 5 | 2–4 | all allies | – | – | Regen 2 on each | CD 4 | Regen 3 | data, wiki |
| Mantra | Shrine 5 | 1–4 | every ally standing on a Consecration | – | – | **Req:** target's rank has a Consecration. Heal 10% / 20% / 30% by Conviction (≤ 1 / 2 / 3). Spends Conviction if ≥ 2 | none | heal 10% (≤ 1) or 30% (≥ 2). At 3 Conviction each target also gets one token by its Consecration: Fortitude → Block or Dodge; Fortitude+ → Block+ or Dodge+; Light → Strength; Light+ → Strength 75% / Crit 25% | data only |

Notes:
- **Mantra.** The wiki lists only the path versions: Confessor, Chaplain, and Seraph ("requires Consecration, heal 30%/50%, removes Consecration"). The data has a separate base `ves_mantra`, which paths replace with `_p1/_p2/_p3` via `actor_paths`. So the row above is the Wanderer version, from data only. **(data; wiki n/a)**

**Engine dependencies:** Conviction gain lives on the path (`ves_wanderer`); **rank-bound tokens** (Consecrations); anti-dodge skill block (Illumination+); "random adjacent ally" targeting (Hand of Light+); Guard; stress (Sanctuary+).

---

## 4. Man-at-Arms

**Stats** (data [D-WB25], wiki agrees [W-MAA2]): HP **42** · SPD **2** · Stun 30% · Blight 30% · Bleed 30% · Burn 30% · Move 30% · Debuff 20% · Deathblow 60% · Disease 30% · Swap: 2 forward / 2 back.
Profile upgrades (not base): +5% Deathblow ×3, +10% Stun ×2, +4 max HP (data). The wiki's "Upgraded" column shows 46 HP.

**Mechanics**
- **No hero-specific token.** **(data + wiki)**
- **Riposte attack** (`maa_riposte`):
  - Fires when he holds a Riposte token and is hit by a damaging attack that can be riposted (combat doc A7).
  - Melee, any rank, **3–5 dmg, 5% crit**. It ignores Riposte, Guard and Taunt on its target (`til_standard_riposte`).
  - The Bulwark and Vanguard path extras on it are not covered.
  - **(data + wiki)**
- **Block-count payoffs.** Courageous Abandon checks his Block-tagged tokens (Block and Block+ both count). **(data)**
- Path variants (not covered): Bulwark, Sergeant, Vanguard.

| Skill | Start? | Launch | Targets | DMG | Crit | Effects | Cooldown / Limit | Mastered | Source |
|---|---|---|---|---|---|---|---|---|---|
| Crush | Start | 1, 2 | e1–3 one | 4–6 | 5% | Ends Combo; he heals 10% if the target had Combo | – | 5–7; heal 20% | data, wiki |
| Rampart | Start | 1–3 | e1–2 one | 3–5 | 5% | Knockback 1; Daze; self Forward 1 | – | 4–6; + Stun if target has Combo (ends Combo) | data, wiki |
| Defender | Start | 1–4 | ally (not self) | – | – | Target Guarded ×2 (he guards them); he gains Block ×2 | CD 1 | Guarded ×3; Block+ ×2 | data, wiki |
| Bolster | Start | 1–4 | ally (not self) | – | – | Target −1 Stress if Stress ≥ 5. He gains Block and −1 Stress if his Stress ≥ 5 | CD 1 | −2 / −2; Block+ | data, wiki |
| Hold the Line | Start | 2–4 | e1–2 one | 3–6 | 10% | Self Block, self Forward 3, then self Immobilize ×1 (nr) | – | 4–7; Block ×2, Immobilize ×2; Stun if target has Combo (ends Combo) | data, wiki |
| Bellow | Shrine 1 | 1–4 | e1–4 all | none | 5% | Removes all Riposte; −2 SPD (3 turns) | CD 1 | also removes all Crit; −3 SPD | data, wiki |
| Stand Fast | Shrine 2 | 1, 2 | self | – | – | Block ×2, Taunt ×2 (nr); buff (3 turns): +1 Block at each of his turn starts | CD 3 | Block+ ×2; the buff gives Block+ | data, wiki |
| Retribution | Shrine 3 | 1–4 | self | – | – | Riposte ×2, Taunt ×2 (nr) | CD 2 | CD 1 | data, wiki |
| Courageous Abandon | Shrine 4 | **1 only** | e1–2 one | 6–8 | 10% | **Req:** he holds ≥ 1 Block or Block+. Ignores Block and Block+. +100% DMG if he holds ≥ 2 Block-type tokens. Afterwards he loses all Block/Block+, **cannot gain Block for 2 turns**, and gets Vulnerable (nr) | – | 8–10, crit 20%; **Execution 2 if he holds ≥ 3** Block-type tokens | data; conflict (wiki) |
| Command | Shrine 5 | 1–4 | ally (not self) | – | – | Strength; removes all Blind | CD 1 | Strength ×2 | data, wiki |
| Strategic Withdrawal | Shrine 5 | 1, 2 | e1–2 one | 3–6 | 5% | Combo on target; self Back 1 | CD 1 | 4–7, crit 10%; + Speed; if he is on Death's Door: heal 33% and Block+ | data, wiki |

Notes:
- **Courageous Abandon (conflict).** The scraped wiki also shows "with Block x3, Execution 2" on the base skill. In the data only the mastered version has it (`til_maa_courageous_u_execution`). The wiki's "Removes Block and Vulnerable" means he removes his Block and *gains* Vulnerable (data `add_1_vulnerable_nr`).
- **SS2 fix.** Since SS2, gaining Block while under the anti-block debuff no longer strips his Vulnerable [P-SS2].

**Engine dependencies:** a Riposte skill per class; Guard; anti-block skill block; Death's Door status as a condition (Strategic Withdrawal+); Execution (Courageous Abandon+); timed SPD debuff (Bellow); stress thresholds (Bolster).

---

## 5. Plague Doctor

**Stats** (data [D-WB25], wiki agrees [W-PD2]): HP **30** · SPD **4** · Stun 10% · Blight 40% · Bleed 30% · Burn 30% · Move 20% · Debuff 20% · Deathblow 60% · Disease 40% · Swap: 1 forward / 1 back.
HP was raised from 28 to 30 in v2.02 [P-2025-07]. Profile upgrades (not base): +5% Deathblow ×3, +10% Blight, +10% Burn, +10% Disease (data).

**Mechanics**
- **No hero-specific token.** **(data + wiki)**
- **Combo payoffs.** Noxious Blast and Incision get +30% Blight/Bleed RES piercing vs Combo; their mastered versions add +1 DoT duration vs Combo. Blinding Gas applies Combo. Disorienting Blast+ stuns vs Combo. **(data)**
- Path variants (not covered): Surgeon, Alchemist, Physician.

| Skill | Start? | Launch | Targets | DMG | Crit | Effects | Cooldown / Limit | Mastered | Source |
|---|---|---|---|---|---|---|---|---|---|
| Noxious Blast | Start | 2–4 | e1–2 one | 2–3 | 5% | Blight 4; +30% Blight RES piercing vs Combo; ends Combo | – | 3–4, crit 10%; Blight 5; +1 Blight duration vs Combo | data, wiki |
| Blinding Gas | Start | 3, 4 | e3+4 all | none | 5% | Blind; Combo 25% per target; on crit Combo 100% | CD 1 | crit 15%; + Daze; Combo 33% | data, wiki |
| Incision | Start | 1–3 | e1–2 one | 3–6 | 10% | Bleed 3; +30% Bleed RES piercing vs Combo; ends Combo | – | 4–7, crit 15%; Bleed 4; +1 Bleed duration vs Combo | data, wiki |
| Battlefield Medicine | Start | 3, 4 | ally/self | – | – | **Req:** target HP < 50% or has Bleed/Blight/Burn. Heal 20% if HP < 50%. Removes all Bleed, Blight and Burn | limit 3 | heal 25%; also removes her own DoTs | data, wiki |
| Ounce of Prevention | Start | 2–4 | all allies | – | – | +20% Bleed/Blight/Burn RES and +15% Disease RES (3 turns) | CD 3 | CD 2; +30% / +30%; + 10% Debuff RES | data, wiki |
| Emboldening Vapours | Shrine 1 | 1–4 | ally/self | – | – | Removes Daze; Strength ×2 | CD 1 | removes Stun and Daze; Strength ×2 + Speed | data, wiki |
| Plague Grenade | Shrine 2 | 3, 4 | e3+4 all | 1–2 | 5% | Blight 3 | CD 1 | 2–3, crit 10%; Blight 4 | data, wiki |
| Indiscriminate Science | Shrine 3 | 2–4 | ally/self | – | – | **Req:** target HP < 50%. Heal 10%, plus 10% per positive token on the target (data: +100% healing received per token). Then removes all its positive tokens | CD 2 | + 5% per negative token (+50% each); also removes all negative tokens | data, wiki |
| Cause of Death | Shrine 4 | 1–3 | e1–3 one | special | – | **Req:** target has Bleed, Blight or Burn. DMG = 100% of the target's total remaining DoT damage. Ignores all damage multipliers and Strength, Weak, Vulnerable, Block and Crit tokens. Removes those DoTs | CD 2 | 125%; Execution 1 | data, wiki |
| Disorienting Blast | Shrine 5 | 2–4 | e2–4 one | none | 5% | Ignores Guard; Shuffle; Daze; removes all Guard | – | crit 15%; + Weak; Stun if target has Combo (ends Combo) | data, wiki |
| Magnesium Rain | Shrine 5 | 2–4 | e1–4 all | none | 5% | Burn 3; clears **every corpse on the enemy side**, even on a miss | CD 2 | crit 10%; if it hits a corpse, all her skill cooldowns are reset | data, wiki |

Notes:
- **Battlefield Medicine.** The wiki says "Remove DoT". The data effect `remove_all_dots` removes all three types: Bleed, Blight and Burn.
- **Cause of Death.** The data field is `m_AdditionalDamageValueType DOT_TAG_TOTAL_HEALTH_DAMAGE_OVER_TIME` with multiplier 1 (1.25 mastered) and `m_IgnoreDamageMultipliers`. The wiki gives the same rule: "deals 100% of the target's remaining DoT".

**Engine dependencies:** Shuffle move; corpses and a whole-team corpse clear (Magnesium Rain); cooldown reset; damage computed from remaining DoT (Cause of Death); heal scaling by token count (Indiscriminate Science); Disease RES only matters outside combat.

---

## 6. Jester

**Stats** (data [D-WB25], wiki agrees [W-JES2]): HP **29** · SPD **4** · Stun 20% · Blight 20% · Bleed 20% · Burn 20% · Move 20% · Debuff 20% · Deathblow 60% · Disease 30% · Swap: 3 forward / 3 back.
Profile upgrades (not base): +5% Deathblow ×3, +10% Debuff, +10% Burn, +1 SPD (data).

**Mechanics**
- **No hero-specific token on the Wanderer path.** The data has a `jes_buff_clear_manager` that removes `finale_buff` and `last_finale` buffs at combat end. Those buffs belong to the Soloist and Virtuoso paths (wiki: Finale and Encore buff stacks). **(data + wiki)**
- **Encore** (data `jes_the_last_laugh`) grants an ally an **extra action** (`m_AddTurn 1`, also valid during an extra turn). Per the combat doc, extra actions do not tick start-of-turn or end-of-turn effects.
- He builds Combo (Razor's Wit, Solo, Harvest, Fade to Black+). Finale cashes it in. **(data)**
- Path variants (not covered): Virtuoso, Soloist, Intermezzo.

| Skill | Start? | Launch | Targets | DMG | Crit | Effects | Cooldown / Limit | Mastered | Source |
|---|---|---|---|---|---|---|---|---|---|
| Razor's Wit | Start | 2–4 | e1–3 one | 3–6 | 10% | Combo; self Forward 1 | – | 4–7, crit 15%; + self Dodge | data, wiki |
| Fade to Black | Start | 1–3 | e1–3 one | 3–6 | 10% | Blind; self Back 1 | – | 4–7, crit 15%; + Combo | data, wiki |
| Slice Off | Start | 2, 3 | e2–3 one | 3–6 | 5% | Bleed 3 | – | 4–7, crit 10%; + Vulnerable | data, wiki |
| Battle Ballad | Start | 2–4 | ally/self | – | – | Target Forward 1; Strength | CD 1 | Forward 2; Strength, plus one of Strength (85%) / Crit (15%) | data, wiki |
| Inspiring Tune | Start | 3, 4 | ally/self | – | – | **Req:** target Stress ≥ 5. −2 Stress | CD 1 | −3 Stress; removes Horror | data, wiki |
| Play Out (data `jes_play_me_out`) | Shrine 1 | 2–4 | ally/self | – | – | Target Back 1; Block | – | Back 2; Block+; removes the target's Combo | data, wiki |
| Harvest | Shrine 2 | 2, 3 | e2+3 all | 2–4 | 5% | Bleed 2; Combo 25% | – | 3–4, crit 10%; Bleed 3; Combo 33% | data, wiki |
| Echoing March | Shrine 3 | 3, 4 | e2–4 one | none | 5% | Pull 1; debuff (3 turns): the target is pulled 1 at each of its turn starts | CD 1 | crit 10%; Pull 2 and the debuff pulls 2 | data, wiki |
| Finale | Shrine 4 | 1, 2 | e1–4 one | 6–12 | 10% | +50% DMG vs Combo; ends Combo; self Vulnerable + Daze (nr); self Back 3; on kill −1 Stress (corpse kills count since v2.02) | CD 3 | 10–13, crit 20%; Execution 1; on kill −2 Stress | data, wiki |
| Solo | Shrine 5 | 3, 4 | e1–4 one | none | 0% (data) / 5% (wiki) | Combo on target; self Dodge ×2, Speed, Forward 3. Does not consume his Crit token | CD 1 | Dodge+ ×2 | data; conflict (crit) |
| Encore (data `jes_the_last_laugh`) | Shrine 5 | 3, 4 | ally (not self) | – | – | Target gets an **extra action** and Bleed 2. Jester gets Daze + Weak (nr) | CD 3 | CD 2; Jester no longer gets Weak | data, wiki |

Notes:
- **Solo (conflict).** The data's `jes_solo` stats block is empty, so its crit chance is 0. The scraped wiki shows 5% (10% mastered).
- **Encore.** The Bleed 2 goes on the **ally**, not on an enemy (data `target_effects extra_action, skill_dot_small_bleed`). The wiki row agrees.

**Engine dependencies:** extra action (Encore); repeating forced move as a debuff (Echoing March); Horror (a stress DoT type) for Inspiring Tune+; on-kill trigger (Finale); Execution.

---

## 7. Flagellant

**Stats** (data [D-WB25], wiki agrees [W-FLG2]): HP **50** · SPD **3** · Stun 30% · Blight 50% · Bleed 20% · Burn 10% · Move 30% · Debuff 20% · **Deathblow 75%** · Disease 75% · Swap: **2 forward / 1 back**.
Profile upgrades (not base): +3% Deathblow ×6 (data). That sums to 93%; the wiki shows 90%, which matches the 90% Deathblow cap in the combat doc.

**Mechanics**
- **Toxic overstress** (replaces Meltdown/Resolute; data `overstresses toxic`, chance 1). At Stress 10:
  - Stress is set to 1 (`StressHealDownFromMax 9`).
  - **HP is set to 30%**, by healing up or damaging down as needed (the Scourge path uses 45%).
  - **All his skill cooldowns are cleared.**
  - He gains **+1 Toxic token**.
  - He gets −10% Deathblow RES until the next Inn.
  - Affinity −2 with the party (`m_LeaningChange -2`).
  - **(data + wiki)**
- **Toxic token** (data id `virulent_blight`): limit **3**, lasts until combat end. While he holds 1 / 2 / 3, every attacker that hits him gets **Blight 2 / 4 / 6** (3 turns). This is one DoT sized by the count (`flg_toxic_blight_armor_level_1..3`, `on_hit_as_target_to_performer`). The wiki words it as "Blight 2 per token". **(data + wiki)**
- **Pain tokens.** The user's "Pain tokens" are data `flagellant_pain_heal` (Pain) and `flagellant_pain_heal_u` (Pain+).
  - Limit **3**.
  - Only **More! MORE!** creates them. While its buff lasts (until the end of his next turn), he gains 1 Pain **each time he takes damage**, including his own self-damage (wiki).
  - **At the end of his turn** he heals **10% max HP per Pain (15% per Pain+)**. This heal cannot crit. Then all Pain is removed. **(data + wiki)**
  - **(inferred)** The "per token" multiplication follows the wiki. The data attaches the heal as an external buff of the token type, so the stacking mechanism is not visible.
- **No Weak on Death's Door.** Data class tag `no_dd_weak`; the wiki says he is the only hero without it. **(data + wiki)**
- **Self-costs.** Several skills deal **%max-HP self-damage** that cannot be resisted (`m_HealthDamagePercent`, `m_IgnoreResist`): Punish, Acid Rain and Undying 10%; Deathless 20%. Endure gives him **+2 Stress**. Lash's Gift and Sepsis require his HP < 50%. **(data)**
- Path variants (not covered): Maniac, Exanimate, Scourge.

| Skill | Start? | Launch | Targets | DMG | Crit | Effects | Cooldown / Limit | Mastered | Source |
|---|---|---|---|---|---|---|---|---|---|
| Punish | Start | 1–3 | e1–2 one | 3–6 | 5% | Blight 3; +30% Blight RES piercing vs Combo; ends Combo; **self −10% max HP** (nr) | – | 4–8, crit 10%; Blight 4; +1 Blight duration vs Combo | data, wiki |
| Fester | Start | 1–4 | enemy corpse, one | none | – | **Req:** target is a corpse. Clears it, even on a miss. The unit directly in front of and the unit directly behind the corpse each get Blight 3 | – | neighbours get Blight 5 | data, wiki |
| Deathless (data `flg_redeem`) | Start | 1–4 | ally (not self), HP < 100% | – | – | Heal 25%; **self −20% max HP** (nr) | CD 1 | heal 35% | data, wiki |
| Endure | Start | 1–4 | ally (not self), Stress ≥ 1 | – | – | Target −2 Stress; **Flagellant +2 Stress** | – | target −3 Stress | data, wiki |
| Lash's Gift | Start | 2–4 | ally (not self) | – | – | **Req:** Flagellant HP < 50%. Target gets Strength, Block and **+1 Stress**; Flagellant heals 25% | CD 2 | Block+ instead of Block; also removes Stun/Daze from the target; heal 35% | data; wiki ambiguous |
| Acid Rain (data `flg_rain_of_sorrows`) | Shrine 1 | 1, 2 | e3+4 all | 2–3 | 5% | Blight 2; +30% Blight RES piercing vs Combo; ends Combo; **self −10%** (nr) | – | 3–4, crit 10%; Blight 3; +1 Blight dealt vs Combo | data, wiki |
| More! MORE! | Shrine 2 | 1, 2 | self | – | – | Taunt ×2 (nr); buff until the end of his next turn: +1 Pain each time he takes damage | **CD 2 (SS2)**; data CD 1 | Pain+ instead of Pain; **Taunt ×3 (SS2)**; data Taunt ×2 | data, SS2, wiki |
| Suffer | Shrine 3 | 1–4 | ally (not self) with Bleed, Blight or Burn | – | – | Moves all of the target's Bleed, Blight and Burn onto himself; self +10% Deathblow RES (3 turns) | CD 1 | also removes all his Bleed, Blight and Burn at the end of his *next* turn | data, wiki |
| Sepsis (data `flg_exsanguinate`) | Shrine 4 | 1, 2 | e1–2 one | 4–8 | 5% | **Req:** Flagellant HP < 50%. Blight 4; +30% Blight RES piercing vs Combo; ends Combo; self heal 35% | CD 2, limit 3 | 6–10; Blight 6; heal 50% | data, wiki |
| Undying (data `flg_reclaim`) | Shrine 5 | 1–4 | ally (not self) | – | – | Regen 3; **self −10%** (nr) | CD 1 | Regen 5 | data, wiki |
| Necrosis | Shrine 5 | 2, 3 | e1–4 all, but only enemies that have Blight | 3–6 | 5% | **Req:** target has Blight. Self heal 5% per target hit | CD 1 | 4–8 | data, wiki |

Notes:
- **Lash's Gift.** In the data the `+1 Stress` sits in `target_effects`, so the ally gets it, and the heal sits in `performer_effects`. The scraped wiki row reads "self +1 Stress", which may be a scrape artefact. I trust the data.
- **Fester.** The neighbour Blight comes from `actor_effect_triggers flg_fester_neighbor_blight`: one unit in front and one behind, up to 2 units, not the corpse itself. Whether it fires on a miss is **(unknown)**. The data only says the corpse is cleared on a miss.
- **Necrosis targeting.** A multi-hit skill whose condition is "target has Blight" hits every enemy in ranks 1–4 that has Blight **(inferred)**. The wiki says "requires Blight; heal 5% per target".
- **Suffer+ timing.** At the end of his next turn, a hidden counter token (`count`) runs out and the buff removes his DoTs. This matches the wiki's "removes DoT at end of next turn". **(data + wiki)**

**Engine dependencies:** the Toxic overstress (stress system, cooldown reset, HP set-to-%), with Affinity and the until-Inn Deathblow penalty as meta systems; an "on hit as target, hurt the attacker" trigger (Toxic token); an "on damage taken" trigger (Pain); %max-HP self-damage; DoT stealing (Suffer); neighbour-of-target triggers (Fester); corpses; stress damage to self (Endure); exemption from Death's Door Weak.

---

## Systems these kits need beyond a plain token/DoT combat engine

| System | Used by | Suggestion |
|---|---|---|
| **Paths** | Vestal's Conviction gain is a buff on the path `ves_wanderer` (data). All `_p1/_p2/_p3` skill variants. | Hard-wire Conviction +1 per Vestal turn. Ignore path variants. |
| **Rank-bound tokens** | Vestal Consecrations of Fortitude and Light (and Mantra reads them) | Needs a per-rank token slot, or attach the token to the unit standing in that rank at cast time (simplification). |
| **Corpses** | Grave Robber Dead of Night, Flagellant Fester, Plague Doctor Magnesium Rain (clear and cooldown reset) | Our engine already has corpses per the combat doc; these need "target must be a corpse" and "clear corpse". |
| **Death's Door Armor / Execution** | Grave Robber Glint, Plague Doctor Cause of Death+, Jester Finale+, Man-at-Arms Courageous Abandon+ | Drop Execution if enemies have no Death Armor. |
| **Stress** | Inspiring Cry, Inspiring Tune, Bolster, Sanctuary+, Endure, Dead of Night+, Finale on-kill, Lash's Gift, Toxic | Core DD2 system. Horror (Inspiring Tune+) is a stress DoT type. |
| **Overstress variant** | Flagellant Toxic and the Toxic token | Needs a per-class overstress hook. |
| **Extra action** | Jester Encore | Needs an "insert an extra turn for the target" mechanism. |
| **Triggers** | on hit as target (Toxic token); on damage taken (More! MORE!); on missed (Repartee+); on kill (Finale); on crit (Lunge, Pick+, Blinding Gas, Poison Dart current); neighbour trigger (Fester); per target hit (Crush, Reap+, Necrosis) | Most are one-line hooks. |
| **Stat buffs with duration** | Bellow −SPD, Radiance +SPD/+DMG (current), resist buffs (Ounce, Ministrations+, Tenacity+, Suffer), heal-received debuff (Reap), resist piercing (Radiance), anti-block/anti-dodge skill blocks | A generic `Buff {stat, value, turns, condition}` covers them. |
| **Special damage** | Cause of Death (damage = remaining DoT); Indiscriminate Science (heal × token count) | Small special cases. |
| **Movement extras** | Shuffle (Disorienting Blast); repeating Pull (Echoing March); random adjacent ally (Hand of Light+) | |
| **Relationships** | Act-Out skills (excluded). Mastered skills carry `m_SkillModifierChanceModifiers curse 3`, which ties into the relationship skill blessings and curses in `skill_modifier_data_export`. Toxic's Affinity −2. | Drop. |
| **Flame/torch, combat items** | **None** of these 77 skills touch torch or items. I checked all seven hero files; the torch-loss hook is a battle-stall rule, not a hero rule. | Nothing to drop. |
| **Profile/meta** | Shrine unlocks, profile `*_ut_*` stat upgrades, signature Inn items, the Toxic until-Inn Deathblow penalty, Disease RES | Drop or treat as campaign-layer. |

---

## Unconfirmed points and conflicts (summary)

1. **Snapshot version.** The snapshot is after v2.02 and before v2.04. The three SS2 changes to these heroes (Radiance, Poison Dart crit duration, More! MORE!) come from patch notes and are not visible in the data. **(patch)**
2. **Grave Robber Repartee.** The data puts the "+Dodge when missed" buff only on the mastered version; the wiki scrape shows it on the base. **(conflict)**
3. **Man-at-Arms Courageous Abandon.** The data puts Execution 2 (at ≥ 3 Block) only on the mastered version; the wiki scrape shows it on both. **(conflict)**
4. **Jester Solo crit.** 0% in the data vs 5% (10% mastered) on the wiki. **(conflict)**
5. **Flagellant Lash's Gift.** The data gives the +1 Stress to the ally; the wiki text is ambiguous.
6. **Pain heal stacking.** "Per Pain token" comes from the wiki; the data mechanism is not explicit. **(inferred)**
7. **"One of" lists.** Pick-one-at-random semantics. **(inferred)**, confirmed by the wiki for two skills.
8. **Fester on a miss.** Whether the neighbour Blight fires on a miss is **(unknown)**. **Necrosis**: hits all Blighted enemies **(inferred)**.
9. **Shrine chapters.** Chapter numbers come from `herostory_XX_0N` ids. **(inferred)** The wiki only says "unlocked at the Shrine of Reflection".
10. **Ranks.** Launch and target ranks are data-only for every skill. The wiki renders them as icons.

---

# Sources

### DD2: data (primary, data-mined)
- **[D-WB25]** Vanilla DD2 `StreamingAssets/Excel` CSV snapshot. woodbrick repo, branch `excel-files`, commit `8a6cb977e2a900723a22bbb2624dc7076826f88d` ("Initial commit: Excel game data files", 2025-12-30): https://github.com/woodbrick/darkest-dungeon-2/tree/8a6cb977e2a900723a22bbb2624dc7076826f88d
  - Files used: `hero_gr_data_export.Group.csv`, `hero_ves_…`, `hero_maa_…`, `hero_pd_…`, `hero_jes_…`, `hero_flg_…`, `dlc_dul_cru/hero_cru_data_export.Group.csv`, `effect_data_export`, `buff_data_export`, `condition_data_export`, `token_data_export`, `token ignore_data_export`, `dots_data_export`, `actor_paths_data_export`, `kingdom_hero_skill_sets_data_export` (+ `dlc_dul_cru/kingdom_hero_skill_sets_data_DLC1`), `overstress_data_export`, `ae trigger_data_export`, `combat_rules_data_export`, `skill_modifier_data_export`, `dlc_dul_cru/dlc1_effect|buff|condition_data_export`, `dlc_dul_cru/token_data_export_DLC1`.
- **[D-WB]** Same repo, `master` branch (Jan 2024 data). **A balance mod.** I used it only to show that its hero numbers differ: https://github.com/woodbrick/darkest-dungeon-2

### DD2: wiki hero pages (wiki.gg)
- [W-CRU2] https://darkestdungeon.wiki.gg/wiki/Crusader_(Darkest_Dungeon_II)
- [W-GR2] https://darkestdungeon.wiki.gg/wiki/Grave_Robber_(Darkest_Dungeon_II) (last edited 2026-01-05)
- [W-VES2] https://darkestdungeon.wiki.gg/wiki/Vestal_(Darkest_Dungeon_II) (last edited 2025-10-14)
- [W-MAA2] https://darkestdungeon.wiki.gg/wiki/Man-at-Arms_(Darkest_Dungeon_II)
- [W-PD2] https://darkestdungeon.wiki.gg/wiki/Plague_Doctor_(Darkest_Dungeon_II)
- [W-JES2] https://darkestdungeon.wiki.gg/wiki/Jester_(Darkest_Dungeon_II)
- [W-FLG2] https://darkestdungeon.wiki.gg/wiki/Flagellant_(Darkest_Dungeon_II)
- [W-PN2] Patch notes index: https://darkestdungeon.wiki.gg/wiki/Patch_notes_(Darkest_Dungeon_II)

### DD2: patch notes
- [P-2025-07] *Steadfast Stewards* v2.02.79016 (Jul 2025): https://darkestdungeon.wiki.gg/wiki/Steadfast_Stewards_Retail_Release. PD HP 28 → 30; crits no longer extend DoTs; Grave Robber keeps Combo with a Crit token; numerous PD skill changes; on-kill effects count corpse kills (Jester Wanderer Finale; Crusader Aggressor-path Smite and Reap).
- [P-SS2] *Steadfast Stewards Pt. 2* v2.04.80601. Radiance rework, Poison Dart crit duration, More! MORE! cooldown 1 → 2 and Taunt+ 2 → 3, Suffer fix, anti-block/Vulnerable fix, "0-damage crit → max damage".
  - wiki mirror: https://darkestdungeon.wiki.gg/wiki/Steadfast_Stewards_2_Retail_Release
  - official notes (consoles, Nov 18 2025): https://www.darkestdungeon.com/patch-notes/
  - PC build (Oct 29 2025): https://patched.gg/games/darkest-dungeon-2/20480601-darkest-dungeon-ii-the-steadfast-stewards-update-part-2
- [P-2026] 2026 builds; no balance changes to these seven heroes:
  - index: https://patched.gg/games/darkest-dungeon-2
  - https://patched.gg/games/darkest-dungeon-2/20483880-darkest-dungeon-ii-coming_in_hot
  - https://patched.gg/games/darkest-dungeon-2/20483892-darkest-dungeon-ii-hotfix (Man-at-Arms Bolster animation fix only)
  - https://patched.gg/games/darkest-dungeon-2/darkest-dungeon-ii-20484350-hotfix
  - https://patched.gg/games/darkest-dungeon-2/20485095-darkest-dungeon-ii-hotfix

### Project
- `docs/research/darkest-dungeon-combat.md`: token, DoT, Death's Door, Execution, Stealth, Riposte, extra-action and cooldown rules referenced above.
