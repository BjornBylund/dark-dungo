## Trinkets, DD2's: rarer ones drop less often and mostly in harder dungeons,
## nobody owns two of one, heroes wear two, their stats, conditional bonuses and
## triggers change fights, and the Nomad Wagon buys and sells them.
extends TestCase


func _trinket(id: String, rarity: TrinketDef.Rarity, stats: Dictionary = {}, hero: UnitDef = null) -> TrinketDef:
	var trinket := TrinketDef.new()
	trinket.id = StringName(id)
	trinket.display_name = id.capitalize()
	trinket.rarity = rarity
	trinket.stats.assign(stats)
	trinket.hero = hero
	trinket.price = [500, 2000, 5000, 0][rarity]
	return trinket


## Three trinkets of each dropping rarity, two boss ones and an Ancestral one.
func _pool() -> Array[TrinketDef]:
	var pool: Array[TrinketDef] = []
	for rarity in 3:
		for i in 3:
			pool.append(_trinket("t%d_%d" % [rarity, i], rarity, {&"damage": 0.05}))
	for i in 2:
		var boss := _trinket("boss_%d" % i, TrinketDef.Rarity.INDELIBLE)
		boss.boss_only = true
		boss.price = 0
		pool.append(boss)
	pool.append(_trinket("ancestral", TrinketDef.Rarity.ANCESTRAL))
	return pool


func _campaign(seed_value: int = 1) -> Campaign:
	var def: CampaignDef = load("res://content/campaign.tres").duplicate()
	def.trinkets = _pool()
	return Campaign.create(def, seed_value)


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _trigger(when: TrinketTrigger.When, to: TrinketTrigger.To, effects: Array) -> TrinketTrigger:
	var trigger := TrinketTrigger.new()
	trigger.when = when
	trigger.to = to
	trigger.effects.assign(effects)
	return trigger


## A hero (fast, wearing `triggers`) against a passive dummy, at the hero's first turn.
func _duel(triggers: Array, skill: SkillDef = null) -> Battle:
	var hero_def := Fixtures.unit("Hero", 30, 50, [skill if skill else Fixtures.attack(1, 1)])
	var battle := Fixtures.battle([hero_def, Fixtures.unit("Ally", 30, 0)], [Fixtures.unit("Dummy", 100, 0)])
	battle.heroes[0].triggers.assign(triggers)
	Fixtures.until_input(battle)
	return battle


func test_rarer_trinkets_drop_less_and_harder_dungeons_drop_better() -> void:
	var pool := _pool()
	var rng := _rng()
	var counts := []
	for tier in CampaignRules.TIER_NAMES.size():
		var tally := [0, 0, 0, 0]
		for i in 3000:
			var trinket := Trinkets.roll(pool, tier, rng)
			assert_false(trinket.boss_only or trinket.rarity == TrinketDef.Rarity.ANCESTRAL, "boss trinkets don't drop")
			tally[trinket.rarity] += 1
		counts.append(tally)
	assert_true(counts[0][0] > counts[0][1] and counts[0][1] > counts[0][2], "Vague, then Distant, then Indelible")
	assert_eq(counts[2][0], 0, "no Vague at Champion")
	assert_true(counts[2][2] > counts[0][2] * 2, "far more Indelible at Champion")


func test_nobody_owns_two_of_a_trinket() -> void:
	var pool := _pool()
	var owned: Array[TrinketDef] = []
	for i in Trinkets.droppable(pool, []).size():
		var trinket := Trinkets.roll(pool, CampaignRules.Tier.APPRENTICE, _rng(i), owned)
		assert_false(trinket in owned)
		owned.append(trinket)
	assert_eq(Trinkets.roll(pool, CampaignRules.Tier.APPRENTICE, _rng(), owned), null, "none left")


func test_bosses_give_a_boss_trinket_not_yet_owned() -> void:
	var pool := _pool()
	var bosses := pool.filter(func(t: TrinketDef) -> bool: return t.boss_only or t.rarity == TrinketDef.Rarity.ANCESTRAL)
	var owned: Array[TrinketDef] = []
	owned.assign(bosses.slice(1))
	for i in 10:
		assert_eq(Trinkets.boss_reward(pool, owned, _rng(i)), bosses[0])
	owned.assign(bosses)
	assert_eq(Trinkets.boss_reward(pool, owned, _rng()).rarity, TrinketDef.Rarity.INDELIBLE, "then an Indelible one")


func test_heroes_wear_two_trinkets_of_their_class() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	var other := campaign.roster()[1]
	var first := _trinket("first", TrinketDef.Rarity.VAGUE)
	var second := _trinket("second", TrinketDef.Rarity.VAGUE)
	var third := _trinket("third", TrinketDef.Rarity.VAGUE)
	var theirs := _trinket("theirs", TrinketDef.Rarity.INDELIBLE, {}, other.def)
	campaign.trinkets.assign([first, second, third, theirs])
	assert_eq(campaign.wear(hero, theirs), "Only the %s can wear this." % other.def.display_name)
	assert_eq(campaign.wear(hero, first), "")
	assert_eq(campaign.wear(hero, second), "")
	assert_eq(campaign.wear(hero, third), "Both trinket slots are full. Take one off first.")
	assert_eq(hero.trinkets, [first, second] as Array[TrinketDef])
	assert_eq(campaign.trinkets, [third, theirs] as Array[TrinketDef])
	assert_eq(campaign.take_off(hero, second), "")
	assert_true(second in campaign.trinkets)
	assert_eq(campaign.wear(other, theirs), "")
	assert_ne(campaign.wear(campaign.recruit_choices()[0], third), "", "only the roster")


func test_stats_and_conditional_bonuses_reach_the_fight() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	var plain := Growth.hero_combatant(hero)
	var trinket := _trinket("bloodied", TrinketDef.Rarity.DISTANT,
			{&"damage": 0.2, &"speed": -2.0, &"max_hp": 0.1, &"resist_stun": 0.15})
	var bonus := TrinketBonus.new()
	bonus.stat = &"damage"
	bonus.amount = 0.3
	bonus.if_token = Tokens.STEALTH
	trinket.bonuses.append(bonus)
	var vs_bleed := TrinketBonus.new()
	vs_bleed.stat = &"crit"
	vs_bleed.amount = 0.25
	vs_bleed.if_target = &"bleed"
	trinket.bonuses.append(vs_bleed)
	hero.trinkets.append(trinket)
	var unit := Growth.hero_combatant(hero)
	assert_almost_eq(unit.stat(&"damage"), 0.2)
	assert_eq(unit.speed(), plain.speed() - 2)
	assert_eq(unit.max_hp, plain.max_hp + roundi(hero.def.max_hp * 0.1))
	assert_almost_eq(unit.resist(&"stun"), plain.resist(&"stun") + 0.15)
	unit.add_token(Tokens.STEALTH)
	assert_almost_eq(unit.stat(&"damage"), 0.5, "+30% while stealthed")
	var bleeding := Combatant.new(Fixtures.unit("Foe", 20), false)
	assert_almost_eq(unit.stat(&"crit", bleeding), 0.0)
	bleeding.dots.append({type = &"bleed", amount = 2, turns = 3})
	assert_almost_eq(unit.stat(&"crit", bleeding), 0.25, "+25% crit against a bleeding target")
	unit.clear_battle_state()
	assert_almost_eq(unit.stat(&"damage"), 0.2, "trinket stats outlast a fight")


func test_combat_start_and_hit_triggers() -> void:
	var start := _trigger(TrinketTrigger.When.COMBAT_START, TrinketTrigger.To.EACH_ALLY, [EffectDef.make_token(Tokens.BLOCK_PLUS)])
	var weaken := EffectDef.make_token(Tokens.WEAK)
	weaken.ignore_resist = true
	var on_hit := _trigger(TrinketTrigger.When.ON_HIT, TrinketTrigger.To.OTHER, [weaken])
	var battle := _duel([start, on_hit])
	assert_true(battle.heroes[0].has_token(Tokens.BLOCK_PLUS), "each hero at combat start")
	assert_true(battle.heroes[1].has_token(Tokens.BLOCK_PLUS))
	battle.submit(battle.heroes[0].skills[0], battle.enemies[0])
	assert_true(battle.enemies[0].has_token(Tokens.WEAK), "applied on hit")


func test_when_hit_and_miss_triggers() -> void:
	var gain := _trigger(TrinketTrigger.When.WHEN_HIT, TrinketTrigger.To.SELF, [EffectDef.make_token(Tokens.STRENGTH)])
	var backlash_effect := EffectDef.make(EffectDef.Kind.DAMAGE)
	backlash_effect.amount = 3
	var backlash := _trigger(TrinketTrigger.When.WHEN_HIT, TrinketTrigger.To.OTHER, [backlash_effect])
	var battle := _duel([gain, backlash])
	var hero := battle.heroes[0]
	var dummy := battle.enemies[0]
	battle.state = Battle.State.RUNNING
	battle._resolve(dummy, Fixtures.attack(1, 1), hero, false)
	assert_true(hero.has_token(Tokens.STRENGTH), "gained when hit")
	assert_eq(dummy.hp, 97, "the attacker takes 3")
	var miss := _trigger(TrinketTrigger.When.ON_MISS, TrinketTrigger.To.SELF, [EffectDef.make_token(Tokens.WEAK)])
	battle = _duel([miss])
	battle.enemies[0].add_token(Tokens.DODGE_PLUS, 3)
	battle.state = Battle.State.RUNNING
	for i in 3:
		battle._resolve(battle.heroes[0], battle.heroes[0].skills[0], battle.enemies[0], false)
	assert_true(battle.heroes[0].has_token(Tokens.WEAK), "a miss in three Dodge+ tries")


func test_conditions_and_pick_one() -> void:
	var first := _trigger(TrinketTrigger.When.TURN_START, TrinketTrigger.To.SELF, [EffectDef.make_token(Tokens.BLIND)])
	first.if_first = true
	var battle := _duel([first])
	assert_true(battle.heroes[0].has_token(Tokens.BLIND), "first in turn order")
	var rank := _trigger(TrinketTrigger.When.TURN_START, TrinketTrigger.To.SELF, [EffectDef.make_token(Tokens.WEAK)])
	rank.if_rank = 4
	battle = _duel([rank])
	assert_false(battle.heroes[0].has_token(Tokens.WEAK), "not in rank 4")
	var either := _trigger(TrinketTrigger.When.TURN_START, TrinketTrigger.To.SELF,
			[EffectDef.make_token(Tokens.CRIT), EffectDef.make_token(Tokens.DODGE)])
	either.pick_one = true
	battle = _duel([either])
	assert_true(battle.heroes[0].has_token(Tokens.CRIT))
	assert_false(battle.heroes[0].has_token(Tokens.DODGE), "only one of them")


func test_skill_triggers_reach_the_skills_target_or_the_user() -> void:
	var buff := Fixtures.attack(0, 0)
	buff.id = &"command"
	buff.side = SkillDef.TargetSide.ALLY
	buff.can_target_self = false
	var target_line := _trigger(TrinketTrigger.When.ON_SKILL, TrinketTrigger.To.OTHER, [EffectDef.make_token(Tokens.TAUNT)])
	target_line.if_skills.assign([&"command"])
	var self_line := _trigger(TrinketTrigger.When.ON_SKILL, TrinketTrigger.To.SELF, [EffectDef.make_token(Tokens.BLOCK)])
	self_line.if_skills.assign([&"other_skill"])
	var battle := _duel([target_line, self_line], buff)
	battle.submit(buff, battle.heroes[1])
	assert_true(battle.heroes[1].has_token(Tokens.TAUNT), "on the skill's target")
	assert_false(battle.heroes[0].has_token(Tokens.BLOCK), "not for other skills")


func test_dot_and_damage_taken_stats() -> void:
	var skill := Fixtures.attack(10, 10)
	skill.effects.assign([EffectDef.make_dot(&"bleed", 2)])
	skill.effects[0].ignore_resist = true
	var battle := _duel([], skill)
	var hero := battle.heroes[0]
	var dummy := battle.enemies[0]
	hero.add_buff(&"dot_dealt_bleed", 1.0, Combatant.BuffExpiry.TRINKET)
	dummy.add_buff(&"dot_duration_received", -1.0, Combatant.BuffExpiry.TRINKET)
	dummy.add_buff(&"damage_taken", -0.5, Combatant.BuffExpiry.TRINKET)
	battle.submit(skill, dummy)
	assert_eq(dummy.hp, 95, "half damage taken")
	assert_eq(dummy.dots[0].amount, 3, "+1 Bleed dealt")
	assert_eq(dummy.dots[0].turns, Rules.DOT_DURATION - 1, "-1 duration received")


func test_healing_trinkets_change_skill_heals() -> void:
	var heal := Fixtures.attack(0, 0)
	heal.side = SkillDef.TargetSide.ALLY
	heal.heal_min = 10
	heal.heal_max = 10
	var amounts := []
	for setup: Array in [[0.0, 0.0], [0.5, 0.0], [0.0, -0.5]]:
		var battle := Fixtures.battle([Fixtures.unit("Healer", 30, 50, [heal]), Fixtures.unit("Hurt", 100, 0)],
				[Fixtures.unit("Dummy", 100, 0)])
		var healer := battle.heroes[0]
		var hurt := battle.heroes[1]
		healer.add_buff(&"heal_power", setup[0], Combatant.BuffExpiry.TRINKET)
		hurt.add_buff(&"heal_received", setup[1], Combatant.BuffExpiry.TRINKET)
		hurt.hp = 10
		Fixtures.until_input(battle)
		battle.submit(heal, hurt)
		amounts.append(hurt.hp - 10)
	# Each battle has the same seed, so a heal crit would hit all three alike.
	assert_eq(amounts[1], roundi(amounts[0] * 1.5), "+50% to healing skills")
	assert_eq(amounts[2], roundi(amounts[0] * 0.5), "-50% healing received")


func test_completed_missions_bring_a_trinket_and_bosses_their_own() -> void:
	var campaign := _campaign()
	var run := campaign.embark(campaign.board[0], campaign.roster().slice(0, 4))
	run.outcome = MissionRun.Outcome.COMPLETED
	var summary := campaign.finish_mission()
	assert_eq(summary.trinkets.size(), 1)
	assert_eq(campaign.trinkets.size(), 1)
	assert_eq(campaign.trinkets[0], summary.trinkets[0], "it goes to the estate")
	assert_false(summary.trinkets[0].boss_only)
	campaign.region_progress[campaign.def.regions[0].id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	var boss: Mission = campaign.board.filter(func(m: Mission) -> bool: return m.boss)[0]
	run = campaign.embark(boss, campaign.roster().slice(0, 4))
	run.outcome = MissionRun.Outcome.COMPLETED
	var reward: TrinketDef = campaign.finish_mission().trinkets[0]
	assert_true(reward.boss_only or reward.rarity == TrinketDef.Rarity.ANCESTRAL)


func test_trinkets_found_on_the_way_are_lost_if_the_party_falls() -> void:
	for outcome: MissionRun.Outcome in [MissionRun.Outcome.RETREATED, MissionRun.Outcome.FAILED]:
		var campaign := _campaign()
		var run := campaign.embark(campaign.board[0], campaign.roster().slice(0, 4))
		var found := _trinket("found", TrinketDef.Rarity.DISTANT)
		run.trinkets_found.append(found)
		run.outcome = outcome
		var kept: Array = campaign.finish_mission().trinkets
		assert_eq(kept, [found] if outcome == MissionRun.Outcome.RETREATED else [], str(outcome))


func test_caches_and_elites_sometimes_hold_a_trinket() -> void:
	var campaign := _campaign()
	var run := campaign.embark(campaign.board[0], campaign.roster().slice(0, 4))
	var finds := 0
	for i in 20:
		run._maybe_find_trinket(CampaignRules.CACHE_TRINKET_CHANCE)
		if run.just_found:
			finds += 1
	assert_between(finds, 5, 9, "about half, while unowned trinkets last")
	assert_eq(run.trinkets_found.size(), finds)
	var unique := {}
	for trinket in run.trinkets_found:
		unique[trinket] = true
	assert_eq(unique.size(), finds, "never the same one twice")


func test_the_campaigns_trinkets_are_well_formed() -> void:
	var def: CampaignDef = load("res://content/campaign.tres")
	var cast: Array[UnitDef] = def.starting_heroes + def.recruits
	var skill_ids := []
	for hero in cast:
		skill_ids.append_array(hero.skills.map(func(skill: SkillDef) -> StringName: return skill.id))
	assert_true(def.trinkets.size() >= 60)
	var ids := {}
	for trinket in def.trinkets:
		var label := String(trinket.id)
		assert_false(ids.has(trinket.id), label + " twice")
		ids[trinket.id] = true
		assert_true(trinket.hero == null or trinket.hero in cast, label + " for a hero in the cast")
		assert_true(trinket.boss_only or trinket.rarity == TrinketDef.Rarity.ANCESTRAL or trinket.price > 0,
				label + " has a price")
		assert_false(UiStyle.perk_effects(trinket).is_empty(), label + " does something")
		var named: Array[StringName] = []
		for trigger in trinket.triggers:
			named.append_array(trigger.if_skills)
		for bonus in trinket.bonuses:
			named.append_array(bonus.if_skills)
		for id in named:
			assert_true(id in skill_ids, "%s names %s" % [label, id])
	assert_true(def.trinkets.filter(func(t: TrinketDef) -> bool: return t.boss_only).size() >= 3, "boss trinkets")


func test_trinkets_survive_saving() -> void:
	var def: CampaignDef = load("res://content/campaign.tres")
	var campaign := Campaign.create(def, 3)
	var hero := campaign.roster()[0]
	var worn := Trinkets.droppable(def.trinkets, []).filter(func(t: TrinketDef) -> bool: return t.hero == null)
	campaign.trinkets.assign(worn.slice(0, 3))
	campaign.wear(hero, worn[0])
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), def)
	assert_eq(loaded.heroes[0].trinkets, [worn[0]] as Array[TrinketDef])
	assert_eq(loaded.trinkets, campaign.trinkets)
	assert_eq(loaded.wagon, campaign.wagon)


func test_the_nomad_wagon_buys_and_sells() -> void:
	var campaign := _campaign()
	assert_eq(campaign.wagon.size(), CampaignRules.WAGON_STOCK)
	var ware := campaign.wagon[0]
	campaign.week = CampaignRules.BUILDINGS[&"wagon"].opens - 1
	assert_eq(campaign.can_buy(ware), "The Nomad Wagon isn't here yet.")
	campaign.week = CampaignRules.BUILDINGS[&"wagon"].opens
	assert_eq(campaign.wagon_price(ware), ware.price)
	campaign.gold = ware.price
	assert_eq(campaign.buy(ware), "")
	assert_eq(campaign.gold, 0)
	assert_true(ware in campaign.trinkets and ware not in campaign.wagon)
	assert_eq(campaign.sell(ware), "")
	assert_eq(campaign.gold, roundi(ware.price * CampaignRules.TRINKET_SELL_SHARE))
	var boss: TrinketDef = campaign.def.trinkets.filter(func(t: TrinketDef) -> bool: return t.boss_only)[0]
	campaign.trinkets.append(boss)
	assert_eq(campaign.sell(boss), "Boss and Ancestral trinkets can't be sold.")
	campaign.upgrades[&"haggling"] = 2
	campaign.upgrades[&"wagon_stock"] = 1
	campaign._advance_week([])
	assert_eq(campaign.wagon.size(), CampaignRules.WAGON_STOCK + 1, "restocked weekly, with the Stock line")
	assert_false(campaign.wagon.any(func(t: TrinketDef) -> bool: return t in campaign.owned_trinkets()), "nothing owned")
	ware = campaign.wagon[0]
	assert_eq(campaign.wagon_price(ware), roundi(ware.price * 0.8))
