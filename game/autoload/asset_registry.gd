extends Node

# Maps semantic asset names to file paths.
# All game code references assets through this — never by raw path.
# To swap placeholder art, update the path here; nothing else changes.

const ASSETS := {
	# Backgrounds
	"bg_space": "res://assets/placeholder/bg_space.png",
	"earth_sphere": "res://assets/placeholder/earth_sphere.png",

	# Icons — factions
	"icon_faction_militarist": "res://assets/placeholder/icon_faction_militarist.png",
	"icon_faction_expansionist": "res://assets/placeholder/icon_faction_expansionist.png",
	"icon_faction_technocrat": "res://assets/placeholder/icon_faction_technocrat.png",
	"icon_faction_cooperativist": "res://assets/placeholder/icon_faction_cooperativist.png",
	"icon_faction_traditionalist": "res://assets/placeholder/icon_faction_traditionalist.png",
	"icon_faction_isolationist": "res://assets/placeholder/icon_faction_isolationist.png",

	# Icons — notifications
	"icon_notify_milestone": "res://assets/placeholder/icon_notify_milestone.png",
	"icon_notify_crisis": "res://assets/placeholder/icon_notify_crisis.png",
	"icon_notify_research": "res://assets/placeholder/icon_notify_research.png",
	"icon_notify_diplomatic": "res://assets/placeholder/icon_notify_diplomatic.png",
}


func get_asset_path(key: String) -> String:
	assert(key in ASSETS, "AssetRegistry: unknown asset key '%s'" % key)
	return ASSETS[key]


func load_texture(key: String) -> Texture2D:
	var path := get_asset_path(key)
	if ResourceLoader.exists(path):
		return load(path)
	return null
