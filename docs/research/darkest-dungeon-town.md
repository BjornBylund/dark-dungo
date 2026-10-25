# Darkest Dungeon 1 town and campaign loop: implementation reference

Researched on 2026-10-25 for the Godot project `darko-dungo`. The combat already mirrors Darkest Dungeon II (see [darkest-dungeon-combat.md](darkest-dungeon-combat.md)). This document covers **Darkest Dungeon 1 (DD1, 2016)**: the Hamlet, roster, weeks, missions, progression and economy. It ends with implementation notes for this project.

## How to read this document

Every claim is tagged with its source:

| Tag | Meaning |
|---|---|
| **(wiki)** | darkestdungeon.wiki.gg, the maintained wiki. It reflects the current game (v1.x with DLC). **Default "truth"** where it gives a number. |
| **(data)** | DD1's own JSON/text data files, as copied into the open-source Unity re-implementation by Reinisch [D-U]. These are real game files, but see the version caveat below. |
| **(patch)** | Red Hook patch notes, as mirrored on the wiki. Authoritative for *changes*. |
| **(community)** | Steam discussions and player guides. Anecdotal. |
| **(inferred)** | My own reading or arithmetic. Treat as a design suggestion, not fact. |

**Conflict** marks places where sources disagree; both values are given. **Unconfirmed** marks things no source states.

> **Version caveat for (data).** The data snapshot [D-U] is from 2016, *before* the 9 Feb 2017 economy patch. Weapon upgrade costs in it are 750/2000/4000/8000. That patch cut them to 750/1750/3000/6000 in Darkest mode; the old values survive only in Stygian. Its Abbey and Tavern side-effect chances (40/35/30%) also predate the current 37.5%. The data also disagrees with the March 2016 roster sizes (see 2.2). It may also have been edited by the port's author. Use the data for **structure and magnitudes** (quest reward tables, loot weights, generation rules), and the wiki for **current numbers** where both exist.

> **Source access.** wiki.gg loaded fine through WebFetch, so the fandom fallback was not needed. (Fandom returned HTTP 402 anyway.) The official modding guide (Steam guide 819597757) returned HTTP 429 on every attempt, so it was **not** consulted. Its role as the data-file reference was filled by the Unity port's copies of the game files.

> **Scale note.** DD1 stress runs 0–200: affliction or virtue at 100, heart attack at 200. This project uses DD2's 0–10. Divide DD1 stress numbers by 10 to compare (inferred).

---

## TL;DR: the numbers you will most likely need

```
Week            = one expedition (success, abandon or wipe). On return: XP, quirks, then week ticks:
                  town activities resolve, idle heroes -5 stress, new recruits, new wagon stock,
                  new quest board, maybe a town event.                         (wiki/data/community)
Roster cap      = 9 base -> 12/16/20/24/28 (Hero Barracks, Deeds+Crests)               (patch/wiki)
Recruits/week   = 2 base -> 3/4/5/6/7 (Stage Coach Network). Free to hire.             (data/wiki)
Resolve XP      = level 1..6 at 2/8/14/24/36/48 total XP                               (wiki+data)
Quest XP        = short/medium/long: 2/3/4 Apprentice, 4/6/8 Veteran, 8/12/16 Champion (wiki+data)
Eligibility     = refuses if hero level >= quest level + 2 (Apprentice=1, Veteran=3, Champion=5)
Underleveled    = +20 stress on entry and +25% stress taken, per level below           (wiki)
Quest gold      = Apprentice 3000/4500/7500, Veteran 4500/6750/11250, Champion 6000/9000/15000 (data, 2016)
Stress relief   = 45/55/65 stress for 1000/1250/1500 gold (Apprentice tier; x1.4 Veteran, x1.8 Champion);
                  37.5% side-effect chance per visit; 1 slot per activity -> 2 -> 3   (wiki/data)
Blacksmith      = rank 2/3/4/5 cost 750/1750/3000/6000; needs hero level 1/2/3/5 and Blacksmith level 1-4 (wiki)
Guild           = skill rank 2/3/4/5 cost 250/750/1250/2500; new skill 1000; same level gates (wiki)
Provisions      = Food 75, Torch 75, Shovel 250, Bandage/Antivenom/Holy Water 150, Herbs/Key 200, Laudanum 100 (wiki)
Retreat         = battle retreat 70% (+5%/try), 25 stress; abandon quest: 20 stress, keep loot,
                  lose reward and XP                                                    (wiki)
```

---

## 1. The Hamlet

### 1.1 Buildings at a glance

| Building | What it does | Heirlooms for upgrades | Unlocks after (data, 2016) |
|---|---|---|---|
| **Stage Coach** | Free hero recruits each week. Roster cap (Hero Barracks). Recruit quality (Experienced Recruits). | Deeds + Crests (Network, Barracks); Busts + Crests (Experienced Recruits) (wiki) | Start of campaign (0 quests) |
| **Abbey** | Stress relief: Meditation, Prayer, Flagellation. Safer than the Tavern. | Busts + Crests (wiki) | 2 quests finished |
| **Tavern** | Stress relief: Bar, Gambling, Brothel. More variance. | Portraits + Crests (wiki) | 2 quests finished |
| **Blacksmith** | Weapon and armour ranks 2–5 for gold. | Deeds + Crests (wiki) | 3 quests finished |
| **Guild** | Skill ranks 2–5 and learning new combat skills, for gold. | Portraits + Crests (wiki) | 3 quests finished |
| **Sanitarium** | Remove negative quirks, lock positive quirks, cure diseases. | Busts + Crests (wiki) | 4 quests finished |
| **Nomad Wagon** | Sells a weekly stock of trinkets. Trinkets can be sold back (from the trinket inventory). | Crests only (wiki) | Highest region level 2 (data) |
| **Survivalist** | Teaches extra camping skills. | Crests only (wiki) | Region progression level 2, i.e. when a region's first boss appears (wiki + data) |
| **Graveyard** | Log of every dead hero: name, level, class, cause and time of death. Headstone art varies by level. No upgrades. (wiki) | none | always |
| **Ancestor's Memoirs** | Lore journal. Entries unlock by slaying bosses and finding journal pages. No upgrades. (wiki) | none | after first boss |
| **"Barracks"** | Not a building. *Hero Barracks* is the Stage Coach's roster-size upgrade line. The roster itself is the panel on the Hamlet screen. (wiki) | — | — |
| **Heirloom Exchange** | Trades heirloom types at a loss (see 8.4). Added in the 8 March 2016 patch. (patch) | — | — |
| Districts (*Crimson Court* DLC) | Passive bonuses built with Blueprints. Out of scope here. (wiki) | Blueprints + others | — |

- The unlock column uses the data's `number_of_quests_finished` / `highest_dungeon_level` fields. The Old Road tutorial counts as quest 1 (inferred). A wiki beginner page gives the same order by week: week 1 Stage Coach; week 2 Abbey and Tavern; week 3 Blacksmith and Guild; week 4 Nomad Wagon, Sanitarium and Survivalist. That page flags itself as unreliable, though. (wiki "Getting Started")
- **Conflict:** The Nomad Wagon is week 4 on the beginner page but "region level 2" in the data. Treat it as "early, after a little progress".
- Every upgrade costs more heirlooms than the one before. Every building uses Crests. (wiki)

### 1.2 Stage Coach

Three upgrade lines. All costs are from the wiki.

**Stage Coach Network: recruits offered per week**

| Level | Recruits per week | Cost |
|---|---|---|
| 0 | 2 (data) | — |
| 1 | 3 | 3 Deeds, 4 Crests |
| 2 | 4 | 8 Deeds, 10 Crests |
| 3 | 5 | 16 Deeds, 15 Crests |
| 4 | 6 | 20 Deeds, 20 Crests |
| 5 | 7 | 25 Deeds, 26 Crests |

**Hero Barracks: roster cap**

| Level | Roster cap | Cost |
|---|---|---|
| 0 | 9 (patch Mar 2016) | — |
| 1 | 12 | 3 Deeds, 4 Crests |
| 2 | 16 | 8 Deeds, 10 Crests |
| 3 | 20 (21 Radiant) | 16 Deeds, 15 Crests |
| 4 | 24 (25 Radiant) | 20 Deeds, 20 Crests |
| 5 | 28 (29 Radiant) | 25 Deeds, 26 Crests |

- The Shieldbreaker, Duelist and Runaway DLC heroes each add 1 slot, for a maximum of 31 (33 Radiant). (wiki)
- **Conflict:** The 2016 data snapshot has 12/15/18/21/25. The 8 March 2016 patch notes say "Roster Size Increase: 9/12/16/20/24/28", which the wiki matches. Use 9→28.

**Experienced Recruits: chance of higher-level recruits**

| Level | Effect | Cost |
|---|---|---|
| 1 | 18.75% chance of level 1 recruits | 9 Busts, 12 Crests |
| 2 | 12.5% chance of level 2 recruits | 12 Busts, 16 Crests |
| 3 | 6.25% chance of level 3 recruits | 15 Busts, 20 Crests |
| 4 (Radiant only) | 3.12% chance of level 4 recruits | 18 Busts, 24 Crests |

- **Prerequisites (conflict).** The wiki says each level requires the Guild skill-cap upgrade and both Blacksmith smithing lines "at the same level", then gives the example "level 1 requires level 2 of each". The Feb 2017 patch says Level 1 Experienced Recruits "now require only a Level 1 Blacksmith and Guild". The Game Modes page lists that change under Radiant. Inferred rule: Experienced Recruit level N needs Blacksmith and Guild level ≥ N.
- In the data, each level is an entry with `level`, `chance`, extra positive and negative quirks (+1/+2/+3), extra combat skills (0/1/2), extra camping skills (1/1/2) and `guaranteed_previous_raid_dead_hero_levels` ([3], [4], [5,6]). (data) How the chance is rolled is **unconfirmed**: per recruit slot, highest level first, is my guess. The "guaranteed" field probably guarantees a replacement recruit of that level after a hero of the listed level died on the previous raid (inferred).

### 1.3 Abbey (Busts + Crests)

Three independent tracks: **Cloister** (Meditation), **Transept** (Prayer) and **Penance Hall** (Flagellation). All three have the same upgrade ladder and costs. (wiki)

| Level | Effect | Busts | Crests |
|---|---|---|---|
| 1 | Stress relief up (tier 1) | 4 | 5 |
| 2 | Cost −15% of base | 8 | 10 |
| 3 | Slots 1 → 2 | 11 | 14 |
| 4 | Stress relief up (tier 2) | 15 | 19 |
| 5 | Cost −15% of base again | 19 | 24 |
| 6 | Slots 2 → 3 | 23 | 29 |

- **Base slots: 1 per activity** (data: `slots` base 1, then 2, then 3). The wiki only says "increases slots to 2" and "to 3".
- **Conflict:** The wiki's Heirlooms summary gives a total of 282 Crests for the Abbey, but the ladder above sums to 3 × 101 = 303. The summary probably predates the March 2016 patch, which raised Crest costs by 25%. Use the per-building ladder.

Activity numbers are in section 4.

### 1.4 Tavern (Portraits + Crests)

Three tracks: **Bar**, **Gambling Hall** and **Brothel**. Same ladder shape as the Abbey. (wiki)

| Level | Effect | Portraits | Crests |
|---|---|---|---|
| 1 | Stress relief up | 2 | 5 |
| 2 | Cost −15% | 4 | 10 |
| 3 | Slots 1 → 2 | 6 | 14 |
| 4 | Stress relief up | 8 | 19 |
| 5 | Cost −15% | 10 | 24 |
| 6 | Slots 2 → 3 | 11 | 29 |

Base slots are 1 (data). The same 240-vs-303 Crest discrepancy exists in the wiki's Heirlooms summary.

### 1.5 Blacksmith (Deeds + Crests)

**Weaponsmithing** and **Armorsmithing** are separate lines with identical costs. Each Blacksmith level raises the maximum rank you can buy. (wiki)

| Blacksmith level | Max weapon or armour rank | Hero level needed for that rank | Deeds | Crests |
|---|---|---|---|---|
| 0 | 1 (starting gear) | — | — | — |
| 1 | 2 | 1 | 8 | 8 |
| 2 | 3 | 2 | 20 | 21 |
| 3 | 4 | 3 | 32 | 35 |
| 4 | 5 | 5 | 44 | 49 |

**Furnace / equipment discount** line: 5 levels, each −10% on weapon and armour gold costs (stacking to −50%). Costs: 4D/4C, 9D/10C, 14D/15C, 18D/20C, 24D/26C. (wiki; the data confirms 5 × 0.10 discounts)

Gold costs per rank are in section 6.

### 1.6 Guild (Portraits + Crests)

| Line | Level | Effect | Portraits | Crests |
|---|---|---|---|---|
| Instructor Mastery (skill cap) | 1 | Skill rank 2 (hero level 1+) | 6 | 14 |
| | 2 | Rank 3 (level 2+) | 15 | 38 |
| | 3 | Rank 4 (level 3+) | 24 | 60 |
| | 4 | Rank 5 (level 5+) | 33 | 84 |
| Training Regimen (discount) | 1–5 | −10% skill costs each (−50% max) | 2 / 5 / 8 / 11 / 14 | 6 / 14 / 21 / 29 / 36 |

(wiki; these totals match the wiki's Heirlooms summary: 118 Portraits, 302 Crests)

### 1.7 Sanitarium (Busts + Crests)

The Sanitarium has two treatment types: **quirk treatment** (remove a negative quirk, lock or remove a positive one) and **disease treatment**.

| Line | Level | Effect | Busts | Crests |
|---|---|---|---|---|
| Treatment Library (quirk cost) | 1–5 | −10% quirk treatment cost each | 3 / 8 / 12 / 16 / 21 | 3 / 5 / 8 / 10 / 13 |
| Medical Devices (disease) | 1 | −13% disease cost | 3 | 3 |
| | 2 | Chance to cure *all* diseases: 33% → 67% (data) | 8 | 5 |
| | 3 | −13% disease cost | 12 | 8 |
| | 4 | Cure-all chance → 100% (data) | 16 | 10 |
| | 5 | −13% disease cost | 21 | 13 |
| Patient Cells (slots) | 1 | Disease slots 1 → 2 | 10 | 6 |
| | 2 | Quirk slots 1 → 2 | 20 | 13 |
| | 3 | Disease slots 2 → 3 | 30 | 19 |
| | 4 | Quirk slots 2 → 3 | 60 | 38 |

- Costs are from the wiki.
- The wiki says only "medical ward" and "treatment ward" for the slot lines. Which is which comes from the data's upgrade codes (disease slots on a/c, quirk slots on b/d), so the mapping is inferred.
- The cure-all percentages come from the data; the wiki says only "increases chance of curing extra diseases".
- Treatment always succeeds (data: `quirk_treatment_chance 1.0`).

Treatment prices and rules are in section 9.

### 1.8 Survivalist (Crests only)

- A camping skill costs **1,750 gold** to learn. (wiki)
- The single upgrade line gives −10% per level: 15 / 35 / 54 / 72 / 92 Crests, bringing the price to 1575 / 1400 / 1225 / 1050 / 875. (wiki; data confirms 5 × 0.10)

### 1.9 Nomad Wagon (Crests only)

| Line | Level | Effect | Crests |
|---|---|---|---|
| Wagon Size | 0 | 2 trinkets per week (data) | — |
| | 1–4 | 4 / 6 / 8 / 12 trinkets per week | 10 / 26 / 42 / 58 |
| Merchant Network | 1–5 | −10% buy price each (−50% max) | 8 / 18 / 28 / 38 / 46 |

**Prices and stock odds** (wiki):

| Rarity | Base buy price | Stock spawn chance | Sell value |
|---|---|---|---|
| Very Common | 5,000 | 33% | 750 |
| Common | 7,500 | 28% | 1,125 |
| Uncommon | 10,000 | 22% | 1,500 |
| Rare | 15,000 | 11% | 2,250 |
| Very Rare | 25,000 | 6% | 3,750 |

- Sell value is 15% of the buy price (inferred from the wiki's two tables).
- Stock refreshes every week. (wiki)
- The Feb 2017 patch made Rare trinkets less common in the wagon. (patch)
- The *Nomad New Year* town event halves prices. (wiki)

### 1.10 Total heirlooms to max everything (base game, no DLC)

534 Busts, 241 Portraits, 421 Deeds and 2,042 Crests. (wiki Heirlooms summary) Because of the Abbey and Tavern discrepancy above, the true Crest total is probably about 84 higher (inferred).

---

## 2. Roster

### 2.1 Starting roster

- The campaign opens with **Reynauld** (Crusader) and **Dismas** (Highwayman), both level 0, on *The Old Road* tutorial. Their skills and quirks are fixed: Reynauld has Kleptomaniac, God Fearing and Warrior of Light; Dismas has Known Cheat, Hard Noggin and Quick Reflexes. Each has 4 skills. (wiki)
- The Old Road has two rooms joined by one corridor, with two fights. Completing it gives **5,000 gold** plus loot. (wiki) No separate starting gold is documented, so the Old Road reward is effectively the starting bankroll (inferred).
- On reaching the Hamlet, the Stage Coach holds a **Plague Doctor and a Vestal** with random skills and quirks. If a starter died, random heroes arrive to fill a party of four. (wiki)

### 2.2 Roster cap

- **9** heroes at the start, raised by Hero Barracks to 12/16/20/24/28 (section 1.2). (patch/wiki)
- Heroes marked by finishing a Darkest Dungeon run ("Never Again") do not count toward the cap. (wiki)
- Community advice for a full campaign is a roster of 16–24. (community)

### 2.3 Stage Coach recruits

- **Pool size per week:** 2 base, then 3/4/5/6/7 with Network upgrades. (data/wiki)
- **Backup recruits:** "Regardless of the upgrade level, there will always be enough recruits to go on an expedition". With 1 hero on the roster, 3 recruits are offered. (wiki) Backup recruits are capped at 4. (patch 25 Jun 2018)
- **Refresh:** a new, different set arrives every week. (wiki) Unhired recruits from the previous week disappear (inferred from "new and different recruits each week"). Network upgrades take effect "after you return from your next quest". (wiki)
- **Cost:** hiring is free, which is why running out of gold is never a game over. (wiki)
- **Class selection:** random from the unlocked classes (15 in the base game). Since the Feb 2017 patch there is an optional deck-based population that favours healers; it can be toggled off in Options. (wiki/patch)
- **What a level 0 recruit gets:**
  - 1–2 positive and 1–2 negative quirks (data `generation`, matched by the wiki).
  - **4 random combat skills** out of the class's 7 (data: `number_of_random_combat_skills 4`).
  - **3 camping skills:** 2 class-specific and 1 shared (data; the wiki also says 3).
  - Rank 1 weapon and armour.
- **What a higher-level recruit gets:** maxed weapon, armour and skill ranks for its level, plus 1 more quirk min and max per level. (wiki)
- **Conflict:** The wiki says level 1+ recruits have all combat skills unlocked. The 2016 data gives level 1/2/3 recruits only +0/+1/+2 extra skills.

### 2.4 Dismissing heroes

- Any hero in town can be dismissed. It is permanent: the hero is gone. The narrator comments ("Those without the stomach for this place must move on."). There is an achievement for the first dismissal. (wiki)
- Backer heroes can be dismissed and re-claimed later, even in the same week. (wiki)
- A hero must be dismissed to make room if the roster is full and you want to hire or revive someone. (wiki)
- **Unconfirmed:** what happens to a dismissed hero's equipped trinkets. Returning them to the trinket inventory is the sensible default (inferred).

### 2.5 Hero names

- Names are drawn at random from a localised name list (data: `name_id_format "hero_name_%d"`).
- Heroes can be renamed in town. The 28 May 2015 patch fixed activity-log names "when heroes are renamed", so renaming existed by then. (patch) Backer heroes cannot be renamed. (wiki)
- Pool size is **unconfirmed**.

### 2.6 Graveyard and revival

The Graveyard records every death (section 1.1). The *From Beyond* town event offers 3 random dead heroes, once at least 3 heroes are buried. You revive one. The hero keeps its level and quirks, but skills and gear reset. (wiki)

---

## 3. Weeks

### 3.1 What advances a week

**One expedition is one week**, whether completed, abandoned, or ended by a party wipe. (community [GLS]; consistent with the wiki's "results are applied after your next quest")

DD1 has no "end week" button. **Unconfirmed:** some players say you can deliberately skip a week. Embarking and immediately abandoning would do it, but costs 20 stress per hero (inferred). The Farmstead (DLC) reportedly does not advance the week. (community)

### 3.2 What happens on return (inferred order)

1. **Expedition results.** Resolve XP, level-ups, end-of-quest quirk and disease rolls (section 9), lost and gained trinkets, loot banked. (wiki)
2. **Week ticks:**
   - Heroes in Abbey, Tavern or Sanitarium slots finish their treatment and become available again, unless a side effect keeps them another week. (wiki)
   - "Missing" heroes count down 1–2 weeks. (wiki)
   - **Idle heroes** recover **5 stress** per week (10 in Radiant, 15 with the Puppet Theatre district). (wiki + data `idle_hero_stress_heal 5.0`)
   - The Stage Coach gets a new set of recruits. (wiki)
   - The Nomad Wagon gets new stock. (wiki)
   - The quest board is regenerated with new random rewards. Quitting and reloading does not reroll it. (wiki)
   - A town event may be drawn (3.4).
3. Heroes return with **full HP**. Stress carries over; the wiki says "Unlike combat damage, it is not fully healed when a mission ends". The wiki also says stress is capped at 100 on return; **unconfirmed** elsewhere.

### 3.3 Availability rules

- A hero placed in a town activity (any Abbey or Tavern activity, or Sanitarium treatment) is **busy for that week and cannot be picked for the next expedition**. The result applies when that expedition returns. (wiki: activities "require holding the hero in town for a week"; Getting Started)
- One activity per hero per week. The wiki states it directly for the Sanitarium: a hero in disease treatment cannot also have quirks treated that week. It is inferred for stress relief.
- Side effects can extend this:
  - **"Refuses to leave / stays another week":** an extra locked week (data `activity_lock`).
  - **"Goes missing":** absent 1 week (75% of missing results) or 2 weeks (25%) (data weights 3:1; matches the wiki percentages).
- Taking a hero out of a slot before embarking presumably refunds the fee. **Unconfirmed** (inferred from the UI's remove button [community]).
- **Quirk-driven refusals:** some quirks restrict which activities a hero accepts (section 4.3). Heroes above the quest's level refuse to embark (section 5.4).

### 3.4 Town events (brief)

- After a return there is a chance of one themed event, drawn like a card. Frequency is an option: Off / Normal / Plentiful. (wiki)
- Data: `event_chance_per_town_visits` is Normal `[0.33, 0.67, 0.75, 1.0]` and Plentiful `[0.67, 0.67, 0.80, 1.0]`. My reading (inferred): the chance escalates with each event-less return, guaranteeing an event on the 4th.
- Each event has a `base_chance` weight, a `cooldown` in weeks, a `minimum_week`, and sometimes roster conditions. Example: "dead_recruit" needs 3 dead heroes and week 15+. (data)
- **Types** (wiki):
  - Free or discounted services: free Abbey, Tavern or Sanitarium; free weapon or armour upgrade; half-price trinkets.
  - A locked activity with the others in that building at −50%.
  - Extra recruits of a class: "Call of the Crusade" +2 Crusaders; "A Day Long Awaited" +6 recruits.
  - Idle heroes of a class gain +1 level.
  - Next-quest buffs or debuffs: provisions −50% or −100% cost; +33% XP and +15% damage in one region; level restrictions lifted ("Helping Hand").
  - Plot events, such as the Shrieker stealing 8 trinkets, or the Vvulf incursion (not before week 40 since 2017 [patch]).
- **Gather and Activate quests guarantee a matching event** on success. Examples: Ruins Gather → "All Saints Day" (free Abbey); Weald Gather → free Sanitarium; Cove Gather → free weapon upgrade; Warrens Gather → free provisions. All Activate quests → +33% XP and +15% damage in that region next week. (wiki + data `quest_type_event_guarantees`)

---

## 4. Stress relief

### 4.1 Activities

All values on DD1's 0–200 stress scale. Costs are for Apprentice-tier heroes (levels 0–2); Veteran (3–4) pays ×1.4 and Champion (5–6) ×1.8. Every activity has 1 / 2 / 3 slots (base / L3 / L6).

| Building | Activity | Stress removed (base / L1 / L4) | Gold: Apprentice (base / L2 / L5) | Veteran base | Champion base |
|---|---|---|---|---|---|
| Abbey | Meditation (Cloister) | 45 / 56 / 70 | 1000 / 850 / 700 | 1400 | 1800 |
| Abbey | Prayer (Transept) | 55 / 69 / 86 | 1250 / 1050 / 900 | 1750 | 2250 |
| Abbey | Flagellation (Penance Hall) | 65 / 81 / 100 | 1500 / 1300 / 1100 | 2100 | 2700 |
| Tavern | Bar | 45 / 56 / 70 | 1000 / 850 / 700 | 1400 | 1800 |
| Tavern | Gambling Hall | 55 / 69 / 86 | 1250 / 1050 / 900 | 1750 | 2250 |
| Tavern | Brothel | 65 / 81 / 100 | 1500 / 1300 / 1110* | 2100 | 2700 |

(wiki; base values match the data)

- *The wiki gives 1,110 for the Brothel but 1,100 for Flagellation. The data says 1,100. Probably a wiki typo.
- Any stress-relief activity also **cures an affliction** (data: `affliction_cure_chance 1.0`; wiki).
- Town events can change stress relief: +33% ("A Ray of Sunlight"), +200% for idle heroes ("One Good Week"), "less effective" ("The Miserable Dark"). (wiki)

### 4.2 Side effects

Every visit has a **37.5% chance** of one side effect (wiki). **Conflict:** the 2016 data has 40% / 35% / 30% for the cheap / middle / expensive activity of each building; the Feb 2017 patch "rebalanced" these. Percentages below are the wiki's absolute chances per visit.

| Activity | Positive | Negative and neutral |
|---|---|---|
| Meditation | Balanced quirk 3.75%; Meditator quirk 3.75% | Enlightened quirk 7.5%; Unquiet Mind quirk 7.5%; Calm quirk 3.75%; stays 1 extra week 3.75%; missing 1 wk 5.6% / 2 wk 1.9% |
| Prayer | −20% stress ("Filled with hope") 6.8%; gains a trinket 3.4% | God Fearing quirk 6.8%; Witness quirk 6.8%; stays 1 extra week 6.8%; **loses 1,000 gold** 3.4%; missing 1 wk 2.6% / 2 wk 0.9% |
| Flagellation | +20% damage buff 9.4% | stays 1 extra week 9.4%; Faithless 4.7%; Flagellant 4.7%; −25% Bleed resist 4.7%; missing 1 wk 3.5% / 2 wk 1.1% |
| Bar | +20% max HP 8% | missing 1 wk 5.9% / 2 wk 2%; Resolution quirk 3.9%; Tippler quirk 3.9%; stays 1 extra week 3.9%; loses a trinket 3.9%; **loses 500 gold** 2%; −10 ACC 2%; −5 Dodge 2% |
| Gambling | **+2,000 gold** 3.5%; wins a trinket 2.9%; Skilled Gambler quirk 2.9% | stays 1 extra week 8.5%; **loses 1,000 gold** 5.2%; Known Cheat 2.9%; Gambler 2.9%; Bad Gambler 2.9%; loses a trinket 2.9%; missing 1 wk 2.2% / 2 wk 0.7% |
| Brothel | +6 SPD 6.3%; −25% stress 3.1% | stays 1 extra week 6.3%; loses a trinket 3.1%; −5 SPD 3.1%; Love Interest 3.1%; **Syphilis** (disease) 3.1%; Deviant Tastes 3.1%; **loses 750 gold** 3.1%; missing 1 wk 2.4% / 2 wk 0.8% |

- Non-quirk buffs and debuffs from town last until the hero's next quest. (wiki)
- Skilled Gambler: +12.9% money wins, +13.3% trinket wins. Bad Gambler: +11.4% money losses, +13.3% trinket losses. (wiki)
- Trinket-loss odds by rarity: about 1% for Rare and Very Rare, about 2.5% for others. (wiki)

### 4.3 Quirks that restrict activities (wiki)

| Quirk | Restriction |
|---|---|
| Enlightened | Only Meditates |
| Unquiet Mind | Won't Meditate |
| God Fearing | Only Prays |
| Witness | Won't Pray |
| Flagellant | Only Flagellates |
| Faithless | Won't Pray or Flagellate |
| Tippler | Only the Bar |
| Resolution | Never drinks (no Bar) |
| Gambler | Only gambles |
| Known Cheat | Barred from the Gambling Hall |
| Love Interest | Only the Brothel |
| Deviant Tastes | Barred from the Brothel |

- Non-restricting relief quirks: Meditator (better Meditation and camp recovery) and Nymphomania (+20% Brothel relief). (wiki)
- **Design consequence:** the side effects themselves create restricting quirks, so the Tavern and Abbey slowly "specialise" heroes. (inferred)

---

## 5. Hero progression

### 5.1 Resolve levels and XP

| Level | Name (wiki) | Total XP, Darkest/Stygian | Per level | Total XP, Radiant |
|---|---|---|---|---|
| 0 | Seeker | 0 | — | 0 |
| 1 | Apprentice | 2 | +2 | 2 |
| 2 | Adventurer | 8 | +6 | 7 |
| 3 | Veteran | 14 | +6 | 13 |
| 4 | Master | 24 | +10 | 21 |
| 5 | Champion | 36 | +12 | 29 |
| 6 | Legend | 48 | +12 | 40 |

(wiki; the data's `resolve_level_thresholds [0,2,8,14,24,36,48]` matches Darkest)

**Service tiers:** Apprentice = levels 0–2, Veteran = 3–4, Champion = 5–6. These tiers set Abbey, Tavern and Sanitarium prices. (wiki)

### 5.2 XP per mission

Every surviving hero gets the full amount on **success** only.

| Quest level | Short | Medium | Long | Boss (always medium length) |
|---|---|---|---|---|
| Apprentice (level 1) | 2 | 3 | 4 | 4 |
| Veteran (level 3) | 4 | 6 | 8 | 8 |
| Champion (level 5) | 8 | 12 | 16 | 16 |

(wiki; data `resolve_xp_table` identical)

- The Old Road gives 2 XP. Darkest Dungeon quests give 16 each. (wiki)
- **Retreating or abandoning gives 0 XP**, "regardless of the amount of enemies slain or objectives partly completed". (wiki)
- Activate-quest town events give +33% XP in that region next week. (wiki)
- **Unconfirmed:** whether over-levelled heroes (one level above) earn less XP. No source mentions a reduction.

### 5.3 What a level-up does

- **+10% resistance** to Stun, Blight, Bleed, Move and Debuff, and **+10% trap disarm chance** per level. (wiki)
- Disease resistance does **not** scale with level. (wiki)
- **Unlocks higher purchase tiers:** weapon, armour and skill rank 2 at level 1, rank 3 at 2, rank 4 at 3, rank 5 at 5. (wiki + data `prerequisite_resolve_level 1/2/3/5`)
- Moves the hero into a more expensive service tier at level 3 and level 5. (wiki)
- Changes which quests the hero will accept (5.4).
- **HP, damage, dodge and speed do not change with level.** They live on the weapon and armour rank (the data's hero files hold HP/dodge per armour rank and damage/crit/speed per weapon rank; nothing per level) (inferred from data). The wiki example "Abomination Max HP 26 → 46 at level 6" is the armour rank 1 → 5 difference.

### 5.4 Level restrictions ("will not go")

- Quest levels: Apprentice = 1, Veteran = 3, Champion = 5, Darkest = 6. (wiki; data difficulty values 1/3/5/6)
- **Refusal (Darkest/Stygian):** a hero whose level is **≥ quest level + 2** "will refuse to be added to the party". So:
  - Apprentice quests accept levels 0–2.
  - Veteran quests accept 0–4.
  - Champion quests accept anyone.
  (wiki; data `resolve_level_threshold_table [2,2,3,4,5,99,99]`, i.e. max allowed hero level per quest level index)
- **Radiant:** heroes up to level 4 may enter Apprentice quests; any hero may enter Veteran and Champion. (wiki/patch Feb 2017) The *Helping Hand* town event lifts restrictions for the next quest. (wiki)
- **Underleveled penalty:** per level the hero is *below* the quest level, +20 stress on entering (data `stress_damage 20`) and +25% stress taken. (wiki)
- The wiki says level 0 heroes "always" take this penalty on their first expedition, since Apprentice is level 1. I could not confirm this from a second source.
- A level 0 hero reaches level 1 after any successful quest (2 XP minimum). (wiki)

---

## 6. Gear, skills and camping

### 6.1 Weapon and armour ranks

Every hero has a weapon and an armour, each rank 1–5. Rank 1 is the recruit's gear. (wiki)

**Gold cost to buy each rank** (before Furnace discount; the Weapon/Armour Tinker quirk takes −20%):

| Rank | Radiant | **Darkest (default)** | Stygian / Bloodmoon | Hero level needed | Blacksmith level needed |
|---|---|---|---|---|---|
| 2 | 750 | **750** | 750 | 1 | 1 |
| 3 | 1,500 | **1,750** | 2,000 | 2 | 2 |
| 4 | 2,500 | **3,000** | 4,000 | 3 | 3 |
| 5 | 4,000 | **6,000** | 8,000 | 5 | 4 |

(wiki)

- The 2016 data has 750/2000/4000/8000 for the default mode, matching today's Stygian column. That fits the Feb 2017 patch's "reduced hero weapon and armour upgrade costs" for Darkest. (data/patch)
- Ranks must be bought in order. (data: each rank requires the previous one)

**What a weapon rank gives** (wiki "Weapons"):

- Damage: min usually +1 per rank, max +1–2.
- Crit: +1% per rank.
- Speed: usually +1 at ranks 3 and 5.

Example, Crusader (DMG / CRIT / SPD):

| Rank | Crusader |
|---|---|
| 1 | 6–12 / 3% / 1 |
| 2 | 7–14 / 4% / 1 |
| 3 | 8–16 / 5% / 2 |
| 4 | 9–17 / 6% / 2 |
| 5 | 10–19 / 7% / 3 |

(wiki; the 2016 data has crit 5–7%)

**What an armour rank gives** (wiki "Armor"):

- **+5 Dodge** per rank for every hero.
- **Max HP +3 to +7** per rank, depending on class. Examples: Crusader 33/40/47/54/61; Antiquarian 17/20/23/26/29.
- Hero armour in the data has `prot 0` at every rank, so heroes get no PROT from armour; PROT comes from skills and trinkets. (data)

### 6.2 Combat skills and the Guild

- Each class has **7 combat skills**; **4** can be equipped, and you can swap them freely outside combat. (data `number_of_selected_combat_skills_max 4`; wiki)
- Level 0 recruits know 4 of the 7 (2.3).
- **Learning** a locked skill costs **1,000 gold** at the Guild. (wiki; data: skill tier 0 costs 1000, needs level 0)
- Every skill has **5 ranks**:

| Skill rank | Gold (base) | Hero level | Guild Instructor Mastery level |
|---|---|---|---|
| 1 | (owned or learned) | 0 | — |
| 2 | 250 | 1 | 1 |
| 3 | 750 | 2 | 2 |
| 4 | 1,250 | 3 | 3 |
| 5 | 2,500 | 5 | 4 |

(wiki)

- **Conflict / version:** the 2016 data has 250/750/1500/3000. The Feb 2017 patch "reduced cost of upgrading hero skills' final two levels". Use the wiki.
- Training Regimen takes up to −50% off these.

**What improves per skill rank** (wiki, Crusader examples):

- Attack skills: **+5 ACC** and **+1% crit** per rank. Smite goes from ACC 85 / crit +0% to 105 / +4%. Damage modifiers are often unchanged.
- Status skills: base effect chance **+10% per rank**. Stunning Blow's stun goes 100% → 140%.
- Heals and buffs scale up. Battle Heal goes 2–3 → 5–6; Bulwark of Faith's PROT buff +20% → +30%.

### 6.3 Camping skills (brief)

- Heroes start with 3 camping skills (2 class-specific and 1 shared) and can take **4** into a camp. Extra skills cost 1,750 gold each at the Survivalist. (wiki/data)
- Each class has about 7 camping skills. Camping skills have no ranks. (wiki)
- **A camp:**
  - Uses 1 Firewood. Medium quests give 1 Firewood, long quests 2. (wiki/data)
  - Gives the party **12 respite points** to spend on skills. Skills cost 2–5 points each; shared ones cost 2. (wiki)
  - Includes a meal. With 4 heroes: 0 food = starve (−20% HP, +15 stress); 2 = no effect; 4 = +10% HP; 8 = +25% HP and −10 stress. Food needs scale down per dead hero. (wiki)
  - Has a 33% night ambush chance unless a skill prevents it. (wiki)
  - Resets the Light Meter to 100 when exploration resumes. (wiki)

---

## 7. Missions

### 7.1 Mission board and generation

- The board is regenerated weekly. Objective, difficulty and length are random, weighted by the roster. At least one Apprentice quest is always offered. (wiki)
- **Generation rules (data, 2016):**
  - `number_of_quests_per_town_visit_table: [2, 5, 7, 8, 9, 10, 11, 12]` is the total quests offered. **Index meaning unconfirmed.** My reading (inferred): indexed by weeks or town visits so far, capped at the last value, so the board grows from 2 quests in week 1 to 12.
  - `max_number_of_generated_quests_per_dungeon: 4`, i.e. at most 4 quests per region.
  - Regions open after N quests finished: Ruins ("crypts") 2, Weald 3, Warrens 4, Cove 4.
  - Quest difficulty follows the roster: hero levels 0–2 → Apprentice, 2–4 → Veteran, 4–6 → Champion (`generated_resolve_level_difficulties`). The board offers quests your heroes can actually take.
  - A region's quest *type* table grows with region progression. At first only short Cleanse quests; then Explore and Cleanse at short and medium; then Gather and Activate (medium); later Explore and Cleanse at long.
- Region levels rise by **killing that region's boss**. The boss quest appears after enough non-boss quests ("boss unlock progress", 7.5). Higher region levels add Veteran, then Champion quests. (wiki)

### 7.2 Quest types

| Type | Goal | Notes |
|---|---|---|
| **Explore** | Enter **90%** of rooms (data `percentage 0.9`) | Rooms left by fleeing a fight still count. (wiki) |
| **Cleanse** | Win **every room battle** (data `percentage 1`; corridor fights don't count) | (wiki) |
| **Gather** | Collect **3** quest items from special curios and carry them out (data `amount 3`) | Success triggers a regional town event. (wiki) |
| **Activate** | Use **3** provided quest items on special curios (data `inventory_activate amount 3`) | Same. |
| **Boss** | Kill the region boss | Always medium length; always rewards a **Very Rare** trinket. (wiki) |
| Darkest Dungeon / plot | Fixed level-6 quests | Retreat costs a hero's life. (wiki) |

Once the goal is met you may return to the Hamlet at any time with the full reward. If the party then dies, the reward is still granted (but loot is lost). (wiki)

### 7.3 Lengths

| Length | Rooms (data, Explore) | Room battles + hallway battles (data, Explore) | Hallway curios (data) | Firewood | Camping |
|---|---|---|---|---|---|
| Short | 9 (Cleanse 7) | 1–3 + 2–4 | 9 | 0 | none |
| Medium | 14 (Boss / Cleanse 11; Gather / Activate 13) | 3–4 + 3–4 (Boss / Cleanse 4–5 + 4–5) | 14 | 1 | 1 camp |
| Long | 19 (Cleanse 14) | 7 + 7 (Cleanse 8 + 8) | 19 | 2 | 2 camps |

- Data source: `MapGenerator` for the Ruins. The other regions use the same counts and differ only in grid size, traps and obstacles.
- I read the battle numbers as min–max ranges; that reading is inferred.
- Long quests always have a hidden secret room with 7,500 gold. (wiki)

### 7.4 Difficulty levels

| Level | Value | Monsters (wiki) |
|---|---|---|
| Apprentice (green) | 1 | Weakest; smallest dungeons |
| Veteran (orange) | 3 | Stronger; bigger dungeons; possible champion monsters |
| Champion (red) | 5 | Strongest; more accurate enemies |
| Darkest | 6 | Darkest Dungeon and Vvulf plot quests only |

### 7.5 Rewards

Each completed quest pays **gold + heirlooms + 1 trinket + XP**, plus progress toward the region boss. (wiki)

**Gold reward** (data `rewards.item_table`, 2016 snapshot):

| Level | Short | Medium | Long |
|---|---|---|---|
| Apprentice (1) | 3,000 | 4,500 | 7,500 |
| Veteran (3) | 4,500 | 6,750 | 11,250 |
| Champion (5) | 6,000 | 9,000 | 15,000 |
| Darkest (6) | 9,000 | 13,500 | 22,500 |

- The pattern is ×1 / ×1.5 / ×2.5 by length and ×1 / ×1.5 / ×2 by level. (inferred)
- The wiki confirms only that gold "increases with difficulty and length". **Not confirmed against the current build.** A Steam modding thread cites 3,000 and 4,500 in the quest file, which is consistent. (community)

**Heirloom reward amounts** (data `rewards.heirloom_amount_table`; rows = level, columns = short/medium/long):

| Level | Bust or Portrait | Deed or Crest |
|---|---|---|
| Apprentice | 2 / 2 / 4 | 3 / 5 / 9 |
| Veteran | 2 / 3 / 6 | 4 / 6 / 12 |
| Champion | 3 / 5 / 9 | 6 / 9 / 18 |

- **Heirloom type** (data `heirloom_type_map`): each region rewards one of two types:
  - Ruins: Bust or Crest
  - Warrens: Portrait or Crest
  - Weald: Deed or Crest
  - Cove: Portrait or Deed
- **Conflict:** the 8 March 2016 patch says "Heirloom type is no longer tied to each region"; quest heirloom rewards became random. The type map may restrict rather than fix the type; **unconfirmed**. Boss quests can give several types. (wiki)

**Trinket reward rarity** (data `trinket_chance_table`, matching the wiki's "one tier per step"):

| Level | Short | Medium | Long |
|---|---|---|---|
| Apprentice | Common | Uncommon | Rare |
| Veteran | Uncommon | Rare | Very Rare |
| Champion | Rare | Very Rare | Ancestral |

Boss quests always give Very Rare. (wiki)

**Boss unlock progress per successful quest:**

| Quest level | Short | Medium | Long |
|---|---|---|---|
| Apprentice | +50% | +75% | +100% |
| Veteran | +33% | +50% | +67% |
| Champion | +20% | +30% | +40% |

The boss appears at 100%. Excess carries over to the next boss. (wiki)

### 7.6 Provisions (bought before embarking)

| Item | Price | Stack | Use (wiki) |
|---|---|---|---|
| Food | 75 | 12 | Hunger checks (4 per meal for a full party), camp meals; heals 5% max HP |
| Torch | 75 | 8 | +25 light |
| Shovel | 250 | 4 | Clears obstacles; without one, clearing costs HP and stress |
| Bandage | 150 | 6 | Cures bleed; curio key |
| Antivenom | 150 | 6 | Cures blight; curio key |
| Holy Water | 150 | 6 | Resist buff; curio key |
| Medicinal Herbs | 200 | 6 | Removes debuffs; curio key |
| Skeleton Key | 200 | 6 | Opens chests and doors |
| Laudanum | 100 | 6 | Cures horror |

- **Free items:**
  - Firewood by length: 0 / 1 / 2. (data/wiki)
  - Class items: Crusader 1 Holy Water; Houndmaster 2 Dog Treats; Plague Doctor 1 Antivenom; Grave Robber 1 Shovel; Arbalest 1 Bandage; Leper and Jester 1 Medicinal Herbs. (data/wiki)
- **Store stock caps** (data 2016, short / medium / long):
  - Food: 18 / 24 / 36
  - Torches: 18 / 24 / 36
  - Shovels: 4 / 6 / 8
  - Each other item: 6 / 9 / 12
  - Laudanum is absent from this snapshot. **Not confirmed for the current game.**
- **Typical purchase:** Food about 8 / 16 / 24 (wiki "Food"). Community picks:
  - Torches about 8 / 12–16 / 16–24.
  - Shovels 1–2 / 2–3 / 3–4.
  - 2–4 of each region-specific curio item.
  - "One or two thousand gold on provisions per dungeon run is pretty normal". (community)
- **Refunds:**
  - On the provisioning screen, items sell back at full price. (wiki)
  - After a quest, leftovers are sold automatically at a "greatly reduced" price. Community figures range from about 5% to 10%. (wiki/community) Radiant refunds slightly more. (patch)
- **Inventory** is 16 slots, shared by provisions and loot. Gold stacks to 1,750, plus 750 per Antiquarian. (wiki) So buying provisions costs loot space, and that trade-off drives the loop. (inferred)
- Town events can halve or zero provision prices, or halve the stock ("Lost Shipment"). (wiki)

### 7.7 Retreating and abandoning

- **Retreat from battle:**
  - The attempt uses the hero's turn. 70% success, +5% per further attempt.
  - On success: **25 stress** per hero (more with modifiers), and the party is pushed back to the previous hallway or room.
  - Not allowed vs the Shrieker or the final boss, or on round 1 when surprised. (wiki)
- **Abandon quest** (out of combat):
  - Always succeeds. **20 stress** per hero, unaffected by trinkets, quirks or light; no resolve check at 100.
  - **Keep collected loot; forfeit quest reward and XP.**
  - Raises the chance of negative quirks and lowers positive ones at end of quest.
  - The week still passes. (wiki/community)
- **Darkest Dungeon and *Wolves at the Door*:** retreating or abandoning kills one hero to cover the rest. (wiki)
- **Total party kill:** loot lost; equipped trinkets lost (recoverable from the Shrieker later); quest reward still granted if the goal was complete. (wiki)

---

## 8. Economy

### 8.1 Gold income

- **Quest reward:** 3,000–22,500 (7.5).
- **Loot from curios and treasure.** The generic treasure table A rolls: gold about 32%, gems about 19%, heirlooms about 28%, supplies about 16%, trinket about 5% (data weights 14/8/12/7/2 of 43). The data uses it for chest bonus rolls, among others. Each gold roll gives 25–1,000:

| Level | Weights for 25 / 50 / 100 / 250 / 500 / 750 / 1000 | Mean per gold roll (inferred) |
|---|---|---|
| Apprentice | 4 / 4 / 6 / 3 / 2 / 1 / 1 | ≈ 210 |
| Veteran | 2 / 4 / 4 / 6 / 4 / 2 / 1 | ≈ 290 |
| Champion | 1 / 4 / 4 / 4 / 4 / 4 / 2 | ≈ 375 |

  (data, 2016; the Feb 2017 patch "increased gold drops and gold stacking from 1,500 to 1,750")
- **Battle loot** (table B) is gold or gems only, no heirlooms. (data)
- **Darkness bonus:** low light gives extra loot rolls, up to 75% per battle (table B) and 95% per chest (table A) in total darkness, falling to 0 at light 76+. (data `darkness_bonuses`) Reading the index as light level is my inference; it matches DD1's known "low torch = more loot" rule.
- **Gems** stack 5 per slot (6 with a district). Per-gem values:

| Gem | Value |
|---|---|
| Citrine | 250 |
| Jade | 375 |
| Onyx | 500 |
| Emerald | 750 |
| Sapphire | 1,000 |
| Ruby | 1,250 |

  Gems auto-convert to gold in town. (wiki)
- Secret rooms in long quests hold 7,500 gold. (wiki)
- Selling trinkets returns 15% of the buy price (1.9).
- **Typical haul: unconfirmed.** Rough estimate (inferred): Apprentice short ≈ 4–7k total; Champion long ≈ 25–40k, limited by the 16 slots.
  - A full 16-slot bag of gold is 28,000.
  - The achievement "Greater riches were never witnessed" is for 20,000+ from one quest (wiki), which suggests 20k is a strong haul.

### 8.2 Gold sinks

| Sink | Typical cost | Frequency |
|---|---|---|
| Provisions | 1–3k per quest (community) | every quest |
| Stress relief | 1,000–2,700 per hero (section 4) | most returning heroes, every week |
| Weapon and armour ranks | 750–6,000 each; ≈ 21k per hero for both lines to rank 5 (inferred: 2 × 10,750 at Darkest prices) | as heroes level |
| Skill ranks | 250–2,500 each; ≈ 4,750 per skill to rank 5; ≈ 19k for 4 skills (inferred) | as heroes level |
| New combat skill | 1,000 | occasional |
| Camping skill | 1,750 | occasional |
| Sanitarium | 750–13,500 (section 9) | when bad quirks or diseases appear |
| Trinkets | 5,000–25,000 | optional |

Gold never gates the game, because recruits are free. (wiki)

### 8.3 Heirloom drops

- **Curio heirloom table H** (data). One roll gives one stack:

| Quest level | Busts | Portraits | Deeds | Crests |
|---|---|---|---|---|
| Apprentice | 2 | 1 | 2 | 4 |
| Veteran | 3 | 2 | 3 | 6 |
| Champion | 4 | 2 | 4 | 8 |

- **Type weights per region**, Bust / Portrait / Deed / Crest (data):
  - Ruins 3/1/1/3
  - Weald 1/1/3/3
  - Warrens 1/3/1/3
  - Cove 1/1/1/3
  So the Ruins lean to Busts, the Weald to Deeds, the Warrens to Portraits, and the Cove to Crests. The wiki says each location "tends to drop one type more than others". (data/wiki)
- **Which loot rolls give heirlooms.** Table H is reached through the generic treasure table A (12 of 43 weight, about 28%) and two curio tables, CH and GH (2 of 5 weight, 40%). (data) Which curios use CH and GH is **unconfirmed**. Battles never roll H.
- Heirlooms also come from quest rewards (7.5).
- **Dungeon stack sizes:** Crest 12, Bust 6, Deed 6, Portrait 3. Heirlooms take inventory slots, so they compete with gold. (wiki)

### 8.4 Heirloom Exchange (data, matching the wiki)

| Give | Get |
|---|---|
| 3 Crests | 1 Bust / 1 Deed |
| 6 Crests | 1 Portrait |
| 2 Busts or 2 Deeds | 3 Crests |
| 3 Busts | 2 Deeds |
| 3 Deeds | 2 Busts |
| 3 Busts or 3 Deeds | 1 Portrait |
| 1 Portrait | 3 Crests |
| 2 Portraits | 3 Busts / 3 Deeds |

- Implied relative values: Crest 1, Bust or Deed about 2, Portrait about 4 (inferred).
- Comet Shards (DLC) trade one-way into heirlooms. (wiki)

### 8.5 Campaign pacing

- **Building unlocks:** spread over weeks 1–4, so the early game teaches one system per week. (data/wiki)
- **Hero levelling:**
  - A hero needs 48 XP for level 6. An efficient path is about 7–8 successful quests: Apprentice short → 2× Apprentice long → Veteran medium → Veteran long ×2 → Champion medium → Champion long. (inferred)
  - Each hero also needs about 40k gold of gear and skills to be "finished" (8.2).
- **Boss pacing:** 1 long or 2 short Apprentice quests unlock the first boss. Veteran and Champion bosses need about 2–3 long or 3–5 short quests each. (wiki)
- **Time limits:**
  - Stygian: 86 weeks (death limit 12). Bloodmoon: 100 weeks (death limit 16). (wiki/patch)
  - Darkest has no limit. An unhurried Darkest campaign plausibly runs 100+ weeks (inferred; **unconfirmed**).
  - Radiant speeds up XP, region progression and town events. (wiki)
- **The loop's main tension (inferred):**
  - Every expedition returns heroes with stress. Relieving it costs about 1k–2.7k gold and takes the hero out for the next week.
  - So a roster of about 3× the party size is needed: one party on the road, one in treatment, one idle and recovering 5 stress per week.
  - Gold flows into treatment and per-hero power. Heirlooms flow into buildings that make both cheaper or better.
  - Higher levels make treatment pricier and lock heroes out of easy quests, which forces the move up to Veteran and Champion content.

---

## 9. Quirks, diseases and trinkets (brief)

### 9.1 Quirks

- Each hero has up to **5 positive and 5 negative** quirks. A new quirk replaces a random unlocked one. (wiki)
- **End-of-quest roll** for surviving heroes, with stress capped at 100 in the formula (wiki):
  - Success: positive 50 − 0.10×stress %; negative 30 + 0.20×stress %.
  - Failure: positive 40 − 0.15×stress %; negative 40 + 0.30×stress %.
- Quirks also come from curios, town side effects (section 4) and recruitment. (wiki)
- **Locking:**
  - Each negative quirk has a **25%** chance to become locked ("permanent") after each mission. Locked negatives cost more to remove. (wiki)
  - Positive quirks are locked at the Sanitarium, up to 3. (wiki)
- **Gameplay hooks:**
  - Some quirks force curio interactions; Kleptomaniac steals loot.
  - Some restrict town activities (4.3).
  - Some change service prices, e.g. Weapon/Armour Tinker −20% at the Blacksmith. (wiki)

**Sanitarium prices** (gold, by service tier; Treatment Library takes −10% per level):

| Treatment | Apprentice | Veteran | Champion |
|---|---|---|---|
| Remove a negative quirk | 1,500 | 2,100 | 2,700 |
| Remove a locked negative quirk | 5,000 | 7,000 | 9,000 |
| Lock or remove a positive quirk | 7,500 | 10,500 | 13,500 |
| Cure diseases | 750 | 1,050 | 1,350 |

(wiki)

- Per week, a hero can have at most 1 negative quirk removed and 1 positive quirk locked; doing both costs the sum.
- Disease treatment cures one chosen disease, with a chance to cure all (33% base → 67% → 100%, data).
- Quirk and disease treatment cannot be combined in the same week. (wiki)

### 9.2 Diseases

- Diseases are negative quirks. A hero can have at most 3; a 4th replaces a random one. They last until cured. (wiki)
- **Sources:** enemy attacks and curios at fixed chances; the Brothel side effect (Syphilis).
- **End of quest roll** for heroes level ≥ 2: 32% − 33% × disease resist, minimum 5%. (wiki)
- **Cures:** the Sanitarium (above), or certain camping skills (Grave Robber, Plague Doctor). (wiki)

### 9.3 Trinkets

- **2 slots** per hero. Rarities: Very Common, Common, Uncommon, Rare, Very Rare, Ancestral, plus special sets. Some are class-locked. (wiki)
- **Sources:**
  - 1 per quest reward (7.5).
  - Curio and chest loot (table T: Apprentice 45% Very Common / 40% Common / 10% Uncommon / 5% Rare). (data)
  - Boss and enemy drops.
  - The Nomad Wagon (1.9).
  - Gambling wins.
- **Loss:**
  - Trinkets on a dead hero are lost unless the battle is won.
  - Tavern side effects can lose a trinket.
  - Lost (not sold) trinkets can be recovered: after 8 losses, a Shrieker quest returns 8 of them. (wiki)
- The trinket inventory holds 999. (wiki)

---

## 10. Could not confirm

- **Current-build quest gold, heirloom reward amounts and provision stock caps.** Only the 2016 data has them. The wiki gives no numbers. Treat them as close but unverified.
- **Index meaning of the quests-per-visit table** `[2,5,7,8,9,10,11,12]`, and of the town-event chance arrays.
- **How Experienced Recruit chances are rolled**, and the exact Guild and Blacksmith prerequisites (sources disagree).
- **What happens to a dismissed hero's trinkets.**
- **Hero name pool size.**
- **Refund on removing a hero from a town slot.**
- **Whether over-levelled heroes earn reduced XP** (no source says they do).
- **Level 0 heroes taking the underleveled penalty in Apprentice quests.** Wiki only.
- **Stress cap at 100 on return.** Wiki only.
- **Post-quest provision refund rate:** about 5% to 10% (community; wiki only says "greatly reduced").
- **The official modding guide (Steam 819597757)** could not be read (HTTP 429), so no claim here relies on it.

---

## Implementation notes (for darko-dungo)

Context from [design.md](../design.md):

- DD2 combat, with stress 0–10.
- 5 fixed skills per hero; no 7-known/4-equipped choice.
- No dodge or accuracy stats; tokens instead.
- 4 classes: Vanguard, Cutthroat, Marksman, Mender. 5 enemies: Ghoul, Bone Spearman, Spitter, Cultist, Brute.
- No dungeon map yet: a mission is a sequence of waves.

The open "Game loop" question in design.md is what this section answers.

### Translating DD1 numbers to this game

- **Keep gold and heirloom numbers 1:1.** They are only meaningful relative to each other. Copying DD1's ratios gives DD1's pacing for free.
- **Stress: divide DD1 by 10, round to whole points.**
  - Stress relief activities: 45/55/65 → **4/5/6**; upgraded **6/7/8**, then **7/9/10**.
  - Idle recovery 5 → **1 per week**. Rounding 0.5 up is generous; consider 1 every other week if the roster gets too easy.
  - Underleveled penalty +20 → **+2 stress on entry per level under**.
  - Retreat 25 → **+3**; abandon 20 → **+2**.
- **HP resets on return; stress persists.** This is DD1's rule (wiki), and it resolves design.md's open "do HP and stress persist" question for the town loop.
- **Gear without dodge or accuracy:**
  - Armour rank: HP only, about +20% of base HP per rank (Crusader 33→61 is +21% per rank). For example the Vanguard goes 40/48/56/64/72 and the Mender 28/34/40/46/52. (inferred)
  - Weapon rank: +1 min and +1 max damage per rank (or about +10% damage), +1% crit, and +1 SPD at ranks 3 and 5. Applied to every damaging skill.
- **Skills:** DD2 heroes already have their 5 skills, so drop "learn skill" (1,000 gold). For upgrades choose one:
  - (a) DD1's 4 paid ranks (250/750/1,250/2,500), each adding about +10% damage or heal and +10% status chance;
  - (b) a single DD2-style "mastered" upgrade per skill.
  Option (b) is the smaller first step. (inferred)
- **Mission length = number of fights.** DD1 long quests have about 14–16 fights, too many for DD2-weight battles. Suggest **short 2–3 waves, medium 4–5 with one rest stop, long 6–8 with two rest stops**. A rest stop replaces DD1's camp: spend food to heal, maybe one camping-style action. (inferred)
- **Difficulty:** DD1 swaps in stronger enemy variants per level. With only 5 enemy types, scale stats instead. For example, Veteran +25% HP and damage, Champion +50% HP and damage, plus +5% crit (inferred; no DD1 source for a multiplier).

### Minimal first version (v1)

Aim: the weekly decision loop (who goes, who rests, what to buy) with the fewest systems.

1. **Week loop and estate state.** Week counter; gold; one heirloom currency; roster; recruit list; quest board; per-hero state:
   - class, name, level, XP, stress, available-from week
   - weapon rank, armour rank, skill upgrades
   Advance the week only when an expedition returns: success, abandon or wipe.
2. **Start of campaign.** 4 heroes at level 0, one of each class. 5,000 gold, standing in for the Old Road reward. Roster cap 9.
3. **Stage Coach.**
   - 2 free recruits per week of random class and level 0, with a random name from a list. Unhired recruits vanish at week end.
   - Always top up so 4 heroes are available.
   - Two upgrades: Network (+1 recruit, up to 4) and Barracks (cap 9 → 12 → 16), with DD1's heirloom costs.
   - Dismiss button.
4. **Quest board.**
   - 3 quests in week 1, growing to 5. Each is {difficulty Apprentice/Veteran/Champion, length short/medium/long, reward gold + heirlooms}.
   - Use DD1's gold table (3,000/4,500/7,500 × 1 / 1.5 / 2) and XP table (2/3/4 × 1/2/4) unchanged.
   - Only offer difficulties some roster heroes can take.
   - One objective type ("survive all waves"). Add Explore, Gather and Boss once a dungeon map exists.
5. **Party select with DD1's eligibility rules.**
   - Heroes busy in town or missing are greyed out.
   - Heroes at level ≥ quest level + 2 show "will not go".
   - Underleveled heroes get the stress penalty, with a warning.
6. **Resolve levels 0–6** with DD1's XP table (2/8/14/24/36/48). A level-up gives +10% to the resistances combat already uses, and raises the gear and skill caps.
7. **One stress building** (Abbey-like). Three activities with 1 slot each (4/5/6 stress for 1,000/1,250/1,500 gold, ×1.4 and ×1.8 for higher tiers). The hero is busy for one week. Skip side effects at first, or add only "stays another week".
8. **Blacksmith.**
   - Weapon and armour ranks 2–5 for 750/1,750/3,000/6,000 gold.
   - Gated by hero level 1/2/3/5 and by Blacksmith level, which costs heirlooms.
9. **Provisions:** Food only (75 gold), used at rest stops. Leftovers are refunded at 10%.
10. **Retreat and abandon** with DD1's rules: lose the reward and XP, keep the loot, +2 stress.
11. **Graveyard as a plain list** (name, class, level, week, killer). Cheap, and it gives permadeath weight.

Keep this logic in a pure "estate core" with its own seeded RNG and an event stream, mirroring the combat core. Store building ladders, quest tables and price tables as `.tres` Resources, like the existing content. (inferred)

### Add later (rough priority)

1. **Guild skill upgrades** (option b, then maybe a). Second gold sink per hero.
2. **Abbey and Tavern side effects** with DD1's 37.5% table. They need quirks for most outcomes, so pair them with:
3. **Quirks** (5+5, end-of-quest roll formula, 25% lock chance) and the **Sanitarium** quirk ward. This is where heroes start to feel individual.
4. **Second heirloom type**, then all four with region-weighted drops and the **Heirloom Exchange**. Only worth it once there are several regions.
5. **Regions and bosses:** boss unlock progress (50/75/100% Apprentice), region levels unlocking Veteran and Champion quests.
6. **Trinkets:** quest reward trinket by the rarity table, 2 slots, then the **Nomad Wagon**.
7. **Diseases** and the Sanitarium disease ward.
8. **Town events:** escalating chance, cooldowns, minimum week. Start with "free service" and "+2 recruits of class X".
9. **Dungeon map, light and full provisions** (torches, shovels, curio keys), plus Gather and Activate quests, then the **Survivalist**/camping. These depend on a dungeon map, which is a separate design decision.
10. **Experienced recruits**, Ancestor's Memoirs, revival event, game modes with week limits.

---

## Sources

### wiki.gg (primary for current numbers)
- Hamlet: https://darkestdungeon.wiki.gg/wiki/Hamlet
- Town: https://darkestdungeon.wiki.gg/wiki/Town
- Stage Coach: https://darkestdungeon.wiki.gg/wiki/Stage_Coach
- Abbey: https://darkestdungeon.wiki.gg/wiki/Abbey (and https://darkestdungeon.wiki.gg/wiki/Meditate)
- Tavern: https://darkestdungeon.wiki.gg/wiki/Tavern
- Blacksmith: https://darkestdungeon.wiki.gg/wiki/Blacksmith
- Guild: https://darkestdungeon.wiki.gg/wiki/Guild
- Sanitarium: https://darkestdungeon.wiki.gg/wiki/Sanitarium
- Nomad Wagon: https://darkestdungeon.wiki.gg/wiki/Nomad_Wagon
- Survivalist: https://darkestdungeon.wiki.gg/wiki/Survivalist
- Graveyard: https://darkestdungeon.wiki.gg/wiki/Graveyard
- Resolve: https://darkestdungeon.wiki.gg/wiki/Resolve
- Expedition: https://darkestdungeon.wiki.gg/wiki/Expedition
- Quest: https://darkestdungeon.wiki.gg/wiki/Quest
- Choosing a quest: https://darkestdungeon.wiki.gg/wiki/Choosing_a_quest
- Provisions: https://darkestdungeon.wiki.gg/wiki/Provisions
- Food: https://darkestdungeon.wiki.gg/wiki/Food
- Torch: https://darkestdungeon.wiki.gg/wiki/Torch
- Inventory: https://darkestdungeon.wiki.gg/wiki/Inventory
- Heirlooms: https://darkestdungeon.wiki.gg/wiki/Heirlooms
- Loot: https://darkestdungeon.wiki.gg/wiki/Loot
- Gold: https://darkestdungeon.wiki.gg/wiki/Gold
- Town Events: https://darkestdungeon.wiki.gg/wiki/Town_Events
- Stress: https://darkestdungeon.wiki.gg/wiki/Stress
- Retreating: https://darkestdungeon.wiki.gg/wiki/Retreating
- Camping: https://darkestdungeon.wiki.gg/wiki/Camping
- Crusader: https://darkestdungeon.wiki.gg/wiki/Crusader
- Weapons: https://darkestdungeon.wiki.gg/wiki/Weapons
- Armor: https://darkestdungeon.wiki.gg/wiki/Armor
- Heroes (DD1): https://darkestdungeon.wiki.gg/wiki/Heroes_(Darkest_Dungeon)
- The Ancestor (dismissal narration): https://darkestdungeon.wiki.gg/wiki/The_Ancestor
- The Old Road: https://darkestdungeon.wiki.gg/wiki/The_Old_Road
- Getting Started (self-flagged as unreliable): https://darkestdungeon.wiki.gg/wiki/Getting_Started
- Game Modes: https://darkestdungeon.wiki.gg/wiki/Game_Modes
- Trinkets: https://darkestdungeon.wiki.gg/wiki/Trinkets_(Darkest_Dungeon)
- Quirks: https://darkestdungeon.wiki.gg/wiki/Quirks_(Darkest_Dungeon)
- Disease: https://darkestdungeon.wiki.gg/wiki/Disease_(Darkest_Dungeon)
- Backer heroes (search excerpt only): https://darkestdungeon.wiki.gg/wiki/Backer_heroes

### Patch notes (Red Hook, mirrored on wiki.gg)
- 8 March 2016 (roster 9/12/16/20/24/28, Heirloom Exchange, random quest heirlooms): https://darkestdungeon.wiki.gg/wiki/8_March_2016_patch
- 9 February 2017 (economy rebalance, Radiant/Stygian, gold stack 1,750): https://darkestdungeon.wiki.gg/wiki/9_February_2017_Patch
- 25 June 2018 (backup recruits capped at 4; search excerpt only): https://darkestdungeon.wiki.gg/wiki/25_June_2018_patch
- 28 May 2015 (renaming referenced; search excerpt only): https://darkestdungeon.wiki.gg/wiki/28_May_2015_patch

### Game data [D-U] (2016 snapshot of DD1 files in Reinisch's Unity port)
- Repository: https://github.com/Reinisch/Darkest-Dungeon-Unity
- Quests (generation, rewards, goals): https://raw.githubusercontent.com/Reinisch/Darkest-Dungeon-Unity/master/Assets/Resources/Data/JsonQuests.json
- Loot tables: https://raw.githubusercontent.com/Reinisch/Darkest-Dungeon-Unity/master/Assets/Resources/Data/JsonLoot.json
- Buildings: https://github.com/Reinisch/Darkest-Dungeon-Unity/tree/master/Assets/Resources/Data/Buildings (`stage_coach`, `abbey`, `tavern`, `sanitarium`, `nomad_wagon`, `guild`, `blacksmith`, `camping_trainer` `.building.json`)
- Hero upgrade trees: https://raw.githubusercontent.com/Reinisch/Darkest-Dungeon-Unity/master/Assets/Resources/Data/Upgrades/Heroes/crusader.upgrades.json
- Hero info (gear ranks, generation): https://raw.githubusercontent.com/Reinisch/Darkest-Dungeon-Unity/master/Assets/Resources/Data/Heroes/Info/Crusader.bytes
- Mechanics: https://github.com/Reinisch/Darkest-Dungeon-Unity/tree/master/Assets/Resources/Data/Mechanics (`Roster.json`, `Campaign.json`, `HeirloomExchange.json`, `Provision.json`, `TownEvents.json`, `MapGenerator.txt`)
- Stage Coach JSON field names (cross-check): https://github.com/XSNomad/DD_RandomStart (`JSON_Classes/StageCoach.cs`)

### Community
- Weeks advance per expedition: https://www.gameslearningsociety.org/wiki/how-do-weeks-pass-in-darkest-dungeon/ [GLS]
- Roster size and passive stress (Steam): https://steamcommunity.com/app/262060/discussions/0/1457328392116274606
- Stage Coach file and max roster 28 (Steam): https://steamcommunity.com/app/262060/discussions/0/2765630416821957514/
- Provision spend and refund about 5% (Steam): https://steamcommunity.com/app/262060/discussions/0/693122272400066528/
- Provisions per length (Steam, via search summary): https://steamcommunity.com/app/262060/discussions/0/135508833659754831
- Provisioning guide (GameSkinny, via search summary): https://www.gameskinny.com/tips/darkest-dungeon-provisioning-guide/

### Not reachable
- Official modding guide, Steam 819597757: https://steamcommunity.com/sharedfiles/filedetails/?id=819597757 (HTTP 429 on every attempt)
- darkestdungeon.fandom.com (HTTP 402)
