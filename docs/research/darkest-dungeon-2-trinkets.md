# Darkest Dungeon II trinkets: rarities, effect building blocks and 63 trinkets

Researched on 2026-10-28 for the Godot project `darko-dungo`. We are adding **Darkest Dungeon II (DD2)** trinkets. In our game they drop from dungeons and are sold at a shop, and each hero wears two. This document gives the raw DD2 data to translate from:

- the trinket rarities, what sets them apart, prices, and where trinkets come from;
- how DD2 builds a trinket effect: stat lines, triggers, conditions, chances and payloads, with counts;
- 21 hero trinkets for our seven classes (Crusader, Grave Robber, Vestal, Man-at-Arms, Plague Doctor, Jester, Flagellant), 42 generic trinkets across the rarities (12 of them three-tier Varying trinkets), and the one pair bonus.

The translation into our engine is not done here.

## How to read this document

Every claim is tagged with its source:

| Tag | Meaning |
|---|---|
| **(data)** | Read directly from DD2's own data tables: the CSV exports of `StreamingAssets/Excel` in a public mod repo [D-WB]. Jan 2024 data (see the version caveat). |
| **(loc)** | DD2's English text strings (item names, rarity names, colours), from a translation repo [D-LOC]. Aug 2023 strings. |
| **(wiki)** | darkestdungeon.wiki.gg, mainly the DD2 Trinkets page [W-TR2]. It shows the current game. See the access caveat. |
| **(wiki+data)** | The wiki and the data give the same value. |
| **(patch)** | Red Hook's patch notes (mirrored on the wiki). Authoritative for *changes*. |
| **(FX)** | darkestdungeon2.wiki.fextralife.com. Early-Access era, low weight. |
| **(inferred)** | My own reading of field names or structure. Treat as a suggestion. |

**Conflict** marks places where sources disagree; both values are given. **Unconfirmed** marks things no source states.

> **Version caveat (important).** The data dump [D-WB] was committed in Jan 2024 (base game v1.x plus *The Binding Blade* DLC). The current game is **v2.04** (*Steadfast Stewards* part 2, Oct/Nov 2025). Hotfixes 2.04.83880 to 2.04.85095 (Mar–Apr 2026) mention no trinket changes [STEAM]. Since the data was taken, patches reworked most hero trinkets of our cast:
> - Grave Robber in *Infernal Pursuits* (Feb 2024) [P-2024-02];
> - Man-at-Arms, Jester and Vestal in *Darkside of the Mountain* (Aug 2024) [P-2024-08];
> - Plague Doctor in *Steadfast Stewards* (v2.02, Jul 2025), along with chance tweaks to Jester and Man-at-Arms trinkets [P-2025-07].
>
> The Crusader's trinkets are named in the data, but their effect definitions are missing from the dump. So **the wiki is the main source for current numbers**. The data is the source for structure (how an effect is wired) and for loot tables. Where they differ, the current (wiki) value is given first and the data value is noted.

> **Source access.** wiki.gg was read through WebFetch, which returns a model-written summary of the page, not the raw wikitext. To catch summariser errors, every hero row and every Varying and Miscellaneous row was extracted **twice**, with different prompts. The two extractions agreed. Where the data has the same trinket, the numbers were also checked against it. The wording of effect lines is the wiki's tooltip vocabulary (below); small wording differences from the game are possible. The data repo was downloaded raw with `gh api` and decoded by script.

### Notation used in the trinket tables

Effect lines use DD2's tooltip phrases, ASCII signs, separated by `;`. Each phrase maps to a data hook **(wiki + data; mapping inferred from trinkets that exist in both)**:

| Tooltip phrase | Meaning | Data hook |
|---|---|---|
| *(no prefix)* `+20% DMG` | Passive stat while worn | `ActorDataStats` in a buff with `m_DurationType infinite` |
| `If <condition>: <stat>` | Stat active only while the condition holds | buff `m_ConditionId` |
| `Apply on Hit: X` | Put X on the target the wearer hits | `on_hit_as_performer_to_target_effects` |
| `Gain on Hit: X` | Wearer gains X when it hits | `on_hit_as_performer_to_performer_effects` |
| `Apply on Miss` / `Gain on Miss` | Same, when the wearer's attack misses | `on_miss_as_performer_to_target` / `_to_performer` |
| `Apply on CRIT` / `Gain on CRIT` | Same, on the wearer's crit | `on_crit_as_performer_to_target` / `_to_performer` |
| `Gain When Hit: X` | Wearer gains X when an enemy hits it | `on_hit_as_target_to_target_effects` |
| `Apply to Attacker When Hit: X` | Put X on the enemy that hit the wearer | `on_hit_as_target_to_performer_effects` |
| `Turn Start` / `Turn End` | The wearer's own turn | `turn_start_effects` / `turn_end_effects` |
| `Round Start` / `Round End` / `Combat Start` | Battle-wide moments | `round_start_effects` etc. |
| `When Moving` / `Gain When Moved By Enemy` | The wearer changes rank / is moved by an enemy | `move_effects` / `move_enemy_effects` |
| `Target: <Skill or Ally>: X` | When the wearer uses that skill (or targets an ally), X goes on the skill's target | `target_effects` + a skill condition |
| `Self: <Skill>: X` | When the wearer uses that skill, the wearer gains X | `performer_effects` + a skill condition |
| `Gain on <X> RES` / `on <X> Resist` | When the wearer resists a Bleed/Blight/Burn/Stun/Move | `ActorEffectTrigger` type `on_resist` |
| `Each Hero on ...`, `All Allies Behind`, `Ally Ahead`, `Random Ally on ...` | The effect lands on other party members | `ActorEffectTrigger`, target `friendly_team`, count 4 (each) or 1 (random) |
| `X (33%)` | 33% chance for this line; no chance shown = 100% | effect `m_Chance` |
| `X or Y or Z` | At most one of the options applies | `*_apply_limit = 1` |
| `per <thing>` | Scales with a count | condition number type `MULTIPLE` |

Other terms:

- **DoT sizes.** `Bleed 1`, `Bleed 2` and `Bleed 3` are the data's `very_small`, `small` and `medium` DoTs (wiki + data, matched on Tinderbox, Enlightening Element and Fishmonger's Gloves). `Regeneration 2` is `heal_hot_small`. DoT rules are in [darkest-dungeon-combat.md](darkest-dungeon-combat.md).
- **`+1 Bleed Dealt`** adds 1 to each Bleed the wearer applies (`dot_effect_value_dealt_change`). **`+2 Bleed Duration Dealt`** adds turns (`dot_extra_duration_dealt`). **`... Received`** is the same on the wearer's side. **(data)**
- **`RES Piercing`** lowers the target's resistance for the wearer's effects (`resistance_ignore`). **(data)**
- **`Add 1 Positive Token`** adds one random token from {Crit, Dodge, Strength, Block, Speed}. **`Add 1 Negative Token`** adds one random token from {Blind, Weak, Taunt, Vulnerable, Immobilize}. The tags are `pos_trinket_token` and `neg_trinket_token`. **(data)**
- **Execution N** and **Guard/Guarded**: see [darkest-dungeon-combat.md](darkest-dungeon-combat.md).
- **Stress** is DD2's 0–10 scale. **Flame** is the run's torch value, 0–100. **Relics** are the run's gold. **Baubles** are the currency for trinkets. In the game strings, `item_name_gold=Relics` and `item_name_faction=Baubles`. **(loc)**
- **Item tags** (`Armor`, `Weapon`, `Flammable`, `Noxious`, `Serrated`, `Stained`) sit on trinkets and items. Other trinkets check them ("If Armor item is equipped"). **(data)**

---

## TL;DR

```
Rarity (data sub_type)   Colour (loc)  Price in Baubles (shop)           # in data  What it is
Vague        (common)    grey #54595C  5   (was 10 until Kingdoms, Jan 2025)  12   lowest tier of the 12 "Varying" stat trinkets: 1 small stat + 1 small malus
Distant      (rare)      teal #3B6062  20 Varying / 30 all others            49   middle Varying tier; 13 "Miscellaneous" token-trigger trinkets; 24 region trinkets
Indelible    (epic)      gold #B0935E  50 Varying / 65 hero, region, Hoarder 119  top Varying tier (no malus); 3 hero trinkets per class; region, Hoarder,
                                       boss/enemy/curio ones are not sold        boss, enemy and curio trinkets
Unforgettable (cultist)  slate #677E9D not sold                              22   9 "Dark Impulse" (Stained) keys + 13 Cultist trinkets: huge bonus + huge malus;
                                                                                  a Cultist trinket can only be worn next to a Stained item
Ancestral                ?             not sold                               0   3 Ancient Adversary trinkets; new rarity since v2.02 (Jul 2025)
Hero trinkets are Indelible + a class lock (3 per class), unlocked by spending candles on that hero's track.
Each hero wears 2. A trinket can't be held twice (possession limit 1).
```

**How they are obtained** (data loot tables, Jan 2024; wiki for shops):

- **Road battles.** Each roll of the battle trinket table gives a trinket 1 time in 3. When one drops it is, by weight, Vague 10 : Distant Varying 3 : Miscellaneous 3 : Indelible Varying 1 : hero 1.
- **Vague** trinkets carry a loot condition that limits them to a run's first two regions (data condition; the reading is inferred).
- **Region trinkets** drop only in their own region.
- **Bosses and mini-bosses** roll better tables plus their own exclusive trinkets.
- **Cultist fights** give the Unforgettable ones.
- **Shops.** The Hoarder (a road shop) has 5 Vague, 5 Distant and 5 Indelible slots plus 7 Hoarder-only Indelibles. The Inn has a trinket shop.
- **Unlocks.** Generic trinkets are unlocked into the loot pool with Candles of Hope (tiers cost 1/2/3 candles).
- **Selling** exists only in the Kingdoms mode, or through an end-game mutator, "for a small fraction" of the price. No exact numbers are published.

**Effect building blocks:**

- **Passive stats:** DMG%, CRIT%, SPD, Max HP%, healing given and received, resistances, RES piercing, DoT dealt/duration.
- **Conditional stats** ("If X: stat"), gated by: skill used, rank, own or target tokens/DoTs, HP%, Speed, first in turn order, equipped item tags, Flame, Relics.
- **Triggers:**

  | Trigger | Trinkets (of 193) |
  |---|---|
  | Turn Start | 35 |
  | Apply on Hit | 26 |
  | Gain on Miss | 17 |
  | Turn End | 12 |
  | Gain When Hit | 10 |
  | Target/Self skill hooks | 17 |
  | Resist events | 11 |
  | Ally/team triggers | 13 |
  | Apply to Attacker When Hit | 7 |
  | When Moving | 6 |
  | On crit | 10 |
  | Death's Door enter/exit | 4 |

- **Payloads:** add a token (by far the most common), add a DoT, ±Stress, heal, convert, remove or steal tokens, extra action, flat damage.
- **Chances:** usually 10/15/20/25/33/50/66/100%.

---

## 1. Rarities

### 1.1 The rarity ladder

| Rarity | Internal `sub_type` | Price (Baubles) | Count in data | Contents | Strength and drawbacks | How obtained |
|---|---|---|---|---|---|---|
| **Vague** | `common` **(data)**; display name "Vague Trinket" **(loc)** | **5** (Kingdoms update, Jan 2025: "Reduced cost of Vague trinkets from 10 to 5 Baubles") **(patch)** [P-2025-01]. Data says 10. | 12 | Lowest tier of the 12 Varying trinkets (data names "Minor Heartseeker" etc. **(loc)**) | One stat bonus plus one malus, e.g. Sharpness Charm: +10% DMG; -2 SPD **(wiki)** | Loot and the Hoarder. Every Vague loot entry has the condition `biome_typical_count <= 2` **(data)**, i.e. only in the first two regions of a run (inferred). At the Hoarder, Vague slots become Distant in the final region and after Escalation 1 in Kingdoms (v2.02) **(patch)** [P-2025-07]. |
| **Distant** | `rare` | **20** for Varying, **30** for Miscellaneous and region trinkets **(wiki+data)** | 49 = 12 Varying + 13 Miscellaneous + 24 region | Middle Varying tier. Misc: a token trigger plus a malus trigger (a self-debuff, or a buff handed to the enemy on a miss). Region: two lines tied to that region's theme. | Bonus plus malus. v2.02: "All downsides on Distant stat trinkets now match the values of Vague versions" **(patch)**. The wiki page does not fully reflect that (see Conflicts). | Loot, Hoarder, Inn shop, supply caches. Region trinkets "can only be found in" their region **(wiki)**. |
| **Indelible** | `epic` | **50** for Varying, **65** for hero, region and Hoarder trinkets **(wiki+data)**. Boss, enemy, Collector and curio trinkets have cost 1000 in the data, i.e. not sold (inferred). | 119 = 12 Varying + 42 hero + 14 region + 7 Hoarder-only + 2 Chirurgeon + 42 not-sold specials | Top Varying tier; all hero trinkets; region, Hoarder, boss and curio trinkets | Varying top tier: bonus only, **no malus** **(wiki)**; the data still has a malus (conflict). Hero trinkets: usually two upsides and one downside (inferred from the rows below). Boss trinkets: strong, rarely a malus. | Rare loot (about 1 in 54 road-battle rolls per category, below). Boss and mini-boss tables, Hoarder, Inn shop, curios in Academic's Study nodes, hero goals. |
| **Unforgettable** | `cultist` | Not sold (data cost 1000; inferred) | 22 = 9 Dark Impulse + 13 Cultist | **Dark Impulse** ("Stained"): one resist bonus plus a stress malus. **Cultist**: an extreme bonus and an extreme malus, e.g. Misstep +75% HP; -50% DMG. | The strongest and riskiest. A Cultist trinket "cannot be equipped without a Dark Impulse or a Shambler's Spawn" (data item condition `performer_has_stained_tag_equipped`). Unequipping the Dark Impulse unequips both **(wiki+data)**. | "Only found from Cultist encounters in any region" **(wiki)**. Data `cultist_battle_trinket_general` weights: Distant/Indelible generic 2 : Cultist 1, +7 more for Cultist if the Shambler pet is equipped. |
| **Ancestral** | not in data | Not sold (unconfirmed) | 0 (added later) | Ancestor's Coat, Ancestor's Moustache Cream, Ancestor's Pistol | Very strong, with a shared malus: `+100% Horror Received` **(wiki)** | Dropped by the Ancient Adversary (the Ancestor's Statue encounter). "Ancestor's Statue trinkets have been changed from Indelible to Ancestral" (v2.02) **(patch)**. |
| *Hero (not a rarity)* | `epic` + item condition `performer_is_<class>` **(data)** | 65 | 3 per class (15 classes on the wiki) | Class-specific, often naming class skills | As Indelible | Unlocked by spending Candles of Hope on that hero's track in the Living City **(wiki)** [W-AOH-LC]. Data `m_UnlockId` is `<class>_2/_5/_9` for heroes with no candle unlock on their track (Highwayman, Man-at-Arms, Grave Robber, Plague Doctor, Crusader, Duelist), `_3/_6/_10` for heroes that cost 4 candles to unlock, and `_3/_6/_9` for the Bounty Hunter **(data)**. Reading the number as the node position on the track is inferred. Drops only when that class is in the party (data loot condition `hero_party_has_<class>`). Hero goals can reward one (Last Light) **(patch)**, and hero trinkets "are now pre-rolled for hero goals" (v2.02) **(patch)**. |

Colours are the rarity text colours in the game strings: `trinket_common=#54595C`, `trinket_rare=#3B6062`, `trinket_epic=#b0935e`, `trinket_cultist=#677E9D` **(loc)**. The Ancestral colour is **unconfirmed**.

### 1.2 Equip, uniqueness, prices, selling

- **Two per hero.** The game text quoted on fextralife says "Each hero may equip up to 2 TRINKETS at a time" **(FX)**. Trinkets "can be removed or swapped outside of combat" **(wiki)**.
- **No duplicates.** Every trinket has `m_possessionLimit 1`, `m_maxQty 1` and `m_combinable False` **(data)**. Patch fixes in Dec 2023 mention "trinket possession limit rules" that also count the trinkets worn by heroes [P-2023-12-05]. Reading: you cannot own two copies of the same trinket at once **(inferred)**.
- **Prices** are in Baubles (data `m_ItemTag faction`) **(data)**:
  - Vague 5 (was 10);
  - Distant Varying 20;
  - Distant Miscellaneous and region 30;
  - Indelible Varying 50;
  - hero, region and Hoarder 65.

  The stagecoach item *Merchants' Guild Seal* gives "-20% Trinket Prices" **(wiki)** [W-AOH-WF].
- **Selling.** A normal Confessions run has no selling; v2.02 added it only as an opt-in mutator **(inferred from the patch below)**. In **Kingdoms** mode, items can be sold to the Hoarder for "a small fraction of their original price" **(wiki)** [W-HOARD]. In Confessions, v2.02 added a run mutator at *The Dam*, "Enable Selling to Hoarders … for a small amount of relics/gold", which is locked until Act 5 **(patch)** [P-2025-07]. **No sell value is published (unconfirmed).** Every trinket has `m_DiscardGameScorePerQty 1` **(data)**; its meaning is unknown.

### 1.3 Where trinkets come from (loot tables)

Weights from the data (Jan 2024). "Varying D" means the Distant tier, "Varying I" the Indelible tier, "Misc" the 13 Miscellaneous trinkets, "Region" the current region's trinkets. **(data)** unless marked.

| Source | Table | Weights |
|---|---|---|
| Road battle | `road_battle_trinket_default` | Vague **10**, Varying D 3, Misc 3, Varying I 1, Hero 1, *nothing 36* (so 33% a trinket; Vague 18.5%, Indelible 1.9%, hero 1.9%) |
| Road battle, regional variant | `road_battle_trinket_faction` | Varying D 3, Varying I 1, Region Distant 3, Region Indelible 1, Hero 1, *nothing 27* (only the current region's entries are valid) |
| "Resistance" battle | `resistance_battle_trinket_default` | Vague 6, Varying D 3, Misc 3, Varying I 2, Hero 2, *nothing 14* (53% a trinket) |
| Lair boss | `lair_boss_battle_trinket_general` + `..._faction_boss` | Misc 1, Varying D 1, Varying I 1, Hero 1 (no "nothing"); plus one of the region boss's own trinkets (Librarian, Harvest Child, Dreaming General, Leviathan) |
| Mini-boss | `miniboss_battle_trinket_general` | Varying D 2, Misc 2, Varying I 1, Hero 1; Shambler and Death add their own exclusive tables |
| Cultist battle | `cultist_battle_trinket_general` | Distant/Indelible generic 2, Cultist 1 (+7 Cultist with the Shambler pet) |
| Supply cache | `supply_cache_trinket` | Region Distant 17, Region Indelible 1, Varying I 1, Hero 1 |
| Hoarder shop | `hoarder_shop` | 5 slots from Vague; 5 from {Region Distant, Misc, Varying D}; 5 from {Varying I, Region Indelible, Hero, Hoarder-only} (equal weights). The *Hoarder Signal Decoder* doubles the trinket selection **(wiki)**. |
| Inn trinket shop | `inn_trinketshop_items` | 3 slots Varying (D 9 : I 1), 2 slots Misc 9 : Hero 1, and 1 slot for each of the five regions' lists (Distant 9 : Indelible 1). *Infernal Pursuits* (Feb 2024, after the data): "Inns have increased shop selection for trinkets" **(patch)**; the new slot counts are **unconfirmed**. |
| Curios | `trinkets_curio_*` | Academic's Study trinkets drop from specific curios **(wiki+data)** |
| Collector, Chirurgeon, Antiquarian, Warlord, Ancient Adversary | own tables | Exclusive enemy trinkets "dropped only by certain rare enemies and lair bosses" **(wiki)** |

The stagecoach item *Trinket Organizer* gives "Increased Chance of Looting Trinkets" **(wiki)**. Every battle loot entry above carries the tag `TRINKET_CHC` **(data)**, probably the hook for that bonus **(inferred)**.

**Unlocking into the pool.** Candles of Hope unlock generic trinkets at the Working Fields in tiers. Tier 1 costs 1 candle, tier 2 costs 2, tier 3 costs 3. "Items are unlocked at random within a tier," and a tier must be finished before the next one opens. "Once unlocked, an item will be added to the loot pool for all future expeditions." **(wiki)** [W-AOH-WF]. The Varying trinkets are not on that list, so they are presumably in the pool from the start **(inferred)**.

**Mapping to our design** *(inferred)*:

- DD2's "rarer ones less often" is the loot weight ladder: Vague 10 : Distant 6 : Indelible 1 : Hero 1.
- "Best in harder dungeons" is the Vague cut-off after region 2 and the Hoarder's Vague-to-Distant swap in the final region.
- "From bosses" is the boss tables, which have no "nothing" entry, plus boss-exclusive Indelibles.

---

## 2. How effects are built

### 2.1 The data model

A trinket in the data is a small graph **(data)**:

```
Item  trinket_<id>          sub_type (rarity), m_tags (armor/weapon/...), m_conditionIds (equip requirement,
                            e.g. performer_is_vestal or performer_has_stained_tag_equipped), m_UnlockId, m_buyCostId
 └─ ActorDataExternalBuffs  buffs: [buff ids]          (1–5 buffs; one tooltip line each, roughly)
     └─ Buff                m_DurationType infinite (while worn), optional m_ConditionId (gate), m_IsVisible
         ├─ ActorDataStats  key_map + add_stats (flat/percent) | key_map + multiply_stats (Max HP) |
         │                  sub_stat <stat>,<subkey>,<value> (resistance,bleed,0.2 / dot_effect_value_dealt_change,burn,2)
         ├─ ActorDataEffects <hook>: [effect ids]   + optional <hook>_apply_limit = N
         │                  actor_effect_triggers: [trigger ids]   (team/other-actor events, on_resist)
         │                  token_ignores: [...]   (Execution N, Ignore Blind, ...)
         └─ RunDataStats    run-level modifiers (one trinket only)
Effect      m_Chance, all_conditions [condition ids], one payload:
            m_TokenAddId|m_TokenAddTag + Amount, m_DotAddId, m_StressDamage, m_StressHeal,
            m_HealthHealPercent|Amount, m_HealthDamageAmount, m_AddTurn, m_Move,
            m_TokenRemoveId|Tag, m_TokenStealTags, m_TokenConvertFrom/To, buffs (timed buff), m_IgnoreResist
ActorEffectTrigger  m_ActorEffectType (turn_start, combat_start, on_resist, ...), target type (friendly_team, target),
            m_ActorCount (1 = random one, 4 = each), m_IncludeSourceActor
Condition   m_ConditionType, m_ConditionActorType (PERFORMER/TARGET/MONSTERS/PARTY/NONE), string, number,
            number type (EQUAL, LESS_THAN, GREATER_THAN_OR_EQUAL, BOOL, PARAMETER, MULTIPLE = "per")
```

Two things to note:

- A trinket's **timed effects** are themselves buffs. His Prison applies a 3-turn debuff buff (`performer_turn_end`, 3) to the attacker.
- The data has a `TrinketSet` table, but its only entry is `test_cave_trinket_set`. There is no live set system **(data)**.

### 2.2 Triggers (hooks), with how often each appears

Count = number of trinkets, out of the 193 whose effects are in the data, that use the hook at least once **(data)**. Almost every current wiki line in section 3 maps onto these hooks; the exceptions are listed under the table. So patches since then mostly changed numbers rather than this vocabulary **(inferred)**. The current wiki adds a few phrases (last table) **(wiki)**.

| Tooltip trigger | Data hook | Trinkets |
|---|---|---|
| Turn Start (wearer) | `turn_start_effects` (+3 with apply limit) | 32 (+3) |
| Apply on Hit | `on_hit_as_performer_to_target_effects` (+ apply limit) | 22 (+4) |
| Gain on Miss | `on_miss_as_performer_to_performer_effects` | 17 |
| Turn End | `turn_end_effects` (+ apply limit) | 10 (+2) |
| Gain When Hit | `on_hit_as_target_to_target_effects` (+ apply limit) | 9 (+1) |
| Target: \<skill / ally\> | `target_effects` | 9 |
| Self: \<skill\> | `performer_effects` | 8 |
| Apply to Attacker When Hit | `on_hit_as_target_to_performer_effects` (+ apply limit) | 6 (+1) |
| When Moving | `move_effects` | 6 |
| Gain on CRIT | `on_crit_as_performer_to_performer_effects` | 6 |
| Gain on Hit | `on_hit_as_performer_to_performer_effects` (+ apply limit) | 4 (+1) |
| Apply on Miss | `on_miss_as_performer_to_target_effects` | 4 |
| Apply on CRIT | `on_crit_as_performer_to_target_effects` | 4 |
| On Entering Death's Door | `deaths_door_enter_effects` | 4 |
| On Leaving Death's Door | `deaths_door_exit_effects` | 3 |
| Round Start | `round_start_effects` (+ apply limit) | 3 (+1) |
| When Stress Damaged | `combat_stress_damage_effects` | 3 |
| Gain When Moved By Enemy | `move_enemy_effects` | 3 |
| Round End | `round_end_effects` | 2 |
| Combat Start (wearer) | `combat_start_effects` | 2 |
| On Kill / Killing Blow | `on_kill_as_performer_to_performer_effects` | 2 |
| Gain When Moved by Ally | `move_friendly_effects` | 1 |
| Missed by an enemy (wearer is target) | `on_miss_as_target_to_target_effects` | 1 |
| On attack, hit or miss | `on_attack_as_performer_to_target_effects` | 1 |
| On Resolute | `on_overstress_effects` | 1 |
| **Actor-effect triggers** (other actors or resist events): | `actor_effect_triggers` | 24 |
| – Gain on \<Bleed/Blight/Burn/Stun/Move\> resist | type `on_resist` | 11 |
| – Turn Start: Random Ally / Each Hero | type `turn_start`, `friendly_team` | 6 |
| – Combat Start: Each Hero / All Allies | type `combat_start`, `friendly_team`, count 4 | 4 |
| – Turn End: Random Ally / Ally Ahead | type `turn_end` | 2 |
| – Round Start / Round End: Each Hero | types `round_start` / `round_end` | 1 / 1 |

**Phrases in the current wiki that have no example in the Jan 2024 data** **(wiki)**:

- `Apply to Attacker when Missed` (His Rings);
- `When Healed` (Heart-Shaped Padlock);
- `Gain on Non-Crit` (Cruel Intent, v2.02);
- `Invert N Positive/Negative Tokens` (Plague Doctor);
- `Copy Positive Token` (Caked Palette);
- `Instant Kill (20%)` with `Ineffective against Bosses` (Murder Weapon);
- `Move Shuffle` (Faceless Visage);
- `Flame -5` (Icon of the Light);
- `+2 Relics, +1 Bauble` (His Rings).

### 2.3 Conditions, with how often each appears

"Gates a stat" counts buff-level conditions (`If X: stat`). "Gates an effect" counts conditions on a triggered effect (`Turn Start: If X: token`) **(data)**.

| Condition | Data type (actor) | Gates a stat | Gates an effect | Example |
|---|---|---|---|---|
| Skill used is X / melee / ranged | `skill`, `skill_tag` (NONE) | 15 | 33 | Gnarly Knuckles: Melee Skills: +20% DMG |
| Resisted a Bleed / Blight / Burn / Stun / Move | `on_resist` + `if_<x>_resist` | – | 11 | Fate's Foreteller: Gain on DoT Resist: Heal 20% |
| Own Speed ≥ / ≤ N (thresholds 2, 6, 8, 10, 12) | `actor_stat_value` | 0 | 11 | Parrying Patriarch: Turn Start: If Speed <= 2: Weak (10%) |
| First / last in turn order | `first_initiative` / `last_initiative` | 0 | 8 / 1 | Price of Pride: Turn Start: If First in Turn Order: Blind |
| Rank = N | `rank` (PERFORMER) | 6 | 7 | Signed Indenture: Turn End: If Rank = 4: Weak |
| Wearer has / lacks token X | `token_amount` (PERFORMER) | 4 | 7 | Foreclosure Notice: If Stealth: +20% DMG |
| Target has token X | `token_amount` (TARGET) | 3 | 1 | Bone Mallet: If Target has Stun: +50% DMG |
| Per positive / negative token on wearer | `token_tag_amount`, `MULTIPLE` | 6 | 0 | Cursed Coin: +5% DMG per positive token |
| Wearer has a DoT | `dot_tag_amount` (PERFORMER) | 4 | 5 | Carved Bodkin: Turn Start: If Bleed: Extra Action (20%) |
| Target has a DoT | `dot_tag_amount` (TARGET) | 4 | 0 | Severed Finger: If Target Bleed: +25% DMG |
| Item with tag equipped (Armor, Weapon, Flammable, Noxious, Serrated) | `item_equipped_tag` | 7 | 4 | Armory Key: If Armor item is equipped: +20% Max HP |
| Specific combat item equipped | `combat_item_equipped` | 1 | 2 | Fisherman's Line: If Fisherman's Net is Equipped |
| Wearer diseased | `quirk_tag_amount` | 6 | 1 | Hint of Home: If Disease: -10% DMG |
| HP above / below N% | `health_percent` | 3 | 0 | Emancipation: If HP < 20%: +25% DMG |
| Stress (per point, or = 5) | `stress` | 3 | 1 | Hierarchy of Sights: +10% DMG per Stress |
| Enemy party contains a type (animal, gaunt) | `tag` (MONSTERS) | 3 | 1 | old Rat Skull: healing malus vs animals |
| Target is not a corpse | `tag` (TARGET) | 0 | 4 | Death's Head: "Ineffective against corpses" |
| Flame above / below N | `run_value` (torch) | 5 | 6 | Covert Cloak: Round Start: If Flame < 50: Stealth (66%) |
| Relics / Baubles above / below N | `item_amount` / `item_tag_amount` | 6 | 3 | Pilfered Wealth: If Relics < 10: +10% CRIT |
| At Death's Door | `status` | 2 | 0 | (Death's Head variants) |
| Per round elapsed | `round`, `MULTIPLE` | 1 | 0 | old Inevitable End |
| Per missing ally | party tag count, inverse | 1 | 0 | Thrilling Tablet: +100% DMG per Missing Ally |

### 2.4 Payloads and passive stats

**Triggered payloads** (trinkets using each kind) **(data)**:

| Payload | Trinkets | Notes |
|---|---|---|
| Add a specific token | 66 | Most added: Crit 10, Weak 10, Vulnerable 9, Block 9, Strength 9, Stealth 8, Combo 7, Stun 7, Blind 7, Taunt 5, Daze 5, Block+ 4, Immobilize 4, Speed 4, Dodge 4, Dodge+ 2, Riposte 1 |
| Add a DoT (Bleed / Blight / Burn) or Regeneration | 22 | sizes 1–3 (5 on Shambler and Death trinkets) |
| +Stress on the wearer or allies | 21 | almost always the malus line |
| Add a random positive / negative token | 12 | tag pools, see Notation |
| -Stress | 10 | |
| Extra action | 7 | `m_AddTurn 1`, usually 20% |
| Convert token A → B | 7 | e.g. Stone Mount: Block → Block+; Footman's Grog: Weak → Strength |
| Remove tokens by tag (negative) / by id (Combo, Weak) | 6 / 5 | |
| Heal % of max HP / flat HP | 6 / 3 | |
| Flat damage to attacker or self | 5 | |
| Apply a timed buff or debuff | 4 | e.g. +1 Blight Received for 3 turns |
| Steal tokens | 2 | |
| Remove a disease, knockback, remove buffs by tag | 1 each | |

**Passive stats** (`ActorDataStats`; trinkets using each) **(data)**:

| Stat | Trinkets |
|---|---|
| DMG % (`health_damage_dealt_percent`) | 38 |
| CRIT chance | 20 |
| SPD (flat) | 17 |
| Max HP % (`multiply_stats`) | 16 |
| Healing Received from Skills % | 12 |
| Healing Given % | 10 |
| DMG Received % | 5 |
| Resistances (per trinket) | Bleed 10, Burn 10, Blight 9, Deathblow 9, Move 8, Debuff 8, Disease 7, Stun 7, Stress 5 |
| RES Piercing | Debuff 4, Bleed 3, Blight 3, Burn 3, Move 1 |
| DoT dealt +N | Bleed 3, Blight 3, Burn 3, Regeneration 1 |
| DoT duration dealt +N | Burn 2, Bleed 1, Blight 1 |
| DoT received +/-N | Bleed 2, Blight 1 |
| Resolute / Meltdown chance | 3 |
| Token ignores (Execution 1, Ignores Blind / Block / Dodge) | 4 |

**Chances** (trinkets using each value at least once) **(data)**: 100% in 81; 33% in 21; 15% in 17; 50%, 20% and 10% in 14 each; 66% in 12; 25% in 7; 5% in 3; 80% and 90% in 2 each; 70% and 30% in 1 each. The current wiki has moved several on-hit debuffs down to 15% (see Conflicts).

### 2.5 Design patterns (inferred from the lists below)

- **Varying:** a single stat, in three tiers. The two lower tiers carry a malus stat; the top tier carries none (wiki).
- **Miscellaneous:** two lines on the same idea.
  - Either an upside trigger on the wearer plus a self-debuff on miss: `Turn Start: Strength (15%); Gain on Miss: Weak (20%)`.
  - Or a debuff on the enemy on hit plus a buff handed to the enemy on a miss: `Apply on Hit: Weak (15%); Apply on Miss: Strength (20%)`.
- **Hero:** three lines. Usually one stat or conditional line, one line tied to a class skill (`Self:` or `Target:`), and one malus (Stress, a self-debuff or a RES penalty).
- **Region:** themed on that region's mechanic: Flame in the Sluice, low/high Speed in the Sprawl, item tags and Disease in the Foetor, first in turn order in the Tangle, Serrated items and Bleed in the Shroud.
- **Boss and enemy:** strong team effects or extra actions, with rarely a malus.
- **Unforgettable:** one extreme bonus and one extreme malus. Equipping one requires a Stained item.
- **"X or Y" lines.** These have an apply limit of 1. In Pristine Lure, the options keep their own chances: Taunt (50%) or Taunt x2 (25%). In Nautical Compass, all five options are 100% with limit 1, and the wiki shows them as a random pick ("Block or Crit or Dodge or Strength or +1 Stress"). The exact selection order is **unconfirmed**.
- **Independent rolls.** Lines are rolled independently unless limited. Sparkleball rolls five separate 15% debuffs on every hit **(data)**.

---

## 3. Trinket list

Effect lines are the **current wiki** values unless the Source column says otherwise. The Source column gives data deviations in brief. Hero skill names are DD2's; our cast's skills may differ.

### 3.1 Hero trinkets (21)

All are **Indelible, 65 Baubles**, locked to the class (wiki + data, except the Crusader: wiki only).

**Crusader** *(The Binding Blade DLC; effects absent from the data dump)*

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Signed Indenture | Indelible | Crusader | When Moving: Ally Behind: Block ; Target: Rallying Cry Skills: +20% Debuff RES ; Turn End: If Rank = 4: Weak | (wiki) [W-TR2]; data `crusader_2` |
| Pilfered Wealth | Indelible | Crusader | If Relics in inventory < 10: +10% CRIT ; Target: Reap Skills: Steal 1 Positive Token ; Self: Reap Skills: -2 Relics (33%) | (wiki); data `crusader_5` |
| Fieldstone | Indelible | Crusader | Apply to Attacker When Hit: Burn 1 (66%) ; Self: Radiance Skills: +1 Burn Dealt (4 turns) ; Turn End: If Combo: +1 Stress | (wiki); data `crusader_9` |

**Grave Robber** *(reworked in Infernal Pursuits, Feb 2024 [P-2024-02])*

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Foreclosure Notice | Indelible | Grave Robber | If Stealth: +20% DMG ; Self: Shadow Fade: Remove all Negative Tokens ; If no Stealth: -25% Healing Received from Skills | (wiki+patch). Data (pre-rework): Apply on Hit: If Rank = 4: Combo (50%) ; Gain on Hit: Flashing Daggers: Stealth x2 (33%) ; If no Stealth: -25% Healing Received. Unlock `grave_robber_2`. |
| His Rings | Indelible | Grave Robber | Apply to Attacker when Missed: Combo ; Pick to the Face: +10% CRIT ; Self: Dead of Night: +2 Relics, +1 Bauble ; Gain When Hit: +1 Stress (15%) | (wiki+patch; the patch calls the skill "Death of Night"). Data (pre-rework): Poison Dart: +2 Blight Dealt ; Apply on CRIT: Ranged Skills: Blight 2 ; If Rank = 1: +75% DMG Received. `grave_robber_5` |
| Stiff Drink | Indelible | Grave Robber | Apply on CRIT: Blight 1 ; If Stealth: +1 Blight Dealt ; Self: Absinthe: Blight 1 (on the wearer, per the "Self:" prefix) | (wiki+patch). Data (pre-rework): Pick to the Face: +50% DMG ; Turn Start: Convert Stealth to Crit (80%) ; Turn End: Convert Speed to Daze (20%). `grave_robber_9` |

**Vestal** *(adjusted in Darkside of the Mountain, Aug 2024 [P-2024-08])*

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Icon of the Light | Indelible | Vestal | +1 Regeneration Dealt, or +2 Regeneration Dealt when Flame is 100 ; Target: Consecration Skills: -1 Stress ; Gain When CRIT: Flame -5 (66%) | (wiki+patch). Data (pre-change): If Rank = 4: +2 Regen Dealt ; Target: blessing skills: -1 Stress ; Melee Skills: -50% DMG. `vestal_3` |
| Smoldering Firewood | Indelible | Vestal | If Flammable item is equipped: +25% DMG ; Target: Ranged Skills: Burn 2 ; Gain When Hit: Burn 1 (15%) | **(wiki+data)**; `vestal_6` |
| Profane Scroll | Indelible | Vestal | +1-2 DMG ; If Flame < 50: +30% Stun RES Piercing ; Self: Ally Behind: Hand of Light: Guard x2 ; Gain on Miss: +1 Stress (25%) | (wiki+patch). Data (pre-change): If Rank = 1: +25% Max HP ; If Rank = 2: +25% DMG ; Self: Hand of Light: Taunt x2 ; hidden: Turn End in Rank 3 or 4: +2 Stress. `vestal_10` |

**Man-at-Arms** *(reworked Aug 2024 [P-2024-08]; Undeserved Commendation retuned v2.02 [P-2025-07])*

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Price of Pride | Indelible | Man-at-Arms | Gain When Hit: Block+ (33%) ; Self: Rampart: Riposte ; Turn Start: If First in Turn Order: Blind | (wiki+data for lines 1 and 3; line 2 per patch; the data had "Bellow: Stun (10%)"). `man_at_arms_2` |
| Standard of the Ninth | Indelible | Man-at-Arms | Each Hero on Combat Start: Block+ ; Apply to Attacker When Hit: Remove 1 Positive Token ; Gain When CRIT: Weak | (wiki+patch; line 1 also in data). Data (pre-rework): Courageous Abandon: +50% CRIT ; Gain on Miss: If Rank = 1: Weak. `man_at_arms_5` |
| Undeserved Commendation | Indelible | Man-at-Arms | Target: Ally: Crit (15%) ; Target: Command Skills: Block, Taunt ; Apply on Miss: All Allies Behind: +1 Stress | (wiki+patch: 10% → 15% and "hero" → "ally" in v2.02). Data (pre-rework): If Rank = 2: +25% Max HP ; Target: Command: Crit (33%) ; When Moving: If Rank = 1: +1 Stress. `man_at_arms_9` |

**Plague Doctor** *(reworked in Steadfast Stewards, v2.02, Jul 2025 [P-2025-07])*

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Annotated Textbook | Indelible | Plague Doctor | Target: Ally: Invert 1 Negative Token (65%) or +1 Stress (5%) ; If Restorative item is equipped: +50% Healing Given from Skills ; Turn Start: If First in Turn Order: Vulnerable (33%) | (wiki+patch). Data (pre-rework): Melee Skills: +10% CRIT ; If Medicinal Herbs equipped: +50% Healing Given ; Turn Start: If First: Vulnerable (100%). `plague_doctor_2` |
| Early Experiment | Indelible | Plague Doctor | If Noxious item is equipped: +1 Blight Dealt ; Apply on CRIT: Invert 2 Positive Tokens ; Gain When Moved By Enemy: Bleed 1 (15%) or Blight 1 (15%) or Burn 1 (15%) | (wiki+patch). Data (pre-rework): If Noxious: +2 Blight Dealt ; Apply on Hit: Disorienting Blast: Blight 2 (50%) ; Incision: bleed-dealt multiplier -1 (data field `dot_effect_value_dealt_multiplier`). `plague_doctor_5` |
| Storage Room Key | Indelible | Plague Doctor | Target: Ounce of Prevention: Block ; Target: Emboldening Vapours: Regeneration 2 ; +1 SPD per Medicinal Gear Equipped ; Gain on Miss: -1 SPD (3 turns) | (wiki+patch; lines 1–2 also in data). Data line 3: Battlefield Medicine: -50% Healing Given. "Medicinal Gear" is an item category; which items count is **unconfirmed**. `plague_doctor_9` |

**Jester** *(reworked Aug 2024 [P-2024-08]; Busker's Haul retuned v2.02 [P-2025-07])*

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Severed Finger | Indelible | Jester | If Target has Bleed: +25% DMG ; Round Start: If Bleed: Add 1 Positive Token ; +1 Bleed Duration Received | (wiki+patch; line 1 also in data). Whether "If Bleed" means the Jester or the target is **unconfirmed**; the Jester is likelier, given the malus (inferred). Data (pre-rework): Slice Off: +2 Bleed Dealt ; +1 Bleed Received. `jester_3` |
| Royal Summons | Indelible | Jester | When Moving: Crit (10%) ; Gain on CRIT: All Allies Behind: Add 1 Positive Token ; Gain When Hit: Forward 1 | (wiki+patch; line 1 also in data). Data (pre-rework): Play Me Out: Remove 1 Negative Token ; Turn End: If Rank = 4: Taunt. `jester_6` |
| Busker's Haul | Indelible | Jester | Target: Ally: Dodge (33%) ; Target: Play Out Skills: Remove 1 Negative Token ; Target: Battle Ballad Skills: Turn Start: Forward 1 (1 turn) ; Turn End: If Relics in inventory < 25: +1 Stress (25%) | (wiki+patch: 20% → 33% and "hero" → "ally" in v2.02). Data (pre-rework): Turn End: Random Ally: If Rank = 1: Add 1 Positive Token ; Solo: Crit (50%) ; If Relics < 25: -25% DMG. `jester_10` |

**Flagellant** *(no rework found in the patch notes)*

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Emancipation | Indelible | Flagellant | If HP < 20%: +25% DMG ; Target: Punish: Steal 1 Positive Token ; -20% Bleed RES | **(wiki+data)**; `flagellant_3` |
| Searing Scripture | Indelible | Flagellant | Round End: Remove 1 Negative Token, Remove Combo ; Target: Hero: Steal 1 Negative Token, Steal Combo ; -20% Burn RES | (wiki). **Conflict:** the data gates the steal lines on the *Endure* skill, not "Target: Hero"; the rest matches. `flagellant_6` |
| His Prison | Indelible | Flagellant | Apply to Attacker When Hit: +1 Blight Received for 3 turns (33%) ; Self: More! MORE!: Strength ; -20% Blight RES | (wiki; lines 1–2 also in data). **Conflict:** the data's third line is a relationship malus (`affinity_tick_trigger_negative_chance_multiplier +0.1`), not -20% Blight RES. `flagellant_10` |

### 3.2 Generic trinkets (42)

#### Varying trinkets (12 names × 3 rarities)

Each exists as Vague (5 Baubles), Distant (20) and Indelible (50). Usable by any hero. Current wiki values are below; the Jan 2024 data values are in the next table. **The two disagree** (see Conflicts).

| Name | Rarity | Hero | Effects (wiki) | Source |
|---|---|---|---|---|
| Sharpness Charm | Vague / Distant / Indelible | any | V: +10% DMG ; -2 SPD<br>D: +15% DMG ; -3 SPD<br>I: +20% DMG | (wiki) |
| Wolfsblood | V / D / I | any | V: +2 SPD ; -10% Max HP<br>D: +3 SPD ; -15% Max HP<br>I: +6 SPD | (wiki) |
| Heartseeker | V / D / I | any | V: +3% CRIT ; -10% Healing Received from Skills<br>D: +5% CRIT ; -15% Healing Received<br>I: +10% CRIT | (wiki) |
| Hale Draught | V / D / I | any | V: +10% Max HP ; -3% CRIT<br>D: +15% Max HP ; -5% CRIT<br>I: +20% Max HP | (wiki) |
| Protectorate | V / D / I | any | V: +10% Healing Given from Skills ; -10% DMG<br>D: +15% Healing Given ; -15% DMG<br>I: +20% Healing Given | (wiki) |
| Gilded Mind | V / D / I | any | V: +15% Stress RES ; +7% Deathblow RES ; -10% Debuff RES<br>D: +20% Stress RES ; +10% Deathblow RES ; -10% Debuff RES<br>I: +25% Stress RES ; +15% Deathblow RES | (wiki) |
| Anchoring Charm | V / D / I | any | V: +15% Move RES ; +10% Stun RES ; -10% Deathblow RES<br>D: +25% Move RES ; +20% Stun RES ; -10% Deathblow RES<br>I: +50% Move RES ; +25% Stun RES | **(wiki+data)** |
| Bouncer's Belt | V / D / I | any | [Armor] V: +15% Healing Received from Skills ; -15% Move RES<br>D: +20% Healing Received ; -15% Move RES<br>I: +25% Healing Received | (wiki) |
| Cleansing Censer | V / D / I | any | V: +15% Disease RES ; +10% Debuff RES ; -10% Stun RES<br>D: +25% Disease RES ; +15% Debuff RES ; -10% Stun RES<br>I: +50% Disease RES ; +20% Debuff RES | **(wiki+data)** |
| Clotting Cruor | V / D / I | any | V: +20% Bleed RES ; -10% Burn RES<br>D: +33% Bleed RES ; -10% Burn RES<br>I: +66% Bleed RES | (wiki) |
| Heat Shield | V / D / I | any | V: +20% Burn RES ; -10% Blight RES<br>D: +33% Burn RES ; -10% Blight RES<br>I: +66% Burn RES | (wiki) |
| Sacrificial Host | V / D / I | any | V: +20% Blight RES ; -10% Bleed RES<br>D: +33% Blight RES ; -10% Bleed RES<br>I: +66% Blight RES | **(wiki+data)** |

**Jan 2024 data values** for the same items. Data names: "Minor X" (Vague, 10 Baubles), "X" (Distant, 20), "Greater X" (Indelible, 50) **(data, loc)**:

| Name | Minor (Vague) | X (Distant) | Greater (Indelible) |
|---|---|---|---|
| Sharpness Charm | +10% DMG ; -1 SPD | +20% DMG ; -2 SPD | +30% DMG ; -3 SPD |
| Wolfsblood | +2 SPD ; +5% DMG ; -5% Max HP | +3 SPD ; +10% DMG ; -10% Max HP | +4 SPD ; +15% DMG ; -15% Max HP |
| Heartseeker | +10% CRIT ; -10% Healing Received | +20% CRIT ; -20% | +30% CRIT ; -30% |
| Hale Draught | +10% Max HP ; -5% CRIT | +20% ; -10% CRIT | +30% ; -15% CRIT |
| Protectorate | +15% Healing Given ; -5% DMG | +25% ; -10% DMG | +35% ; -10% DMG |
| Gilded Mind | +20% Stress RES ; +10% Deathblow RES | +30% ; +20% ; -1 SPD | +40% ; +30% ; -2 SPD |
| Anchoring Charm | as wiki | as wiki | as wiki |
| Bouncer's Belt | +10% Healing Received ; +10% Move RES ; -1 SPD | +20% ; +20% ; -2 SPD | +30% ; +30% ; -3 SPD |
| Cleansing Censer | as wiki | as wiki | as wiki |
| Clotting Cruor | +20% Bleed RES ; -10% Burn RES | +50% ; -10% | +66% ; Gain on Bleed resist: -1 Stress |
| Heat Shield | +50% Burn RES ; -20% Blight RES | +70% ; -10% | +70% ; Gain on Burn resist: -1 Stress |
| Sacrificial Host | as wiki | as wiki | as wiki |

#### Distant: Miscellaneous (13, 30 Baubles, any region)

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Adrenalizing Ash | Distant | any | Turn End: Speed (15%) ; Gain on Miss: Daze (20%) | **(wiki+data)** |
| Bulwark Band | Distant | any | Turn Start: Dodge (15%) ; Gain on Miss: Blind (15%) | **(wiki+data)** |
| Buttressing Band | Distant | any | Turn Start: Crit (10%) ; Gain on Miss: Vulnerable (20%) | **(wiki+data)** |
| Clandestine Cape | Distant | any | [Armor] Round Start: Stealth (15%) ; Gain on Miss: Vulnerable (15%) | **(wiki+data)** |
| Guarding Gauntlet | Distant | any | [Armor] Turn Start: Block (15%) ; Gain on Miss: Weak (15%) | **(wiki+data)** |
| Stirring Snuff | Distant | any | Turn Start: Strength (15%) ; Gain on Miss: Weak (20%) | **(wiki+data)** |
| Dead Ringer | Distant | any | Apply on Hit: Daze (15%) ; Apply on Miss: Speed (20%) | (wiki). Data: Daze **50%** |
| Disarming Dagger | Distant | any | [Weapon] Apply on Hit: Weak (15%) ; Apply on Miss: Strength (20%) | (wiki). Data: Weak **33%**, Strength **10%** |
| Distracting Dust | Distant | any | Apply on Hit: Blind (15%) ; Apply on Miss: Crit (15%) | (wiki). Data: Blind **50%** |
| Strange Sapper | Distant | any | [Weapon] Apply on Hit: Vulnerable (15%) ; Apply on Miss: Block (20%) | (wiki). Data: Vulnerable **50%** |
| Strong Shackles | Distant | any | Apply on Hit: Immobilize ; Gain on Hit: Immobilize | (wiki). Data: Apply on Hit: Immobilize x2 (66%) ; when an enemy misses the wearer: Stun on the wearer (5%) |
| Gnarly Knuckles | Distant | any | [Weapon, Serrated] Melee Skills: +20% DMG ; Gain on Miss: Melee Skills: +1 Stress | **(wiki+data)** |
| Raven's Reach | Distant | any | Ranged Skills: +20% DMG ; Gain on Miss: Ranged Skills: +1 Stress | **(wiki+data)** |

In the "Apply on Miss" lines above, the token goes on **the enemy the wearer missed**: the data hook is `on_miss_as_performer_to_target`, and the wiki uses the "Apply" prefix **(wiki+data)**. So Speed, Strength, Crit or Block there is the malus: a miss hands the enemy a positive token.

#### Distant: region trinkets (5, 30 Baubles, only in their region)

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Blistering Bugle | Distant | any (Tangle) | Turn Start: Taunt (50%) ; Turn Start: If First in Turn Order: Vulnerable (33%) | **(wiki+data)** |
| Stone Mount | Distant | any (Tangle) | Turn End: Convert Block to Block+ ; Gain on Miss: If First in Turn Order: +1 Stress | **(wiki+data)** |
| Unwavering Standard | Distant | any (Tangle) | Combat Start: All Allies Behind: Block ; Gain on Miss: If First in Turn Order: Weak | (wiki). Data: Combat Start: Each Hero incl. self: Block (66%) |
| Parrying Patriarch | Distant | any (Sprawl) | Turn End: Convert Dodge to Dodge+ ; Turn Start: If Speed <= 2: Weak (10%) | **(wiki+data)** |
| Seamen's Boots | Distant | any (Shroud) | [Armor] When Moving: If Speed <= 2: Block (66%) ; When Moving: If Speed >= 6: Dodge (66%) | **(wiki+data)** |

Region names on the wiki, with the data's names: Sluice = `cave`, Sprawl = `city`, Foetor = `farm`, Tangle = `forest`, Shroud = `coast` (its loot checks `shroud_biome_check`). Catacombs is the *Inhuman Bondage* DLC region and is not in the data **(wiki+data)**.

#### Indelible: region, Hoarder and boss trinkets (8)

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Calibrating Censer | Indelible (65, Tangle) | any | Gain on Miss: Strength ; Gain When Hit: If Speed <= 2: Block (66%) | **(wiki+data)** |
| Clenching Claws | Indelible (65, Tangle) | any | [Serrated] Apply to Attacker When Hit: Weak (20%) or Vulnerable (20%) or Stun (10%) ; Round Start: If Speed <= 2: Immobilize (66%) | **(wiki+data)**; "or" = apply limit 1 |
| Sparkleball | Indelible (65, Hoarder only) | any | Apply on Hit: Daze (15%), Blind (15%), Weak (15%), Vulnerable (15%), Immobilize (15%) | **(wiki+data)**; five independent rolls |
| Mortal Ward | Indelible (65, Hoarder only) | any | On Entering Death's Door: Crit, Dodge+, -2 Stress ; On Leaving Death's Door: Crit, Dodge+, -2 Stress | (wiki+patch v2.02 added the "Leaving" line; the data has "Entering" only) |
| Footman's Grog | Indelible (boss: Dreaming General) | any | Each Hero on Turn Start: Convert Vulnerable to Block ; Each Hero on Turn Start: Convert Weak to Strength | **(wiki+data)**; converts all (amount 99) |
| Reverberating Redoubt | Indelible (boss: Dreaming General) | any | [Armor] Apply to Attacker When Hit: 2 DMG ; Gain When Hit: If Speed <= 2: Extra Action (20%) | **(wiki+data)** |
| Kitchen Knives | Indelible (boss: Harvest Child) | any | [Weapon, Noxious] If Target has Blight: +15% CRIT ; Gain on CRIT: Heal 2 ; Gain on Blight Resist: Extra Action (20%) | **(wiki+data)** |
| Carved Bodkin | Indelible (boss: Leviathan) | any | Turn Start: If Bleed: Extra Action (20%) ; -2 Bleed Received | **(wiki+data)** |

#### Ancestral (1)

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Ancestor's Coat | Ancestral (enemy: Ancient Adversary) | any | [Armor] -15% DMG Taken ; -2 DoT Duration Received ; +100% Horror Received | (wiki); not in the data |

#### Unforgettable (3)

| Name | Rarity | Hero | Effects | Source |
|---|---|---|---|---|
| Dark Impulse (Stun Resist variant) | Unforgettable (Stained) | any | +25% Stun RES ; If Stun token: +50% DMG Taken | **(wiki+data)**. Item tag `stained`. Its "quote" text reads "Unlocks the potential of Cultist Trinkets" **(loc)**. There are 9 variants (Bleed, Blight, Burn, Move, Disease, Debuff, Stun, Stress, Healing), each one resist bonus plus one malus. |
| Wounding Words | Unforgettable (Cultist) | any, needs a Stained item | +50% DMG ; -33% Max HP | (wiki). Data: +30% DMG ; -15% Max HP (conflict) |
| Silent Treatment | Unforgettable (Cultist) | any, needs a Stained item | Round Start: Stealth (50%) or Stealth x2 (20%) ; If Stealth: +50% CRIT ; If no Stealth: +50% DMG Received | **(wiki+data)** |

### 3.3 Set and pair bonuses

- **Gelatinous Secretion + Slimemulet** *(Catacombs, Inhuman Bondage DLC; Indelible)* is the only pair. Each carries a line that is active only when the other is worn **(wiki)**:
  - **Gelatinous Secretion:** +33% Debuff RES Piercing ; Turn Start: If Last In Turn Order: Add 2 Positive Tokens ; **If Slimemulet item is equipped: Apply On Hit: Slimed (66%)** ; Gain When Hit: Disease "The Goops" (5%).
  - **Slimemulet:** +20% Debuff RES ; Turn End: If Last In Turn Order: Regeneration 4 ; **If Gelatinous Secretion item is equipped: Apply to Attacker When Hit: Slimed** ; Gain When Hit: Slimed (5%).
  - The bold line is the pair line. The last line of each reads as an always-on malus (inferred from the line order in the wiki summary). *Slimed* is a DLC status that is not covered here.
- **No set system in the data.** `trinket_set_data_export` holds only `test_cave_trinket_set` **(data)**.
- **Tag synergies work like soft pairs.** Many trinkets check another equipped item's tag:
  - Armory Key (Armor / Weapon);
  - Smoldering Firewood and Tinderbox (Flammable);
  - Early Experiment and Poison Ring (Noxious);
  - Fishmonger's Gloves and Fisherman's Line (Serrated);
  - Annotated Textbook (Restorative).

  Cultist trinkets also require a Stained (Dark Impulse) item **(wiki+data)**.

---

## Conflicts and unconfirmed points

1. **Varying trinket numbers.** The current wiki values (3.2) differ from the Jan 2024 data almost everywhere. Examples: Heartseeker +3/5/10% vs +10/20/30% CRIT; the Indelible tier has no malus on the wiki. **No patch note** found in the wiki-mirrored notes (Infernal Pursuits through Steadfast Stewards 2) or the 2026 Steam hotfix posts explains this. v2.02 also says "All downsides on Distant stat trinkets now match the values of Vague versions". The wiki follows that for 7 items but not for Sharpness Charm, Wolfsblood, Heartseeker, Hale Draught and Protectorate. The values in game today are **unconfirmed**; trust the wiki for the shape (3 tiers, Indelible with no malus) and treat the exact numbers as approximate.
2. **Miscellaneous on-hit chances.** Dead Ringer, Disarming Dagger, Distracting Dust and Strange Sapper are 15% on the wiki but 33–50% in the data. Strong Shackles is redesigned. **No patch note found.**
3. **Vague price.** 5 Baubles since Kingdoms (patch); 10 in the data.
4. **Hero trinkets.** Most of our cast's trinkets were reworked after the data (see the version caveat), so the wiki is the only current source. The Crusader's effects are not in the data at all. His Prison (third line) and Searing Scripture (skill gate) differ from the data with no patch note found.
5. **Severed Finger**: "If Bleed" could mean the Jester or the target. **Storage Room Key**: which items count as "Medicinal Gear" is unconfirmed.
6. **"Applied effect" durations.** Most token and DoT lines give no duration; tokens follow the normal token rules in [darkest-dungeon-combat.md](darkest-dungeon-combat.md). Buff-type lines without a stated duration (e.g. Signed Indenture's "+20% Debuff RES") are **unconfirmed**.
7. **Sell values**: not published; only "a small fraction" / "a small amount of relics".
8. **Ancestral rarity**: colour, price and drop rate are unconfirmed.
9. **Loot weights and shop slot counts** are Jan 2024 data. The Inn shop selection was enlarged in Feb 2024, with unknown numbers. The Hoarder's Vague slots change in late regions since v2.02.
10. **Two trinkets per hero** comes from fextralife quoting the game text (an older source). The "no duplicates" rule is read from data fields plus patch wording.
11. **"X or Y" selection.** How one option is picked under an apply limit of 1 (in order, or shuffled) is unconfirmed.
12. **Data cost 1000** is read as "not sold" (inferred: it is used for every boss, enemy, curio and Cultist trinket and is far above any real price).

---

## Sources

### DD2: data (primary, data-mined)
- [D-WB] DD2 `StreamingAssets/Excel` CSV exports, mirrored in a mod repo (Jan 2024 data): https://github.com/woodbrick/darkest-dungeon-2
  - Files used: `trinkets_data_export.Group.csv`, `trinkets_actor_effect_trigger_data_export.Group.csv`, `trinket_set_data_export.Group.csv`, `buff_data_export.Group.csv`, `effect_data_export.Group.csv`, `condition_data_export.Group.csv`, `item_subtype_data_export.Group.csv`, `token_data_export.Group.csv`, `loot_data_export_TRINKETS.Group.csv`, `loot_data_export_COMBATS.Group.csv`, `loot_data_export_NODESandROAD.Group.csv`, `loot_data_export_INN_REWARDS.Group.csv`, `loot_data_export_MISC.Group.csv`, `dlc_dul_cru/trinkets_data_export_DLC1.Group.csv`, `dlc_dul_cru/trinkets_actor_effect_trigger_data_export_DLC1.Group.csv`, `dlc_dul_cru/dlc1_buff_data_export.Group.csv`, `dlc_dul_cru/dlc1_effect_data_export.Group.csv`, `dlc_dul_cru/dlc1_condition_data_export.Group.csv`, `dlc_dul_cru/loot_data_export_DLC1.Group.csv`
- [D-LOC] DD2 English source strings in a Persian translation repo (uploaded 2023-08-26): https://github.com/ParsiSaz/DarkestDungeon-2---Persian, files `Sources/trinkets.txt` (trinket names), `Sources/items.txt` (rarity names, currency names), `Sources/colors.txt` (rarity colours)

### DD2: wikis
- [W-TR2] https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon_II)
- [W-HOARD] https://darkestdungeon.wiki.gg/wiki/Hoarder
- [W-AOH] https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope
- [W-AOH-LC] https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope/The_Living_City (hero tracks and candle totals)
- [W-AOH-WF] https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope/The_Working_Fields (trinket unlock tiers, stagecoach trinket items)
- [W-PATCH] https://darkestdungeon.wiki.gg/wiki/Patch_notes_(Darkest_Dungeon_II) (patch index)
- [FX-TR] https://darkestdungeon2.wiki.fextralife.com/Trinkets (equip limit quote; last edited 10 Nov 2023)

### DD2: official patch notes (Red Hook, mirrored on wiki.gg)
- [P-2023-09-14] https://darkestdungeon.wiki.gg/wiki/14_September_2023_Patch (Execution 1 on Covert Cloak, Staggering Striker, Dismas's Head, Vengeful Kill List)
- [P-2023-12-05] https://darkestdungeon.wiki.gg/wiki/December_5_2023_Patch (trinket possession limit fixes)
- [P-2024-02] https://darkestdungeon.wiki.gg/wiki/Infernal_Pursuits_Retail (Grave Robber and Highwayman trinket reworks; larger Inn trinket shop)
- [P-2024-04] https://darkestdungeon.wiki.gg/wiki/Last_Light (hero goals reward hero trinkets; Rat Skull, Profane Scroll and curio trinket tweaks)
- [P-2024-08] https://darkestdungeon.wiki.gg/wiki/Darkside_Of_The_Mountain (Man-at-Arms, Jester and Vestal trinket reworks)
- [P-2025-01] https://darkestdungeon.wiki.gg/wiki/Kingdoms_Release (Vague 10 → 5 Baubles)
- [P-2025-04] https://darkestdungeon.wiki.gg/wiki/Secrets_Of_The_Coven_Release (no trinket changes)
- [P-2025-07] https://darkestdungeon.wiki.gg/wiki/Steadfast_Stewards_Retail_Release (v2.02: Plague Doctor, Occultist and Runaway trinket reworks; Ancestral rarity; Distant downsides; Hoarder Vague swap; selling via The Dam; hero-goal trinkets)
- [P-2025-SS2] https://darkestdungeon.wiki.gg/wiki/Steadfast_Stewards_2_Retail_Release (v2.04: Hellion and Leper item reworks; Cultist equip-condition text)
- [P-OFF] https://www.darkestdungeon.com/patch-notes/ (v2.04.80601 console notes, 18 Nov 2025)
- [STEAM] Steam news feed for app 1940340: https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=1940340 (2026 hotfixes 2.04.83880, 2.04.83892, 2.04.84350 and 2.04.85095 contain no trinket lines)

### Project docs
- [darkest-dungeon-combat.md](darkest-dungeon-combat.md): tokens, DoTs, Execution, Guard, Death's Door.
- [darkest-dungeon-1-trinkets.md](darkest-dungeon-1-trinkets.md): the DD1 counterpart.
