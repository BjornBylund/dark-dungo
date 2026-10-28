## Turns battle events into combat-log lines (BBCode), including the rolls
## behind each outcome so balance can be checked by reading the log.
class_name CombatLog
extends RefCounted


## `name_of` maps a uid to a display name.
static func describe(event: Dictionary, name_of: Callable) -> String:
	var who: String = name_of.call(event.uid) if event.uid else ""
	match event.type:
		&"round_start":
			return "[color=#d9b45a]-- Round %d --[/color]" % event.round
		&"turn_start":
			return ""
		&"dazed":
			return "%s is dazed and acts at the end of the round." % who
		&"stunned":
			return "%s is stunned and loses the turn." % who
		&"skill":
			var skill: SkillDef = event.skill
			var targets: Array = event.targets.map(func(uid: int) -> String: return name_of.call(uid))
			var line := "[b]%s[/b] uses [b]%s[/b]" % [who, skill.display_name]
			if event.get("riposte", false):
				line = "[b]%s[/b] ripostes with [b]%s[/b]" % [who, skill.display_name]
			if skill.side != SkillDef.TargetSide.SELF and skill.kind != SkillDef.Kind.PASS:
				line += " on " + ", ".join(targets)
			if event.get("crit", false):
				line += " [color=#ffd25e]CRIT[/color]"
			if event.get("crit_roll", -1.0) >= 0.0:
				line += _roll(event.crit_roll, event.crit_chance)
			return line
		&"miss":
			var reason := "dodges" if event.reason == &"dodge" else "is missed (blind)"
			return "  %s %s%s" % [who, reason, _roll(event.roll, event.chance)]
		&"guarded":
			return "  %s takes the attack meant for %s." % [who, name_of.call(event.protected)]
		&"damage":
			var line := "  %s takes [color=#e0533f]%d[/color]" % [who, event.amount]
			if event.get("cause", &"hit") != &"hit":
				line += " %s" % event.cause
			elif event.has("base"):
				line += " (%s x%.2f x%.2f%s)" % [str(snappedf(event.base, 0.1)), event.attack_mod, event.defense_mod,
						" x0.5 weak" if event.weak else ""]
			return line + " -> %d HP" % event.hp
		&"heal":
			return "  %s heals [color=#6fd38a]%d[/color]%s -> %d HP" % [who, event.amount,
					" (crit)" if event.crit else "", event.hp]
		&"stress":
			return "  %s %+d stress -> %d" % [who, event.amount, event.stress]
		&"stress_resisted":
			return "  %s resists stress%s" % [who, _roll(event.roll, event.chance)]
		&"token":
			var parts: Array[String] = []
			if event.added > 0:
				parts.append("gains %s x%d" % [UiStyle.token_name(event.token), event.added])
			for negated: StringName in event.negated:
				parts.append("%s cancels %s" % [UiStyle.token_name(event.token), UiStyle.token_name(negated)])
			return "  %s %s" % [who, ", ".join(parts)]
		&"token_expired":
			return "  %s's %s wears off." % [who, UiStyle.token_name(event.token)]
		&"resisted":
			return "  %s resists %s%s" % [who, _what(event.what), _roll(event.roll, event.chance)]
		&"dot_applied":
			return "  %s: %s %d for %d turns" % [who, String(event.dot).capitalize(), event.amount, event.turns]
		&"cleansed":
			return "  %s is cleansed." % who
		&"immobile":
			return "  %s is immobilized and can't be moved." % who
		&"moved":
			return "  %s moves to rank %d." % [who, event.rank]
		&"reposition":
			return "[b]%s[/b] repositions." % who
		&"pass":
			return "[b]%s[/b] waits." % who
		&"deaths_door":
			return "  [color=#e0533f]%s is at Death's Door![/color]" % who
		&"left_deaths_door":
			return "  %s is pulled back from Death's Door." % who
		&"deathblow_resisted":
			return "  %s resists the deathblow%s" % [who, _roll(event.roll, event.chance)]
		&"deathblow":
			return "  [color=#e0533f]Deathblow! %s falls%s[/color]" % [who, _roll(event.roll, event.chance)]
		&"death_armor":
			return "  %s's Death Armor holds (%d left)." % [who, event.remaining]
		&"death":
			return "  [color=#e0533f]%s falls%s.[/color]" % [who, " and leaves a corpse" if event.corpse else ""]
		&"removed":
			match event.reason:
				&"decayed":
					return "  %s's corpse decays." % who
				&"destroyed":
					return "  %s's corpse is destroyed." % who
			return ""
		&"meltdown":
			return "  [color=#c9b8ff]%s MELTS DOWN![/color] HP %d, stress %d" % [who, event.hp, event.stress]
		&"resolute":
			return "  [color=#d9b45a]%s becomes RESOLUTE![/color]" % who
		&"toxic":
			return "  [color=#8fc23a]%s turns TOXIC![/color] HP %d, stress %d" % [who, event.hp, event.stress]
		&"token_removed":
			return "  %s loses %s." % [who, UiStyle.token_name(event.token)]
		&"buffed":
			return "  %s: %s for %d rounds" % [who, UiStyle.buff_text(event.stat, event.amount), event.rounds]
		&"regen_applied":
			return "  %s: Regen %d for %d turns" % [who, event.amount, event.turns]
		&"extra_turn":
			return "  %s gets an extra turn." % who
		&"consecrated":
			return "  Rank %d is consecrated (%s, %d rounds)." % [event.rank, String(event.name).capitalize(), event.rounds]
		&"battle_end":
			return "[color=#d9b45a]Victory.[/color]" if event.victory else "[color=#e0533f]Defeat.[/color]"
	return "  (%s)" % event.type


static func _roll(roll: float, chance: float) -> String:
	return " [color=#9a8c7a](roll %d vs %d%%)[/color]" % [roundi(roll * 100), roundi(chance * 100)]


static func _what(what: StringName) -> String:
	return UiStyle.token_name(what) if Tokens.RULES.has(what) else String(what)
