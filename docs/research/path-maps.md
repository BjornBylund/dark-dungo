# Path maps: Darkest Dungeon 2 and Slay the Spire

How the two games turn a trip into a map of branching choices, for designing darko-dungo's mission maps. Facts are marked with their source; anything else is marked **unconfirmed**.

## Slay the Spire (2019)

### Shape

- An act is a map of **15 floors** plus the boss, with up to **six rooms per floor** in a rough row. (wiki)
- Most rooms have **1–3 paths in and 1–3 paths out**. You may start in any floor-1 room. (wiki)
- **Generation** (community reverse-engineering, not confirmed against code): a 7-column × 15-floor grid. Pick a floor-1 room at random and walk upwards, each step moving to one of the 3 nearest rooms on the next floor. Repeat for **6 walks**. The first two walks must start in different rooms, and paths may not cross. Rooms no walk touched are removed. (kosgames guide)

### Fixed floors (Act 1)

| Floor | Room |
|---|---|
| 1 | Normal combat (easy pool) |
| 9 | Treasure |
| 15 | Rest site |
| 16 | Act boss; every route leads to it |
| 17 | Boss chest (not drawn on the map) |

(wiki)

### Room types

| Type | Base share |
|---|---|
| Normal combat | 53% |
| Unknown (?) | 22% |
| Rest site | 12% |
| Elite combat | 8% |
| Merchant | 5% |

- From Ascension 1, elites are about 60% more common (8% → 16%, taken from normal combat). (wiki; kosgames)
- **Placement rules** (community, unconfirmed against code). When a rule is broken the room is re-rolled:
  1. No elite or rest site below floor 6.
  2. Elite, merchant and rest site rooms can't follow each other on a path. Read literally, that means none of the three directly after any of the three. Players usually describe it as no two of the *same* one in a row; **unconfirmed** which is right.
  3. A room with several exits leads to rooms of different types.
  4. No rest site on floor 14, since floor 15 is all rest sites.
- **Unknown rooms** are decided when entered: an event, a combat, a merchant or a treasure. Each time a type comes up its chance drops back to its baseline and the others' chances rise, so long droughts are rare. The exact numbers are **unconfirmed**. (wiki)
- **Rest site:** heal 30% of max HP, or upgrade a card. **Unconfirmed**; this is from memory of the game, not a source here.

## Darkest Dungeon II (2023)

### Shape

- A run crosses several **regions**, each a map of **nodes joined by roads**. You drive the stagecoach from node to node, choosing at forks. (wiki)
- Each main region ends with **Oblivion's Rampart**, then an **Inn** to recover and resupply. (wiki)
- Region modifiers change the map, e.g. **Maze** +200% path choices, **Trench Run** −50% path choices. (wiki)
- Node and road counts per region are not documented: **unconfirmed**.

### Roads

Five types; all but one have a hazard. (wiki)

| Road | Effect |
|---|---|
| Safe | Nothing |
| Combat | A road battle |
| Hazardous | −1 Armor; with no Armor left, an ambush |
| Rough | −1 Wheel; with no Wheel left, an ambush |
| Oblivion Tear | +1 Loathing |

### Nodes

| Node | What happens |
|---|---|
| Battles (e.g. cultist encounters) | A fight |
| **Creature Den** | A **two-wave** fight against the region's creatures. Guaranteed in the Foetor and the Tangle. (wiki) |
| **Lair** | The region's boss: **up to 3 battles, the last against the boss**. Optional; you may leave after any battle, and rewards grow with each one won. Always scouted. (wiki) |
| **Academic's Study** | A scene with choices (15 kinds). Outcomes include loot, stat changes, diseases and quirks, or a fight with a Shambler. The options depend on the heroes' quirks. (community guide) |
| **Shrine of Reflection** | Pick a hero, see part of their backstory, sometimes fight a battle, and unlock a new skill for them. (community guide) |
| Oasis | Recovery. Details **unconfirmed**; from memory it heals or relieves stress. |
| Field Hospital | Paid treatment. Details **unconfirmed**. |
| The Hoarder | A shop. (wiki) |
| The Desperate Few, Resistance Encounter | Help fellow travellers, sometimes by fighting. (wiki) |
| Watchtower | Reveals every later node in the region. (wiki) |

### Scouting

Nodes and roads start hidden or revealed. Quirks, items, pets and region modifiers change how many are revealed; the Lair is always revealed. (wiki)

### Region goals

Each region sets a goal with a reward, such as **Exterminate** (visit a Creature Den), **Spelunk** (clear the Lair) or **Patrol** (fight 4+ road battles). (wiki)

## Common ground

- **Every route converges** on a fixed end: Slay the Spire's boss, DD2's Rampart and Inn.
- **Risk is a choice of route.** Elites, Lairs and Dens pay more but can be avoided; rests and treasure sit on other branches.
- **Some floors are fixed** (StS treasure mid-act, rest before the boss) so every route gets a breather.
- **Unknowns and events** break up the fights with choices whose outcomes vary.

## Sources

- Slay the Spire wiki, Map Generation: https://slaythespire.wiki.gg/wiki/Map_Generation
- Slay the Spire map generation guide (community): https://kosgames.com/slay-the-spire-map-generation-guide-26769/
- Darkest Dungeon II wiki, Locations / Nodes / Roads: https://darkestdungeon.wiki.gg/wiki/Node
- Darkest Dungeon II wiki, Lair: https://darkestdungeon.wiki.gg/wiki/Lair
- Darkest Dungeon II wiki, Creature Den: https://darkestdungeon.wiki.gg/wiki/Creature_Den
- GameSkinny, DD2 encounter types (Academic's Study, Shrine of Reflection; not opened directly, quoted from search results): https://www.gameskinny.com/tips/darkest-dungeon-2-encounter-types-guide/
