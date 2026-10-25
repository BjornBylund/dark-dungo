# Darkest Dungeon combat UI: presentation reference

Researched on 2026-10-25 for the Godot project `darko-dungo`, as the companion to [darkest-dungeon-combat.md](darkest-dungeon-combat.md) (rules). This document covers only **how combat looks and reads on screen**.
**Darkest Dungeon II (DD2) is the target.** Part A covers DD2 in depth. Part B is a short Darkest Dungeon 1 (DD1) comparison. The last section turns the findings into a prioritised checklist for a 1920×1080 Godot screen with placeholder art.

## How to read this document

Text sources say very little about DD2's interface, so most of this document comes from **looking at full-resolution 1920×1080 screenshots** (official Steam store and press images, plus player screenshots) and zooming in on each region. Every claim carries a tag:

| Tag | Meaning |
|---|---|
| **(seen S#/U#)** | Observed directly in the listed screenshot (index below). Pixel values were measured on 1920×1080 images and are accurate to about ±10 px. |
| **(patch)** | Red Hook patch notes. Authoritative for what exists and what changed. |
| **(wiki)** | darkestdungeon.wiki.gg. |
| **(community)** | Steam forum posts or guides. Lower weight. |
| **(inferred)** | My reading of what I saw, where no source states it. Treat as a design suggestion. |
| **(unknown)** | Not visible in any screenshot I found and not described in text. |

> **Version caveat.** The Steam store and press screenshots date from around the 1.0 release (May 2023). The July 2025 *Steadfast Stewards* update (v2.02) changed some UI details. It added quarter notches to health bars, recoloured some tokens, showed token durations in tooltips and added a 1.5× combat speed option [P-2025-07]. Where a patch changed something, the current behaviour is noted.

### Screenshot index

Official images (Steam store page for app 1940340 and Red Hook's DD2 media page):

| ID | Shows |
|---|---|
| S1 | Round 1, hero turn: Grave Robber "Audrey", *Thrown Dagger* selected, night forest |
| S2 | Action close-up: *Hold the Line*, red damage "5" |
| S3 | Enemy action close-up: *Fire Flay*, white "6" then red "3" |
| S4 | Academic View, the full-screen enemy info: *Fish Monger* |
| S5 | Round 2, hero turn: "Bonnie", *Firefly* selected, a skill on cooldown |
| S6 | Kingdoms-mode combat (militia), Round 2, two turns left in the queue |
| S7 | Road travel with a hero bark speech bubble |
| S8 | Inn: HP numbers and stress pips at rest |
| S9 | Official press image "combat-foetor": hero turn with no skill selected, bark bubble |
| S10 | Official press image "combat-wickedstab": action close-up, *Wicked Slice*, "8" |
| S11 | Official press image "combat-sprawl": rank 1 hero, disabled skills, a blessed skill |

Player screenshots (Steam Community):

| ID | Shows |
|---|---|
| U1 | *Bellow* close-up with two targets: "CRIT!" and "Dodge" on each |
| U2 | *Riposte* close-up: "Critical!", orange "20", "Armor Break!" |
| U3 | *Limerence*: "Critical!" orange "72"; a struck-through "16" then red "8" |
| U4 | **Round 19, enemy hovered with a skill selected**: HIT/DMG/CRIT preview and the enemy panel |
| U5 | Single-target heal close-up: green "+74" |
| U6 | *Deathless* party heal played in the normal battlefield view: green "Critical!" "+194", narrator subtitle |
| U7 | Pre-combat encounter title "Plague Eaters!", "!" bubbles over the heroes |
| U8 | Hero character sheet opened mid-combat (Round 4) |
| U9 | Enemy turn, "Runda 12" (Polish build): the bottom HUD is gone |
| U10 | Round 14: blessed skills and a cooldown "2" |
| U11 | Greyscale boss cinematic with a narrator subtitle |
| U-rel | Pre-embark relationship list: blessed skills drawn with gold sunburst tops |
| S3-rel | Official store image: the "Respectful" relationship card |

DD1 screenshots (Steam store page for app 262060): D1 is a hero turn (Grave Robber "Wilma"), D2 an in-place attack zoom with a red "10", D3 an enemy turn.

URLs are in the Sources section.

---

## TL;DR: the DD2 combat screen at 1920×1080

```
y=0    ┌─────────────────────────────────────────────────────────────────────────────────┐
       │▓▓▓▓▓▓▓ ragged black ink band ≈0–64 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  Round 1   ◆  ◆  ◆  ◆ │ label x≈1370–1540, y≈34
       │                              ╭FLAME╮                                         ∨ │ 4 portraits ≈80 px, x≈1560–1896
       │          ═══════════════════ │EMBLEM│ ═══════════════════  orange line y≈127   │ emblem ≈180 px, centred x=960
       │                              ╰─────╯                                           │
       │  [bark bubble]                                                                 │
       │     R4      R3      R2      R1                E1      E2       E3      E4      │ heads ≈ y300 (≈380 px tall)
       │    x≈255   x≈450   x≈650   x≈845             x≈1100  x≈1300   x≈1480  x≈1680  │ ground line ≈ y680
       │   ▱▱▱▱    ⟪▱▱▱⟫   ▱▱▱▱    ▱▱▱▱              ‹▱▱▱›   ‹▱▱▱›     …              │ HP bar ≈92×12 at y≈705
       │   ▪▪▪■■■□□□□                                                                   │ 10 stress pips, y≈725 (heroes)
       │     ⛨ ◈                                       ⛨ ☠                              │ tokens 22 px, y≈755; stack pips below
       │──────────── scene fades to black between y≈700 and y≈780 ───────────────────────│
       │ ✎ Audrey ────────────            Thrown Dagger                 Alpha Rot Claw ✎ │ y≈800–830
       │ DMG: 3-6  CRIT: 15%        ⚑ Ranged ⬢⬢⬢⬡ ⬡⬢⬢⬢                       Beastman │ y≈835–880
       │ Ignores ⛨              [▣][▣][▣][▣][▣]  ◇⟳  ◇✕              2⚡  0/102 ▬▬▬▬ │ icons 82 px, y≈866–948
       │ +50% CRIT when Target ☠      100%   1-2   16%               BLD BLGT BURN STN… │ preview y≈990–1040
       │                               HIT   DMG   CRIT               40   60   40  50  │
y=1080 └─────────────────────────────────────────────────────────────────────────────────┘
          left panel x 0–576            centre, on x = 960                right panel x 1344–1920
```

Key facts:
1. The battlefield takes the top ~70% and fades to plain black below the floor line. The HUD floats on that black with **no frame** — no box and no stone border. **(seen S1, S5, S9, S11, U4)**
2. At the top: the **Flame emblem** in the centre with a thin glowing orange line through it, and **"Round N" plus a turn-order queue of portraits** at the top right. **(seen)**
3. Under every unit: HP bar, then 10 stress pips (heroes only), then a token row. Unit names are **not** shown on the battlefield. **(seen)**
4. At the bottom: a left panel (hero name plus the **selected skill's** numbers), a centred skill bar (5 skills, then Swap and Pass diamonds), and a right panel for the **hovered enemy** (name, type, speed, HP and resistances). A HIT / DMG / CRIT preview sits under the skill bar. **(seen U4)**
5. Each action **cuts to a letterboxed close-up**. The HUD is hidden, the scene is colour-graded and ink-edged, and the skill name is shown in the bottom band. Pop-up numbers and words appear over the target. **(seen S2, S3, S10, U1–U5)**

---

# Part A: Darkest Dungeon II

## A1. Overall layout at 16:9

### Formation and scale
- **Heroes on the left, facing right. Enemies on the right, facing left.** Rank 1 on each side is nearest the centre. **(seen, all combat shots; wiki)** [W-CM2]
- **Slot centres in S1 (x):** heroes R4 ≈ 252, R3 ≈ 451, R2 ≈ 648, R1 ≈ 845. That is a pitch of **≈195–200 px**. Enemy centres were ≈ 1140 / 1416 (a size-2 unit) / 1680. Other shots put enemy R1 at ≈ 1100–1130. The gap between the hero R1 and enemy R1 centres is ≈ 260–300 px, so the two lines leave a visible empty strip around x = 960–1000. **(seen S1, S5, S9)**
- **Character height.** Human-sized heroes are ≈ **360–400 px from feet to head, about 35% of screen height**. Big enemies reach ≈ 430–470 px (≈ 40–43%). The ground line, where the feet are, sits at **y ≈ 680**. **(seen S1, S9)**
- **Size-2 enemies** stand centred over their two slots. Their HP bar is about **twice as wide** (≈ 200 px against ≈ 92 px). **(seen S1, S5)**
- Units overlap slightly and are not boxed into slots. Sprites are full 3D-rendered, ink-outlined figures. **(seen)**

### Background, foreground and vignette
- The background is a **3D painted environment** for each region: night forest, burning red city, sepia farmland, teal swamp. Each scene is strongly **colour-graded towards one hue**. **(seen S1, S5, S9, S11, U4)**
- **Foreground silhouettes** frame the stage: black branches and canopy along the top edge, fences, grass and plants in the bottom corners. **(seen S9, U4, S6)**
- The **top ≈ 50–70 px is a ragged black ink-brush band**. The round counter sits inside it. **(seen S9, S11)**
- The scene **fades to black** below the floor, from y ≈ 700 to 780. Everything below y ≈ 780 is a pure black HUD area. **(seen)**
- There is a soft dark **vignette** on the left and right edges. The tone is generally low-key, with light concentrated on the combatants. **(seen)**

### Top of the screen
- **Flame emblem, centred.** A spiked circular ring like a crown of thorns surrounds a torch or brazier with a yellow-orange flame. It is ≈ 170–180 px tall, spans y ≈ 30–210 and is centred on x = 960. **(seen S1, S5, S9, S11, U4)**
- **Orange glowing line** through the emblem at y ≈ 127. Its length differs between screenshots: about 900 px in S1 and about 450 px in S9. It is most likely the **Flame meter**, with length proportional to Flame (0–100), the same idea as DD1's torch bar. **(inferred from variation + DD1 precedent)** [W-FLAME]
- **"Round N"** sits at the top right (x ≈ 1370–1540, y ≈ 34). It uses grey blackletter-style display text with a cap height of about 28 px, and it is localised ("Runda 12", "回合 101"). **(seen S1, S5, U9)**
- **Turn-order queue.** To the right of the round label is a row of **diamond-framed face portraits** (≈ 80 px, x ≈ 1560–1896).
  - Each frame has a coloured chevron "roof": **gold for heroes, blue for enemies**.
  - The **rightmost portrait is the current actor** and has a **white "V" chevron under it**.
  - The queue **shrinks as the round goes on**. Round 1 shows 4 portraits partway through the round. S6 (Round 2) and U8 show only 2. **(seen)**
  - Reading: the queue lists the units still to act this round including the current one. The next actor is probably the portrait just left of the current one. **(inferred)**
  - Patch notes confirm an "Initiative order" display and fix bugs in it (it skipped ahead after skill use, and did not update after kills by combat items). **(patch)** [P-2025-SS2]
  - A community post also notes that DD2 shows turn order and DD1 does not. **(community)** [ST-TURN1]
- **Top-left corner.** In some fights a small emblem sits here: an orange sigil in U4, a red banner in S6 and U10. It is probably a Loathing or game-mode indicator. **(seen; meaning unknown)**

## A2. Per-character status display

Everything sits **under the unit's feet**, centred on the unit, in this order from top to bottom. **(seen S1, S5, S9, U4)**

| Row | y (centre) | Look |
|---|---|---|
| (DoT icons) | ≈ 650–670 | Small icons **above** the HP bar when a damage-over-time effect is active: red blood drop (Bleed), green ring (Blight), white skull (Horror). **(seen U4)** |
| HP bar | ≈ 705 | See below |
| Thin gold strip | ≈ 714 | A ≈ 4 px gold/dark line directly under the HP bar. It looks like a tiny label but cannot be read at 1080p. **(seen; meaning unknown)** |
| Stress pips | ≈ 725 | **Heroes only.** 10 pips |
| Token row | ≈ 755 | Token icons, centred, with stack pips underneath |

### HP bar
- **Shape:** a flat **trapezoid**, wider at the bottom, ≈ **92 × 12 px** (about 200 px for size-2). It has a **dark grey frame** (≈ #3A3A3A, 2–3 px), a **deep crimson fill** (≈ #8E1020) and **black** for lost HP. **(seen, zoomed S9)**
- **No numbers on the battlefield bar.** Numbers ("31/31", "46/46") appear on the bar only outside combat (Inn, rewards, pre-combat) and in the hovered-enemy panel ("16/16", "0/102"). **(seen S8, U7, U4, S4)**
- **Damage preview.** U4 shows a hero with DoTs whose bar has a bright red marker at the current-HP edge and **diagonal red hatching** over part of the lost portion. This probably previews pending DoT damage. **(seen U4; meaning inferred)** Patch notes mention heal and damage previews ("heal preview", "preview ... if the RNG picks 0 damage"). **(patch)** [P-2025-SS2]
- **Quarter notches.** Since v2.02 health bars have quarter lines. **(patch)** [P-2025-07] They do not appear in the older screenshots.
- **Buff and debuff markers beside the bar.**
  - A **gold double up-chevron (^^)** sits at the left end of some units' bars.
  - A **blue double down-chevron (vv)** sits at the right end of some heroes' bars.
  - They appear on both heroes and enemies. In Kingdoms fights every enemy has ^^. **(seen U4, S5, S6, S11)**
  - Reading: they summarise stat **buffs** (gold, up) and **debuffs** (blue, down), which are separate from tokens. **(inferred, fits DD2's gold = good / blue = bad convention)** [P-2025-07]

### Stress (0–10)
- **10 square pips in one row** under the HP bar, ≈ 77 px wide in total. **Pips 1–3 are small (≈ 5 px) and pips 4–10 are larger (≈ 8 px) with rounded corners.** Filled pips are **white**, empty pips **dark grey** (≈ #2E2E2E). **(seen, zoomed S9 and U4)**
- The size step after pip 3 lines up with DD2's negative banter, which starts at stress 4. **(inferred)** [darkest-dungeon-combat.md A9]
- Enemies have no stress row. **(seen)**
- The RPGFan review also describes "a stress bar below their health bar". **(community)** [RPGF]

### Tokens
- **Position:** a row **below the HP bar** (and below the stress pips for heroes). **(wiki + seen)** [W-CM2, W-TOK]
- **Size and stacking:** each token type is **one ≈ 22 px icon**, side by side with ≈ 6 px gaps, centred under the unit. Extra stacks are shown as **tiny white diamond pips under the icon**: "◆" or "◆◆". There is no number. **(seen S5, S6, U4)** Exactly what the pips count (stacks beyond the first, or all stacks) is **(unknown)**. One icon with no pips seems to mean a single stack. **(inferred)**
- **Colours:** "Positive tokens are yellow and Negative tokens are blue." **(wiki)** [W-TOK]
  - Seen in play: a gold shield (Block), a gold crescent (Dodge), a **blue crossed-out eye (Blind)**, a **blue sword with a down arrow** (a damage debuff) and a red skull (Death Armor or Death's Door on an enemy). **(seen S11, U4)**
  - Faction and class tokens use their own colours: orange "!!" (Beastmen), teal icons. **(seen S6, U4)**
  - v2.02 recoloured several tokens for consistency and made Stealth gold. **(patch)** [P-2025-07]
- **Targeting preview on tokens.** When an attack would consume a target's token, that token is boxed in a **gold square highlight**. In U4 the enemy's Block token is boxed and the preview reads "1-2 DMG". **(seen U4)** "Enabled highlights in previews for tokens that could be stolen or converted." **(patch)** [P-2025-SS2]
- **Rank-locked tokens** (Barnacles, Consecration) have an extra small icon under them. **(patch)** [P-2025-07]
- **Hover tooltip:** hovering a token or buff opens a small dark tooltip just above the row, for example "-20% [icon] resistance (1 Inn)". **(seen, Chinese-language player screenshot)** Tooltips show token durations since v2.02. **(patch)** [P-2025-07]

### Rank / position, active unit, acted markers
- **No rank numbers are drawn** on the battlefield. Rank is read from position. **(seen)**
- **Active hero:** a **gold double-ended "arrow-fletching" bracket** (a horizontal gold line with outward-pointing chevron tips) at the feet, just above the HP bar. It is ≈ 160 px wide and **wider than the HP bar**, with a warm **amber glow** filling the space above it, like a low pillar of light. **(seen S1, S5, S9, S11, U4)**
- **Active enemy:** not captured. Enemy turns hide the bottom HUD (U9). **(unknown)**
- **"Has acted this round":** there is **no per-unit marker**. The turn-order queue does this job. **(seen)**
- **Turns remaining for multi-turn enemies:** probably the same enemy appears more than once in the queue. S5's queue shows two similar boar faces. **(inferred)**

### Death's Door and corpses
- An **enemy at 0 HP** (Death's Door, kept alive by Death Armor) shows an **empty HP bar**, "0/102" in the enemy panel, and a red skull icon at the head of its token row. **(seen U4)** The wiki uses a skull "Deathblow" icon and `Token_deaths_door_armor.png` for these states. **(wiki)** [W-DD2]
- **Hero on Death's Door:** no screenshot found. What we know: the HP bar is empty, a Weak token and a −SPD debuff are added (rules doc A8), and the wiki has key art "A Plague Doctor on Death's Door". **(unknown visual)**
- **Corpses:** DD2 has corpses for heroes and enemies (rules doc A1). No screenshot of their look was found. **(unknown)**

## A3. The bottom HUD

The HUD is three groups on a black ground. Thin grey horizontal rules (1–2 px, tapered ends) are the only "frame". **(seen S1, S5, S9, U4)**

### Left: active hero panel (x ≈ 0–576, y ≈ 790–1000)
- **Header row (y ≈ 800–850):** a small **greyscale ink-sketch portrait** of the hero's head (≈ 110 × 60 px, fading into the black at the left), then the **hero's name** in **gold blackletter display type** (≈ 30–34 px). Thin horizontal rules run above and below. **(seen)**
- **No class or path, HP, stress or stats** here. HP and stress live only under the character. Full stats are in the character sheet, which can be opened mid-combat as a centred overlay (U8). That sheet shows class, path, Combat Skills grid, Resistances row, HP "15/60", stress "2/10", SPD, quirks and trinkets. **(seen S9, U8)**
- **Body (y ≈ 865–960):** with a skill selected, the panel lists **that skill's details** in white sans text (≈ 22 px, line height ≈ 29 px). Details are in A4. With no skill selected only the header shows. **(seen S1, S5, S9 vs U4)**

### Centre: skill bar (the whole row is centred on x = 960)
- **Skill name** is centred above the bar at y ≈ 800, in cream/white display type (≈ 28 px). If the skill is upgraded, a small **teal double-triangle badge** follows the name (see A4). **(seen)**
- **Tag + rank pips** at y ≈ 835: a small weapon icon and grey word ("Melee", "Ranged", or "Heal" since v2.02), then 8 hexagonal rank pips. **(seen; patch)** [P-2025-07]
- **A large thin-outlined diamond** (rotated square, grey, ≈ 480 px across) sits behind the name and pips, with its apex at y ≈ 746. It is purely decorative and the same motif frames the skill name in action close-ups. **(seen)**
- **Skill icons:** **5 square icons, ≈ 82 × 82 px, pitch ≈ 98 px, at y ≈ 866–948**, starting at x ≈ 619 in S1.
  - Each has a thin grey frame over a dark diagonal-crosshatch fill. The icon art is painted in muted colours.
  - Militia in Kingdoms have only 3 skills, and the row stays centred. **(seen S1, S6)**
  - Heroes equip 5 skills. **(rules doc A3)**
  - The order on the bar is the order the player picked them in. **(patch)** [P-2023-09-14]
- **Icon states:**

  | State | Look | Tag |
  |---|---|---|
  | Selected | **Gold L-shaped corner brackets** at the bottom-left and bottom-right corners | (seen S1, S5, U4) |
  | Not usable now (e.g. wrong rank) | Icon **desaturated and darkened** to near-grey | (seen S5, S11; reason inferred) |
  | On cooldown | Darkened icon with a **large white number in the centre** ("1", "2") = turns left | (seen S5, U10; meaning inferred) |
  | Limited uses per battle | Small white number in the **top-right corner** ("3") | (seen S1, S9) Confirmed by the wiki: Grave Robber *Absinthe* and *Dead of Night* have "Uses 3" [W-GR2] |
  | Blessed (positive relationship) | **Gold frame + gold sunburst rays** above the top edge | (seen S11, U10; meaning inferred from relationship screen U-rel) [W-REL] |
  | Cursed (negative relationship) | **Blue flame-like glow** above the icon | (seen S9; meaning inferred) |
  | Upgraded ("+") | Small **teal ▲▲ badge** centred under the icon | (seen U4; meaning inferred) |

- **Swap and Pass:** two **diamond buttons** (rotated squares, ≈ 96 px across the corners, grey bevel) right after the skills, at x ≈ 1159 and ≈ 1260 in S1.
  - **Swap** has two circular arrows. **Pass** has an "✕".
  - These match the always-equipped move and pass skills in the data (rules doc A3).
  - **(seen; mapping inferred from icons and the DD1 precedent)**
- **Combat items** appear **in the skill row at its right end**. An empty slot is a square with a "+". They are a free action. **(community)** [GR-ITEMS; rules doc A2] None of the screenshots I examined showed one. **(not seen)**
- **Hit / damage / crit preview** (only when an enemy is hovered with a skill selected):
  - Three centred columns under the bar, **number above label**: "100% / HIT", "1-2 / DMG", "16% / CRIT".
  - Cream display type, numbers ≈ 30 px and labels ≈ 26 px, at y ≈ 990–1040 and x ≈ 820 / 955 / 1090.
  - A soft **amber radial glow** sits behind them.
  - The numbers already include the target's tokens: 4–7 against a Block+ target showed as 1–2. **(seen U4)**
- During **enemy turns the left panel, skill bar and preview are hidden**. Only the decorative diamond outline stays. **(seen U9)**

### Right: hovered target panel (x ≈ 1344–1920, y ≈ 790–1040)
This panel mirrors the hero panel and appears when you hover an enemy. **(seen U4)**
- **Name** in **blue blackletter** (≈ 34 px), right-aligned (ends at x ≈ 1776), with a greyscale **sketch portrait** at the far right edge and thin rules above and below.
- **Type or faction** in grey ("Beastman"), right-aligned below the name. Champion enemies show a Champion tag (v2.02). **(patch)** [P-2025-07]
- **Stat line:** a speed value with a speed icon ("2"), then **HP "0/102"** with a thin bar.
- **Resistance row:** 6 columns with a pitch of ≈ 70 px. Each column is a **colour-coded abbreviation**, then an icon, then a value: BLD (red), BLGT (green), BURN (orange), STN (tan/yellow), MOV (violet), DBFF (blue). For example 40 / 60 / 40 / 50 / 30 / 30.
  - In U4 the **labels relevant to the selected skill are lit** (BLD red, DBFF blue) and the rest are greyed. **(seen U4; reason inferred)**
- A guide says resistances show "on the bottom right ... just by hovering" and that ALT opens a full inspect view. **(community, search excerpt only; the page itself returned 403)** [PGG]
- **Academic View (full enemy inspect, S4):**
  - A framed overlay with grey blackletter column headers "Skills", "Statuses" and "Resistances".
  - Skills are listed as name (blue) + tag + rank pips + "Target:" / "Self:" lines with icons. Unknown skills show as "???".
  - Statuses are listed as token icon + plain-language text ("50% chance to dodge next attack").
  - Resistances use the same colour-coded row.
  - The enemy is drawn large on the right, with a huge blue blackletter name and "16/16" plus an HP bar.
  - Since v2.02 it also shows ignores, requirements, speed and stress resistance. **(seen S4; patch)** [P-2025-07]

## A4. Skill details ("tooltips")

In DD2 the skill description is mostly the **persistent bottom HUD**, not a floating tooltip. It reads in this order **(seen S1, S5, U4)**:

1. **Skill name** (centre, cream display type), plus the **teal ▲▲ badge** if upgraded **(seen U4, U5, U6)**. Patch notes refer to upgraded skills as "Name+" and mention an "upgraded skill comparison" in hero tooltips. **(patch)** [P-2025-07]
2. **Tag:** weapon icon + "Melee" / "Ranged" / "Heal".
3. **8 hexagonal rank pips**, about 12 px each.
   - **First group of 4 = your own ranks, drawn rank 4 → rank 1 from left to right** (mirroring the formation). **Gold filled** means the skill can be used from that rank.
   - **Second group = target ranks, drawn rank 1 → 4.** **Blue filled** means that enemy rank can be targeted.
   - An **empty hex outline** means not valid.
   - A small gap separates the two groups. **(seen)**
   - Check against wiki data: *Thrown Dagger* shows ⬢⬢⬢⬡ ⬡⬢⬢⬢, which is from ranks 4–2 at ranks 2–4. *Lunge* shows the gold pips on the left, i.e. ranks 4–3. **(seen + wiki)** [W-GR2]
   - **Ally-targeting skills** use **green** target pips. **(patch: "missing green circles on certain skills which targets ally")** [P-2025-SS2]
   - **Multi-target** pips are **joined by a line**. **(community)** [ST-DOTS]
   - In the **Academic View for enemy skills** the launch pips are **red** (enemy side) and the target pips **gold** (hero side). **(seen S4)**
4. **Left panel, line 1:** "DMG: 3-6   CRIT: 15%" (white).
5. **Effect lines** with inline icons:
   - "Target: [Bleed icon] **3** (3 Turns)". The label "Target:" is **blue**. DoT amounts are **red or orange** with the DoT icon, and the duration "(3 Turns)" is white.
   - "Random Adjacent Enemy: …".
   - "Self: …". In the Academic View this label is gold.
   - **(seen S5, U4, S4)**
6. **Modifiers and conditions:** "Ignores [token icon]", "Ignores [Stealth icon] when Self [icon]", "+50% CRIT when Target [icon]". The conditional bonus line is a **pale green**. **(seen S1)**
   - Since v2.02, condition text reads as "EFFECT when Flame is under 50" instead of operator symbols. **(patch)** [P-2025-07]
7. **Cooldown and uses** show on the icon (A3). The Academic View now lists hero cooldowns, uses and conditions. **(patch)** [P-2025-07] Their wording in the skill text is **(unknown)**.

Colour convention: Red Hook speaks of a "gold/blue paradigm" (gold = good or increase, blue = bad or decrease) when fixing tooltip colours. **(patch)** [P-2025-07]

## A5. Targeting

- **Valid enemy targets:** when a skill is selected, every valid enemy gets a **blue horizontal bracket line just above its HP bar**. The line has **forked chevron tips at both ends**, extends ≈ 25–40 px past the HP bar on each side and covers both slots of a size-2 unit. **Invalid enemies get no bracket.** **(seen S1, S5, S6)**
- **Hovered target:**
  - A **translucent blue box** (light steel-blue fill at ≈ 30–40% opacity, rounded upper corners) rises from the bracket to about 60% of the unit's height and covers its legs and torso.
  - A **brighter blue rim** runs along the bottom, and the forked bracket tips grow into the box's lower corners.
  - In U4 a small green eye icon sits in the box (meaning **unknown**).
  - The bottom-right enemy panel and the HIT/DMG/CRIT preview appear at the same time. **(seen U4)**
- **A grey or white bracket** appeared on one enemy in S5 while the others were blue. It may mark the keyboard-focused target, or a target the skill hits only as a secondary ("Random Adjacent Enemy"). **(seen; meaning unknown)**
- **Ally targeting** (heals, guards, swap): not captured. Gold is the hero colour and green is the ally-pip colour, so gold or green brackets on allies would be consistent. **(inferred)**
- **Multi-target skills:** every target gets a bracket. Whether hovering one highlights all of them is **(unknown)**. DD1 links them; see Part B.
- **Tokens the attack will consume** on the target get a gold square highlight (A2). **(seen U4)**

## A6. Action presentation

### Camera and staging
- **Damaging actions cut to a separate close-up shot.** This is not a zoom of the battlefield. **(seen S2, S3, S10, U1, U2, U3, U5)**
  - **All HUD is hidden.** No HP bars, skill bar, queue or Flame emblem.
  - The frame is **letterboxed**: a black ragged ink band ≈ 60–70 px at the top, and a black band ≈ 280 px tall at the bottom (y ≈ 800–1080).
  - The **skill name** is centred in the bottom band at y ≈ 905, in **gold blackletter (≈ 40–45 px)**, under the apex of the same thin diamond outline.
  - The background is **monochrome-graded** (sepia brown, blood red or cold blue, depending on the scene), with **black ink-splatter vignetting** that is heaviest on the right edge.
- **Poses:** the attacker and target(s) are drawn at **≈ 1.5× battlefield scale (≈ 550–650 px tall, ≈ 55% of screen height)**, mid-action and facing each other. Heroes stay on the left and enemies on the right, even on enemy turns (S3). Other units are removed. Multi-target skills show all targets (U1). A riposte shows the relevant heroes (U2). **(seen)**
- **VFX:** motion streaks, slash arcs, sparks and blood. Heals show vertical green light beams on the target (U5). **(seen)**
- **Party-wide or self heals can play without the cut.** U6 shows *Deathless* in the normal battlefield view with HP bars visible and the skill name at the bottom centre. **(seen U6; generalisation inferred)**
- **Timing:** not measurable from stills. There is a 1.5× combat speed option, and "in-combat cinematics (boss intros, deaths, resolve checks)" always run at 1×. **(patch)** [P-2025-07] Durations are **(unknown)**. The checklist gives suggested values.
- **Screen shake, impact freeze, dimming:** not determinable from stills. **(unknown)**

### Floating pop-ups (all over the target's head in the close-up)

| Event | Look | Tag |
|---|---|---|
| Damage | **Red number**, heavy angular display digits, ≈ 48 px, thin dark outline | (seen S2, S10) |
| Damage reduced by Block | **White/grey number with a strike-through, then the red final number** beside it (6 → 3, 16 → 8: both exactly −50%) | (seen S3, U3; meaning inferred) |
| Crit with damage | **"Critical!"** small orange italic-style label (≈ 30 px) **above an orange number** (≈ 70–90 px) | (seen U2, U3) |
| Crit without damage | **"CRIT!"** large orange blackletter (≈ 100 px) | (seen U1) |
| Dodge | **"Dodge"** in large light-grey display type (≈ 75 px) with a dark outline | (seen U1) |
| Status or special | Icon + text in orange-red, e.g. "[broken-shield icon] Armor Break!" | (seen U2) |
| Heal | **Green "+" icon + green number**. A crit heal adds a green "Critical!" | (seen U5, U6) |
| Trinket damage | The trinket's name is shown beside the damage value | (patch) [P-2025-07] |
| Meltdown | The word "Meltdown!" on screen | (community) [RPGF] |
| Resist, miss, stress change, DoT tick | not captured | (unknown) |

### Barks, narration and big titles
- **Hero barks:** a **speech bubble above and slightly beside the speaker's head**.
  - The box is near-black navy with a thin light steel-grey border and slightly irregular, skewed edges. A tail points down at the speaker.
  - Text is **white italic serif** (≈ 22 px), centred, 1–2 lines, for example "What know you of hardship?!". The box is ≈ 275 × 150 px.
  - Barks appear on the normal battlefield view and the HUD stays visible. **(seen S9, S7)**
- **Alarm bubbles:** small "!" speech bubbles over heroes when an encounter starts. **(seen U7)**
- **Narrator subtitles:** a single line of **cream or gold italic text centred near the top**, just under the Flame emblem, sometimes on a dark translucent band. **(seen U6, U11)**
- **Encounter title:** before combat, the enemy group's name appears as a **large grey blackletter title** ("Plague Eaters!") at the bottom right of the stage, with a prompt line underneath. **(seen U7)**
- **Relationship act-outs:** full-screen card with two heroes in front of a glowing moon disc and the relationship name ("Respectful", "Amorous") in huge cream blackletter. **(seen S3-rel, U-rel)**
- **Boss cinematics:** desaturated to greyscale with a heavy vignette. **(seen U11)**

## A7. Fonts, frames and palette

- **Display type** (names, skill names, "Round", headers, pop-up words): a **blackletter-influenced gothic display face**. It has broken strokes and angular serifs but reads cleanly, like a "gothic book" style rather than full Fraktur. It is used in **gold** for heroes and positive things, **steel blue** for enemies, **grey** for headings and **cream** for skill names. **(seen)**
  - The DD1 logo font is identified by players as Blambot's **Dwarven Axe BB**. **(community)** [FONT1]
  - The DD2 UI typeface name is **(unknown)**.
- **Body type** (stats, descriptions): a clean humanist sans in white or light grey, ≈ 22 px at 1080p. Barks and narration use an **italic serif**. **(seen)** v2.02 made the default PC font slightly smaller and added a "Larger Font Size" option. **(patch)** [P-2025-07]
- **Frames:** deliberately minimal. **(seen)**
  - Thin grey rules with tapered ends.
  - **Diamonds everywhere**: turn portraits, Swap/Pass, the big outline behind the skill name.
  - Square skill frames with crosshatch fill, and **gold L-corners** for selection.
  - Hexagonal rank pips.
  - Overlays (Academic View, character sheet) use a thin grey border with small notched corner ornaments.
  - There is no heavy carved frame like DD1's.
- **Palette** (sampled by eye; approximate):

  | Role | Colour |
  |---|---|
  | HUD ground | #000000 to #0D0D0D |
  | Hero, positive, launch pips | gold ≈ #C9A66B (name) to #D8B878 (brackets) |
  | Enemy, negative, target pips | steel blue ≈ #4C78B5 |
  | HP fill / lost HP / frame | ≈ #8E1020 / #050505 / #3A3A3A |
  | Stress pips | filled #F0F0F0, empty #2E2E2E |
  | Flame, crit | orange ≈ #F08A24 |
  | Damage numbers | red ≈ #D9262E |
  | Heals, ally pips | green ≈ #4CCB7A |
  | Upgrade badge | teal ≈ #3FA7A0 |
  | Resist labels | BLD #C0282D, BLGT #3E8F4F, BURN #D9622B, STN #C8A050, MOV #6A5FB0, DBFF #4C86C8 |

## A8. Could not confirm (DD2)

1. Exact meaning of the **token stack pips** (all stacks, or stacks beyond one).
2. The **active-enemy marker** during enemy turns, and whether enemy turns also use the letterboxed close-up. Most likely yes, since S3 is an enemy skill.
3. **Hero Death's Door** visuals and **corpse** visuals.
4. **Ally-targeting** bracket colour, and whether **multi-target hovering** links targets.
5. Pop-ups for **resist, miss, stress, DoT ticks and status application**.
6. **Animation timings**, camera move curves and screen shake.
7. The **gold strip under the HP bar**, the **grey enemy bracket** (S5) and the **green eye** in the hover box (U4).
8. The display **font name**.
9. Whether a **combat log** exists. None was seen and no source mentions one.

---

# Part B: Darkest Dungeon 1 comparison (short)

Sources: DD1 Steam store screenshots D1, D2, D3 **(seen)** and Steam community threads.

| Topic | DD1 | DD2 |
|---|---|---|
| Screen split | Battlefield in the top ≈ 65% (to y ≈ 700). **HUD in the bottom ≈ 35% inside a heavy carved-stone frame** with statues at both ends. **(seen D1)** | Scene ≈ 70%, HUD floats on black with no frame |
| Bottom HUD content | **Left:** hero portrait, gold name, class, **4 skills + Move**, numbered 1–5, plus a narrow "X" pass button. Below that, **HP "20.0 / 20.0" (red), stress "10.0 / 100"**, ACC, CRIT, DMG, DODGE, PROT, SPD, and trinket slots. **Right:** dungeon map and inventory. Hovering an enemy with a skill selected shows hit chance, damage and crit "on the bottom panel, far right". **(seen D1; community)** [ST-HOVER1] | Left = name + skill numbers only; right = hovered enemy; preview under the skill bar |
| Top | Torch emblem in the centre with a **long horizontal light meter with tick marks**; quest text at the top left. **(seen D1, D3)** | Flame emblem + thin glowing line; round counter + **turn-order queue** |
| Turn order | **None shown.** Units yet to act this round carry small **vertical white lines** on the GUI. **(community)** [ST-TURN1] | Portrait queue, current actor rightmost |
| Under-unit status | Thin flat red HP bar (≈ 100 px) and a **10-segment stress bar** (each segment = 10 of 100/200 stress) | Trapezoid HP bar, 10 stress pips (0–10), token row |
| Status effects | Separate buffs, debuffs and statuses as small icons near the unit | Capped **tokens** in one row, gold or blue |
| Rank dots | Circles: **yellow = launch, red = target**. **(community)** [ST-HOVER1] | Hexes: gold = launch, **blue** = target, green = ally |
| Target markers | **Red floor brackets** (posts at both ends, a spike in the middle) under each valid enemy. The active hero gets a gold floor bracket. **(seen D1)** | Blue forked line over the HP bar; translucent blue box on hover |
| Action shot | **In-place zoom**: attacker and target enlarged in front, the others **dimmed and blurred** behind. **The HUD stays visible.** Big red number on a blood splat. **(seen D2)** | Cut to a letterboxed, colour-graded close-up; HUD hidden; skill name in the bottom band |
| Enemy turn cue | A big red skull-and-crossed-blades emblem over one enemy. **(seen D3; meaning inferred)** | (unknown) |

---

# Implementation checklist (1920×1080 Godot, placeholder art)

This maps the findings onto the existing UI (`src/ui/combat_screen.tscn`, `combat_screen.gd`, `unit_view.gd`, `skill_button.gd`, `ui_style.gd`, `combat_log.gd`) and the existing placeholder art (`art/tokens/*.svg`, `art/skills/*.svg`, `art/backgrounds/ruined_road.svg`, `art/fonts/gelasio`). Pixel values come from the measurements above. Items marked *(inferred)* fill gaps where DD2 could not be confirmed. The core must not change. All of this is presentation of existing events.

## P0: layout skeleton (do first)

1. **Screen zones.**
   - 0–64: black ragged top band. A placeholder can be a black `ColorRect` with a jagged polygon bottom edge.
   - 64–740: the stage, using the background art.
   - 700–780: a vertical gradient from the stage to **pure black**.
   - 780–1080: HUD on black with **no panel frames or boxes**. Separate the HUD groups only with 1–2 px grey (#555, 60% alpha) horizontal rules that fade at the ends.
2. **Formation slots.** Ground line at y = 680, slot pitch 196 px, heroes facing right with rank 1 nearest the centre:
   - Hero centres: R1 845, R2 650, R3 455, R4 260.
   - Enemy centres (mirrored, slightly wider gap): R1 1090, R2 1285, R3 1480, R4 1675.
   - A size-2 enemy centres between its two slots.
   - Scale placeholder figures to **≈ 380 px tall** (≈ 35% of 1080), up to ≈ 460 px for the Brute.
   - Add a soft side vignette (both edges darkened about 40%) and one or two black foreground silhouettes in the bottom corners.
3. **Per-unit status stack under the feet,** centred on the unit, top to bottom:
   - (a) DoT icons (Bleed, Blight, Burn) at y ≈ 660, 18 px, **above** the HP bar.
   - (b) **HP bar** 92 × 12 trapezoid at y ≈ 705: frame #3A3A3A 2 px, fill #8E1020, empty #050505. 200 px wide for size-2. **No numbers.** Add **quarter notches** (current DD2).
   - (c) **Stress** (heroes only) at y ≈ 725: 10 pips in one row, 3 small (5 px) + 7 large (8 px, rounded), white when filled and #2E2E2E when empty.
   - (d) **Token row** at y ≈ 755: 22 px icons, 6 px gap, centred. Tint the frame or icon **gold for positive and steel blue for negative**. Show stacks as tiny white diamonds under the icon (one diamond per stack beyond the first, *(inferred)*), not as numbers.
   - (e) Buff and debuff summary: gold "^^" at the left end and blue "vv" at the right end of the HP bar when the unit has stat buffs or debuffs *(inferred)*.
4. **Remove unit names from the battlefield.** DD2 shows names only in the bottom panels and tooltips. This changes the current design note "Units show ... name". Keep hover tooltips.
5. **Active-unit marker:** replace any current highlight with a gold forked bracket (a horizontal line with outward chevron tips, 160 × 6 px plus the tips) just above the HP bar, with an **amber gradient glow** rising ~60 px above it (additive, ≈ 35% opacity at the bottom fading to 0).
6. **Top bar:**
   - A **placeholder emblem** centred at (960, 120), ≈ 170 px: a spiked ring with a flame glyph.
   - **"Round N"** at the top right (right-aligned to x ≈ 1540, y ≈ 34, grey display font, 28 px).
   - A **turn-order queue**: 80 px diamond portraits from x ≈ 1560 to 1896, **current actor rightmost** with a white "V" under it, units still to act this round extending leftward. The chevron cap is gold for heroes and blue for enemies. Drop portraits as units act. A multi-turn enemy appears once per turn.
   - The orange Flame line is optional while v0 has no Flame. Either omit it or keep the emblem purely decorative.
7. **Bottom HUD, three groups:**
   - **Left (x 0–576):** an 110 × 60 greyscale placeholder head plus the **hero name in gold display type (32 px)** at y ≈ 823, with rules at y ≈ 792 and 852. Below it, from y ≈ 865 with 29 px lines, show the selected skill's text (see P1 item 10).
   - **Centre:**
     - Skill name (cream, 28 px) centred at (960, 800).
     - Tag + 8 rank pips at y ≈ 835.
     - **5 skill squares 82 × 82, pitch 98, y 866–948**, then **Swap and Pass as 96 px diamonds**. Centre the whole row on x = 960. Keep Recover in the row when it is valid.
     - A thin grey diamond outline (≈ 480 px wide, apex at (960, 746)) behind the name.
   - **Right (x 1344–1920):** hovered-enemy panel. Blue display name (32 px) right-aligned to x ≈ 1776, type line in grey, "SPD n" + "HP cur/max" with a thin bar, then a **6-column resist row** (BLD, BLGT, BURN, STN, MOV, DBFF): colour label, icon, value, pitch 70 px.
   - Hide the left panel, skill bar and preview during enemy turns.

## P1: targeting, skill states, preview, action shot

8. **Skill icon states** (`skill_button.gd`):
   - Selected: gold L-corners on the bottom corners.
   - Unusable: desaturate and darken to 35% brightness.
   - Cooldown: darkened, with a big centred white number.
   - Per-battle uses (Rally, "once per battle"): a small number in the top-right corner.
   - Later, when skill upgrades exist: a teal "▲▲" badge for upgraded skills, and gold sunburst or blue glow for blessed and cursed skills.
9. **Rank pips:** 8 hexagons (12 px).
   - First group = own ranks **drawn 4 → 1**, gold if usable from there.
   - Second group = **enemy ranks 1 → 4**, blue if targetable.
   - Otherwise draw an empty outline.
   - For ally-target skills draw the second group in **green** over ally ranks.
   - **Join multi-target pips with a line** ("1+2" skills such as Cleave and Volley).
10. **Skill text in the left panel,** in DD2 order:
    - "DMG: a-b  CRIT: c%".
    - Then "Target:" (blue label) / "Self:" (gold label) lines with inline token and DoT icons. Write DoT amounts in red or orange plus "(3 Turns)".
    - Then conditional lines ("+50% DMG when Target has Combo") in pale green.
    - Then "Ignores …" lines.
    - Put cooldown and uses on the icon, not in the text.
11. **Targeting markers:**
    - Valid enemy: a **blue forked bracket line** just above its HP bar, ≈ 30 px wider than the bar on each side.
    - Hovered or focused target: a **translucent blue box** (≈ #4C78B5 at 30% alpha, brighter 3 px bottom rim) from the bracket up to 60% of the unit's height.
    - Allies: the same in gold or green *(inferred)*.
    - Multi-target: bracket all targets and box all of them on hover *(inferred)*.
    - Keyboard focus uses the same box.
12. **Preview under the skill bar** (replaces the current info-panel preview): three columns "HIT / DMG / CRIT" (number above label, cream, numbers 30 px) at y ≈ 990–1040, centred on x = 960, with a soft amber radial glow behind.
    - The numbers must include the target's tokens: Block, Block+, Vulnerable, attacker Strength or Weak, Blind and Dodge in HIT.
    - Draw a gold highlight square around each target token the attack would consume.
    - Light up the resist labels in the enemy panel that the skill's effects test.
13. **Action close-up** (replaces the current close-up):
    - Hide the HUD, top band and status stacks.
    - Letterbox to a black top band (64 px, ragged) and bottom band (y 800–1080). Show the **skill name in gold display type (44 px) at (960, 905)** under the diamond apex.
    - Desaturate and tint the stage (multiply with one hue per scene). Add black ink-splat vignettes on the outer edges.
    - Re-stage the actor and target(s) at **≈ 1.5× scale (≈ 580 px tall)**: hero side around x ≈ 620, enemy side around x ≈ 1300. Heroes always left. Show every target of a multi-target skill. Drop non-participants.
    - Suggested timing *(inferred)*:

      | Step | Time |
      |---|---|
      | Cut in | 0.15 s |
      | Attacker lunge | 0.25 s |
      | Impact, with a 2–4 px, 0.15 s shake on crits | — |
      | Hold | 0.8 s |
      | Cut back | 0.2 s |

      Total about 1.4–1.6 s at 1×. Keep the existing 2× toggle (DD2 offers 1.5×). Never speed up boss, death or Meltdown/Resolute moments.
    - Self- and party-only heals or buffs play on the normal battlefield view without the cut *(inferred from U6)*.
14. **Pop-up styles** (all rise ~40 px and fade over ~1.0 s, dark 3 px outline):

    | Pop-up | Style |
    |---|---|
    | Damage | red #D9262E, 48 px |
    | Blocked damage | struck-through white original, then red final |
    | Crit | small orange "Critical!" over an orange number (72 px); "CRIT!" alone (100 px) for non-damaging crits |
    | Heal | green "+" icon + number |
    | Dodge, miss, resist | light grey word, 64 px |
    | Status applied | token icon + name in its polarity colour *(inferred)* |
    | Stress | white "+N" or "−N" with a stress glyph *(inferred)* |

    Stagger several pop-ups on one target vertically.
15. **Barks:** a near-black navy bubble (#0B0E14, 90%) with a 2 px steel-grey border, slightly skewed corners and a tail down to the speaker's head. White italic serif text (Gelasio Italic, 22 px), max width 280 px, shown ~2.5 s above the speaker on the battlefield view. Use them for Death's Door entry, kills, Meltdown and Resolute. "!" bubbles at fight start.

## P2: polish and secondary screens

16. **Fonts:** keep **Gelasio** for body and italic text. Add one free OFL **blackletter-ish display face** for names, skill names, "Round" and pop-up words, for example Grenze Gotisch or Pirata One from Google Fonts *(suggestion)*. Use one font size scale: 44 / 32 / 28 / 22 px.
17. **Colour tokens in `ui_style.gd`:** gold #C9A66B, blue #4C78B5, HP #8E1020, stress #F0F0F0 / #2E2E2E, crit and flame #F08A24, damage #D9262E, heal #4CCB7A, teal #3FA7A0, plus the six resist colours.
18. **Enemy inspect overlay** (Academic View style) on right-click or ALT. Columns: Skills (name + pips + Target/Self lines), Statuses (token + plain text), Resistances. Show the enemy large on the right with its name in big blue type and HP.
19. **Character sheet overlay** on hero right-click mid-combat. Keep the turn queue visible.
20. **Death's Door and corpses** *(DD2 look unknown; suggestion)*:
    - On Death's Door: empty HP bar with a slow red pulse on its frame, a skull icon at the head of the token row, and a "Death's Door!" pop-up on entry.
    - Corpse: a darkened, desaturated placeholder lowered ~20 px, with the HP bar fill in brown-grey and no stress or tokens.
21. **Encounter intro:** a big grey display-font title with the wave name ("Ghoul Pack!") at the bottom right of the stage for ~1.5 s before Round 1.
22. **Narrator line slot:** one centred italic line under the top emblem, for wave start and end.
23. **Combat log:** DD2 shows none. Keep ours behind the L toggle, **hidden by default**, as a dev overlay.

---

# Sources

### Screenshots examined (primary visual evidence)
- [S-store] Steam store page, *Darkest Dungeon II*: https://store.steampowered.com/app/1940340/Darkest_Dungeon_II/ . Full-resolution images follow the pattern `https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1940340/ss_<id>.1920x1080.jpg`:
  - S1 `bc4c7aec5704ed4108a181ec9a790c3fea4a9f12`
  - S2 `254e72f3356e62496b02c1faf7852bb5053e0338`
  - S3 `e25bc022fa98e7b235eb7146a3e54507893f3ab0`
  - S4 `e45a78cf2c30c0bea63cd7db9c17782cabf82a16`
  - S5 `fed764604bcb367ccd2411c9540b8754c21e8090`
  - S6 `e5f532902ce528340bce0735f16a8816f56182d9`
  - S7 `ea2afe87f9ea89ee9816b3eef48e7eac51f60e13`
  - S8 `d9ace881030b51b9f405198111df391f4573d092`
  - S3-rel (relationship card) `19b4a3415f5c4167121cb2acd12b7d6d90555e2c`
- [S-press] Red Hook DD2 media page: https://www.darkestdungeon.com/darkest-dungeon-2/media
  - S9: https://img2.storyblok.com/f/127947/3840x2160/96d1acc4d1/dd2-screenshots-combat-foetor-4k.png
  - S10: https://img2.storyblok.com/f/127947/3840x2160/4f9de926f0/dd2-screenshots-combat-wickedstab-4k.png
  - S11: https://img2.storyblok.com/f/127947/3840x2160/93d6283911/dd2-screenshots-combat-sprawl-4k.png
- [U] Steam Community player screenshots (search pages under https://steamcommunity.com/app/1940340/screenshots/):
  - U1: https://images.steamusercontent.com/ugc/9223515235866686751/A57CEFADB182155E7D9435A575C57BDD6C8861A3/
  - U2: https://images.steamusercontent.com/ugc/2272694181277407393/58B7398F865214593F9E2AAF7FE1552AA112EE17/
  - U3: https://images.steamusercontent.com/ugc/2493380238617375738/F1B7B3EA5510C05227EB9676B998ABF5761026ED/
  - U4: https://images.steamusercontent.com/ugc/18680076979733098/9917E346EE8754EEECFA45E752DE344906DA86A9/
  - U5: https://images.steamusercontent.com/ugc/2026103328090827438/620ABB2129E22678DDD5BEA0DD57D4C0BE86FC33/
  - U6: https://images.steamusercontent.com/ugc/2290709224094340899/7BA103A11C168B87B4E33458750BCC32B3B37BFD/
  - U7: https://images.steamusercontent.com/ugc/14167502345982890/94FFF105838AED39AB3622C10B7724B7CBE4301C/
  - U8: https://images.steamusercontent.com/ugc/2350385077320260999/1BDE20D0036E63AD4D9227C816057709D5F1AEF5/
  - U9: https://images.steamusercontent.com/ugc/2459621195378676725/8278C6283B67A694302597E8D870CBEBD02EE2F1/
  - U10: https://images.steamusercontent.com/ugc/10552338056171852510/BF6C4DBA4A03AA7A85888E22A69B3AD66B3AE2CE/
  - U11: https://images.steamusercontent.com/ugc/2038495579069252868/5EA96C5060499E51AA20A81810A9D94692BC07AC/
  - U-rel (relationship skill blessings): https://images.steamusercontent.com/ugc/2297466512921726547/B0F40082E6CDD7648DEAB5CF1D51921B8892FB13/
  - Token-tooltip example (Chinese build): https://images.steamusercontent.com/ugc/2062138842867441493/A7E17A1DC798C388F7CF4E5376FB04D4154725B7/
- [D1-store] Steam store page, *Darkest Dungeon*: https://store.steampowered.com/app/262060/Darkest_Dungeon/ . Same URL pattern with app 262060:
  - D1 `04572edc979601b038756f87861c6f8c6c337806`
  - D2 `ac1f594bf8128e376ca95ff266d400d404b639bf`
  - D3 `c9d41e74d574f6fa9bf53c0cf74f8430c2072cc2`

### Patch notes (Red Hook)
- [P-2025-07] *Steadfast Stewards* (v2.02), UI section: https://darkestdungeon.wiki.gg/wiki/Steadfast_Stewards_Retail_Release (also summarised at https://www.rpgsite.net/news/17938-darkest-dungeon-ii-steadfast-stewards-update-patch-notes-pc-mac-ps5-switch-xbox-later)
- [P-2025-SS2] *Steadfast Steward's Update Pt 2* (consoles, Nov 2025): initiative order fixes, green ally circles, heal preview, token highlight in previews: https://www.darkestdungeon.com/patch-notes/
- [P-2023-09-14] Skill bar order = selection order: https://darkestdungeon.wiki.gg/wiki/14_September_2023_Patch
- Patch index: https://darkestdungeon.wiki.gg/wiki/Patch_notes_(Darkest_Dungeon_II)

### Wikis
- [W-CM2] https://darkestdungeon.wiki.gg/wiki/Combat_Mechanics_(Darkest_Dungeon_II) (tokens below the health bar; rank icons)
- [W-TOK] https://darkestdungeon.wiki.gg/wiki/Tokens ("Positive tokens are yellow and Negative tokens are blue"; stack limits)
- [W-DD2] https://darkestdungeon.wiki.gg/wiki/Death%27s_Door_(Darkest_Dungeon_II) (icon file names)
- [W-STRESS2] https://darkestdungeon.wiki.gg/wiki/Stress_(Darkest_Dungeon_II) (0–10 scale; meltdown images)
- [W-GR2] https://darkestdungeon.wiki.gg/wiki/Grave_Robber_(Darkest_Dungeon_II) (rank grids; *Absinthe* and *Dead of Night* "Uses 3")
- [W-REL] https://darkestdungeon.wiki.gg/wiki/Relationships (blessed and cursed skills)
- [W-FLAME] https://darkestdungeon.wiki.gg/wiki/Flame
- Health bar (DD1): https://darkestdungeon.wiki.gg/wiki/Health_Bar

### Community, reviews and guides
- [ST-DOTS] "What is the Yellow / Blue balls/Circles??" (DD2 rank pips; a joining line = multi-target): https://steamcommunity.com/app/1940340/discussions/0/6741370072203302313
- [ST-TURN1] "Turn order..." (DD1 white lines for units yet to act; DD2 shows turn order): https://steamcommunity.com/app/262060/discussions/0/594009924939353219
- [ST-HOVER1] "How exactly do you find out what each ability does?" (DD1 hover preview on the bottom panel's far right; yellow and red dots; torch meter at the top): https://steamcommunity.com/app/262060/discussions/0/412447613581265645
- DD1 turn-order discussion: https://steamcommunity.com/app/262060/discussions/0/612823460276360397
- [GR-ITEMS] Game Rant, combat items "always appear at the right end of that row": https://gamerant.com/darkest-dungeon-2-how-to-use-combat-items-equip/
- [RPGF] RPGFan review (stress bar below the health bar; "Meltdown!" on screen): https://www.rpgfan.com/review/darkest-dungeon-ii/
- [PGG] ProGameGuides beginner tips (resistances bottom right on hover; ALT to inspect). Seen only as a search excerpt because the page returned 403: https://progameguides.com/darkest-dungeon-2/darkest-dungeon-2-beginner-tips/
- [FONT1] DD1 logo font = Dwarven Axe BB (player identification): https://steamcommunity.com/app/262060/discussions/0/612823460268981859
- GamePressure, DD1 vs DD2 differences (5 skill slots instead of 4; tokens replace modifiers): https://www.gamepressure.com/darkest-dungeon-ii/differences-between-dd1-vs-dd2/zbf03b
- Turn Based Lovers review (tokens as the main status display): https://turnbasedlovers.com/review/darkest-dungeon-ii-review
- TUNI Playlab review: https://blogs.tuni.fi/playlab/game-reviews/the-way-is-lit-we-require-only-the-strength-to-follow-it-darkest-dungeon-iis-bigger-badder-apocalypse/
- The Spriters Resource lists a DD2 "Turn Order Icons" sheet, which corroborates the queue. The page itself returned 403: https://www.spriters-resource.com/pc_computer/darkestdungeon2/asset/213374/
