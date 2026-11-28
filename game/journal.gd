extends RefCounted
## Write the full inventory and world state as one replaceable snapshot.
const CREST_PATH := "user://six-crests-v1.cfg"
var path := CREST_PATH

func read() -> Dictionary:
	var candidates := [path, path + ".bak"]
	if path == CREST_PATH:
		candidates.append_array(["user://expedition-v1.cfg","user://expedition-v1.cfg.bak","user://island-v1.cfg","user://island-v1.cfg.bak"])
	for candidate in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		var config := ConfigFile.new()
		if config.load(candidate) == OK and config.get_value("game", "version", 0) in [1,2]:
			var state = config.get_value("game", "state", {})
			if state is Dictionary and state.get("pos") is Vector3 and state.get("taken") is Array:
				return state
	return {}

func write(state: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.set_value("game", "version", 2)
	config.set_value("game", "state", state)
	var tmp := ProjectSettings.globalize_path(path + ".tmp")
	var dest := ProjectSettings.globalize_path(path)
	var backup := dest + ".bak"
	if config.save(tmp) != OK:
		return false
	if FileAccess.file_exists(dest):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return false
		if DirAccess.rename_absolute(dest, backup) != OK:
			return false
	if DirAccess.rename_absolute(tmp, dest) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, dest)
		return false
	return true
