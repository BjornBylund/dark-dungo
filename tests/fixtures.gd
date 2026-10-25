## Builders for small hand-made battles and campaign content in tests.
class_name Fixtures
extends RefCounted


## A region from encounter file names in content/encounters/.
static func region(id: StringName, encounters: Array, elites: Array, finales: Array) -> RegionDef:
	var result := RegionDef.new()
	result.id = id
	result.display_name = String(id).capitalize()
	for name: String in encounters:
		result.encounters.append(load("res://content/encounters/%s.tres" % name))
	for name: String in elites:
		result.elites.append(load("res://content/encounters/%s.tres" % name))
	for name: String in finales:
		result.finales.append(load("res://content/encounters/%s.tres" % name))
	return result


static func outcome(kind: EventOutcomeDef.Kind, amount: float = 0.0,
		target: EventOutcomeDef.Target = EventOutcomeDef.Target.PARTY) -> EventOutcomeDef:
	var result := EventOutcomeDef.new()
	result.kind = kind
	result.amount = amount
	result.target = target
	return result


static func choice(label: String, success: Array, chance: float = 1.0, failure: Array = [],
		requires: UnitDef = null) -> EventChoiceDef:
	var result := EventChoiceDef.new()
	result.label = label
	result.success.assign(success)
	result.chance = chance
	result.failure.assign(failure)
	result.requires = requires
	return result


## An event with one choice of each kind: certain healing, a gamble between
## gold and a fight, and one only the Mender can take.
static func spring_event() -> EventDef:
	var event := EventDef.new()
	event.id = &"spring"
	event.title = "A Spring"
	event.choices.assign([
		choice("Drink", [outcome(EventOutcomeDef.Kind.HP, 0.2)]),
		choice("Dig", [outcome(EventOutcomeDef.Kind.GOLD, 1.0)], 0.5, [outcome(EventOutcomeDef.Kind.FIGHT)]),
		choice("Bless it", [outcome(EventOutcomeDef.Kind.STRESS, -2, EventOutcomeDef.Target.CHOSEN_HERO)], 1.0, [],
				load("res://content/heroes/mender.tres")),
	])
	return event


static func unit(display_name: String, hp: int = 30, speed: int = 0, skills: Array = []) -> UnitDef:
	var def := UnitDef.new()
	def.id = StringName(display_name.to_snake_case())
	def.display_name = display_name
	def.max_hp = hp
	def.speed = speed
	def.skills.assign(skills)
	return def


static func attack(min_damage: int, max_damage: int, crit_chance: float = 0.0) -> SkillDef:
	var skill := SkillDef.new()
	skill.id = &"attack"
	skill.display_name = "Attack"
	skill.damage_min = min_damage
	skill.damage_max = max_damage
	skill.crit_chance = crit_chance
	return skill


## A skill that only applies effects to one enemy.
static func debuff(effects: Array) -> SkillDef:
	var skill := SkillDef.new()
	skill.id = &"debuff"
	skill.display_name = "Debuff"
	skill.effects.assign(effects)
	return skill


static func battle(hero_defs: Array, enemy_defs: Array, seed_value: int = 1) -> Battle:
	var heroes: Array[Combatant] = []
	for def: UnitDef in hero_defs:
		heroes.append(Combatant.new(def, true))
	var enemies: Array[Combatant] = []
	for def: UnitDef in enemy_defs:
		enemies.append(Combatant.new(def, false))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Battle.new(heroes, enemies, rng)


## A fast hero with one skill against a slow, passive dummy. The hero always acts first.
static func duel(skill: SkillDef, dummy_hp: int = 100, seed_value: int = 1) -> Battle:
	var hero := unit("Hero", 30, 50, [skill])
	var dummy := unit("Dummy", dummy_hp, 0)
	return battle([hero], [dummy], seed_value)


## Advances until the player must choose (or the battle ends) and returns all events.
static func until_input(battle: Battle) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in 1000:
		if battle.state != Battle.State.RUNNING:
			break
		events.append_array(battle.advance())
	return events


static func of_type(events: Array[Dictionary], type: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event.type == type:
			result.append(event)
	return result


## Uses `skill` once from a hero on a dummy, after `prepare(hero, dummy)` sets up tokens.
## Returns {damage: the first damage event or {}, events, hero, target}.
static func hit_once(skill: SkillDef, prepare: Callable = Callable(), seed_value: int = 1) -> Dictionary:
	var battle := duel(skill, 100, seed_value)
	until_input(battle)
	var hero := battle.heroes[0]
	var target := battle.enemies[0]
	if prepare.is_valid():
		prepare.call(hero, target)
	var events := battle.submit(skill, target)
	var damage := of_type(events, &"damage")
	return {
		damage = damage[0] if not damage.is_empty() else {},
		events = events, hero = hero, target = target,
	}
