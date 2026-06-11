extends Node
## Autoload "Game": XP, level, kill sayacı ve seçilen kartların kaydı.

signal xp_changed(xp: int, needed: int)
signal leveled_up(new_level: int)
signal kills_changed(kills: int)
signal gold_changed(gold: int)
signal bonus_draw  ## sandıktan bedava kart çekimi

var level := 1
var xp := 0
var kills := 0
var picked_cards := {}  ## kart id -> kaç kez seçildi
var stage := 1  ## kaçıncı kat (zindan derinliği)
var run_seed := 0  ## bu oyunun labirent tohumu
var gold := 0


func next_stage() -> void:
	stage += 1


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func xp_needed() -> int:
	return 40 + (level - 1) * 30


func add_kill(xp_value: int) -> void:
	kills += 1
	kills_changed.emit(kills)
	add_xp(xp_value)
	add_gold(4 + randi() % 4 + stage)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_needed())


func card_count(id: String) -> int:
	return picked_cards.get(id, 0)


func reset() -> void:
	level = 1
	xp = 0
	kills = 0
	picked_cards.clear()
	stage = 1
	run_seed = randi()
	gold = 0
