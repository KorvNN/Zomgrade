extends Node
## Autoload "Game": XP, level, kill sayacı ve seçilen kartların kaydı.

signal xp_changed(xp: int, needed: int)
signal leveled_up(new_level: int)
signal kills_changed(kills: int)
signal gold_changed(gold: int)
signal bonus_draw(rarity_boost: int)  ## sandıktan bedava kart çekimi (boost>0 = yüksek rarity)

## Koşu akışı: 1-5 bahçe labirenti → 6 bahçe boss arenası → 7-11 şato katları → (sonra: şato boss)
const GARDEN_STAGES := 5
const CASTLE_STAGES := 5

var level := 1
var xp := 0
var kills := 0
var picked_cards := {}  ## kart id -> kaç kez seçildi
var stage := 1  ## global ilerleme sayacı (tüm bölümler boyunca artar)
var run_seed := 0  ## bu oyunun labirent tohumu
var gold := 0
var intro_shown := false  ## açılış hikâye ekranı (koşu başına bir kez)
var castle_intro_shown := false  ## şatoya giriş hikâye ekranı


func biome() -> String:
	if stage <= GARDEN_STAGES:
		return "garden"
	if stage == GARDEN_STAGES + 1:
		return "garden_boss"
	if stage == GARDEN_STAGES + CASTLE_STAGES + 2:  # kat 12: taht salonu
		return "castle_boss"
	return "castle"


func biome_stage() -> int:
	## bulunulan bölümün kaçıncı katı (1'den başlar)
	if stage <= GARDEN_STAGES:
		return stage
	if stage == GARDEN_STAGES + 1:
		return 1
	if stage <= GARDEN_STAGES + CASTLE_STAGES + 1:
		return stage - GARDEN_STAGES - 1
	if stage == GARDEN_STAGES + CASTLE_STAGES + 2:
		return 1
	return stage - GARDEN_STAGES - 2  # boss sonrası şato derinleri (kat 6+)


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


func add_kill() -> void:
	## sadece sayaç — XP/altın artık yerden pickup olarak toplanıyor
	kills += 1
	kills_changed.emit(kills)


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
	intro_shown = false
	castle_intro_shown = false
