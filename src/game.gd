## Autoload: the running campaign, its save file, and moving between screens.
extends Node

const CAMPAIGN: CampaignDef = preload("res://content/campaign.tres")
const SAVE_PATH := "user://campaign.json"
const MAIN_MENU := "res://src/ui/main_menu.tscn"
const TOWN := "res://src/ui/town_screen.tscn"
const EXPEDITION := "res://src/ui/expedition_screen.tscn"
const MAP := "res://src/ui/map_screen.tscn"
const BATTLE := "res://src/ui/combat_screen.tscn"
## The balance tool; left out of exports.
const BALANCE := "res://src/balance/balance_app.tscn"

## Null in the main menu and the combat sandbox.
var campaign: Campaign


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_campaign() -> void:
	campaign = Campaign.create(CAMPAIGN, randi())
	save()
	go_to_town()


## Loads the save and goes back to where it left off. False if there is no usable save.
func continue_campaign() -> bool:
	campaign = Campaign.load_from(SAVE_PATH, CAMPAIGN)
	if campaign == null:
		return false
	if campaign.run and campaign.run.has_pending_fight():
		go_to_battle()
	elif campaign.run:
		go_to_map()
	else:
		go_to_town()
	return true


## Called in town and after each fight. Other rooms on a mission map aren't
## saved: quitting goes back to the last fight, or to the town before embarking.
func save() -> void:
	if campaign:
		var error := campaign.save(SAVE_PATH)
		if error != OK:
			push_error("Could not save the campaign: %s" % error_string(error))


func go_to_town() -> void:
	get_tree().change_scene_to_file(TOWN)


## The map for choosing a mission and lining up the party.
func go_to_expedition() -> void:
	get_tree().change_scene_to_file(EXPEDITION)


## The mission in progress: its map, between rooms.
func go_to_map() -> void:
	get_tree().change_scene_to_file(MAP)


func go_to_battle() -> void:
	get_tree().change_scene_to_file(BATTLE)


func go_to_menu() -> void:
	campaign = null
	get_tree().change_scene_to_file(MAIN_MENU)


## Opens the combat sandbox (a fixed party against three waves) instead of the campaign.
func play_sandbox() -> void:
	campaign = null
	get_tree().change_scene_to_file(BATTLE)


## Opens the balance tool, for designing and balancing heroes, enemies and items.
func open_balance_tool() -> void:
	campaign = null
	get_tree().change_scene_to_file(BALANCE)


## Whether the balance tool is here: running from the project folder, not an export.
func has_balance_tool() -> bool:
	return not OS.has_feature("template")
