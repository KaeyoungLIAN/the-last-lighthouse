extends SceneTree
## A hunt can be traded once; cooking one dish replaces the last regional travel effect.
const Game=preload("res://main.gd")
var game
var failures:=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL ",message)

func open_recipes() -> void:
	game._place_hero(game.voyage.HOME)
	game._refresh()
	game._interact(game.voyage.DESK)
	game.hud.action.emit("village_recipes")
	check(game.screen=="recipes","cookbook opens from village table")

func dish_button(id: String) -> Button:
	for item: Button in game.hud.menu_buttons:
		if item.text=="做"+game.voyage.RECIPES[id][0]: return item
	return null

func exposure(id: String, meal: String) -> float:
	var s=game.survival
	s.zone=id
	s.sheltered=false
	s.crested=false
	s.weather_strength=.64
	s.food=100
	s.water=100
	s.warmth=0
	s.wet=10 if id=="tide" else 0
	s.meal_zone=meal
	game.hero.velocity=Vector3.RIGHT*7 if id=="forest" else Vector3.ZERO
	game.ferry.afloat=id=="lake"
	s._metabolism(5.,game.Geo.HUNTS[id])
	match id:
		"snow","volcano": return absf(s.warmth)
		"tide": return 10-s.wet
		"desert": return 100-s.water
	return 100-s.food

func run() -> void:
	game=Game.new()
	var path:=OS.get_temp_dir().path_join("greybay-recipes-%d.cfg"%OS.get_process_id())
	game.journal.path=path
	root.add_child(game)
	game.hud.action.emit("start")
	game.hud.action.emit("prologue_skip")
	open_recipes()
	for id: String in game.voyage.ORDER:
		var button:=dish_button(id)
		check(button!=null and button.disabled,"requires the local catch for "+id)
	game.hud.action.emit("cook/snow")
	check(not game.taken.has("village_taste_snow"),"empty pantry cannot be exchanged")
	game.hud.action.emit("back_recipes")
	game.hud.action.emit("resume")
	for id: String in game.voyage.ORDER:
		game.wilds.harvested.emit(id)
		game.wilds.harvested.emit(id)
		check(game.survival.pantry.get(id,0)==1,"one daily catch credited in "+id)
	game.hud.action.emit("cook/forest")
	check(not game.taken.has("village_taste_forest"),"cannot cook from the field")
	game.hero.oil=14
	game.survival.rations=1
	open_recipes()
	var chosen:=dish_button("forest")
	check(chosen!=null and not chosen.disabled,"choose a dish out of harvest order")
	if chosen!=null: chosen.pressed.emit()
	check(game.taken.has("village_taste_forest") and game.voyage.shade_flags.forest.visible,"first dish raises its pennant")
	check(game.survival.rations==3 and game.hero.oil==24,"two rations and ten lamp oil")
	check(not game.survival.pantry.has("forest") and game.survival.pantry.has("snow"),"only selected ingredient spent")
	var expiry: float=game.survival.meal_until
	game._process(60.)
	check(is_equal_approx(expiry-game.time_elapsed,game.voyage.MEAL_MINUTES),"reading recipes freezes the clock")
	game.hud.action.emit("cook/forest")
	check(game.survival.rations==3 and game.hero.oil==24,"same catch cannot be traded twice")
	game.hud.action.emit("continue")
	check(game.survival.meal_zone=="forest" and game.survival.meal_until==expiry,"active meal survives a reload")
	check(not game.survival.pantry.has("forest") and game.survival.pantry.has("snow"),"stock survives a reload")
	open_recipes()
	game.hud.action.emit("cook/desert")
	check(game.survival.meal_zone=="desert" and game.survival.meal_status(game.time_elapsed).contains("饮水"),"new dish replaces effect and describes it")
	game.hud.action.emit("back_recipes")
	game.hud.action.emit("resume")
	game.time_elapsed+=1440.
	check(game.survival.meal_status(game.time_elapsed)=="","world time or a night of rest expires the effect")
	game.wilds.harvested.emit("forest")
	game.wilds.harvested.emit("snow")
	check(game.survival.pantry.get("snow",0)==2,"unspent catches from different days accumulate")
	open_recipes()
	game.hud.action.emit("cook/forest")
	check(game.taken.count("village_taste_forest")==1 and not game.survival.pantry.has("forest"),"new day's catch can be traded without duplicating pennant")
	game.hud.action.emit("cook/snow")
	check(game.survival.pantry.get("snow",0)==1,"each recipe consumes one batch")
	game.hud.action.emit("back_recipes")
	game.hud.action.emit("village_cook")
	check(not game.survival.pantry.has("snow"),"legacy cooking action trades one remaining batch")

	game.world_day=1.0
	for id: String in game.voyage.ORDER:
		game.survival.meal_until=game.time_elapsed+80.
		var base:=exposure(id,"")
		var protected:=exposure(id,id)
		var factor:=2.0 if id=="tide" else .5
		check(base>0.0 and absf(protected-base*factor)<.0001,"regional effect matches cookbook for "+id)
		var elsewhere:=exposure(id,"forest" if id!="forest" else "lake")
		check(is_equal_approx(elsewhere,base),"regional effect stays local for "+id)
		game.survival.meal_until=game.time_elapsed
		check(is_equal_approx(exposure(id,id),base),"expiry restores ordinary travel cost for "+id)
	game.ferry.afloat=false

	var legacy: Dictionary=game.journal.read()
	for key: String in ["pantry","meal_until","meal_zone"]: legacy.survival.erase(key)
	legacy.taken=["village_taste_snow"]
	legacy.hunted_today={"snow":0,"lake":0}
	game.journal.write(legacy)
	game.hud.action.emit("continue")
	check(game.survival.pantry=={"lake":1} and game.survival.meal_zone.is_empty(),"legacy save retains untraded catch without rewarding an old flag twice")
	open_recipes()
	game.hud.action.emit("cook/lake")
	game.hud.action.emit("continue")
	check(game.survival.pantry.is_empty(),"migration is not applied twice")
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	game.free()
	print("All six recipes, stock, regional effects, expiry, migration and repeat trades. Failures: ",failures)
	quit(1 if failures else 0)
