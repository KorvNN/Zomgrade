class_name WeaponData
extends Resource
## Bir silahın tüm sayısal + görsel kimliği. Upgrade kartları runtime kopyasını
## değiştirir; yeni silah eklemek = yeni .tres dosyası.

@export var display_name := "Silah"
@export var damage := 10.0
@export var fire_rate := 6.0  ## saniyedeki atış sayısı
@export var mag_size := 12
@export var reserve_ammo := 48
@export var auto := false  ## true: basılı tutunca atar
@export var reload_time := 1.2
@export var headshot_mult := 2.5  ## kafaya isabette hasar çarpanı

@export_group("Saçılma")
@export var pellets := 1  ## tek atışta çıkan saçma sayısı (shotgun)
@export var spread_deg := 0.0  ## saçılma açısı (derece)

@export_group("Görsel / Ses")
@export var model_scene: PackedScene  ## silah modeli (FBX/glb sahnesi)
@export var view_scale := 0.07          ## modelin görüş açısı ölçeği
@export var view_rot_deg := Vector3(0, -90, 0)  ## modelin dönüşü (derece)
@export var view_pos := Vector3(0, -0.3, -0.08) ## modelin konumu (kameraya göre)
@export var fire_sound: AudioStream
@export var fire_volume_db := -14.0


func view_transform() -> Transform3D:
	var basis := Basis.from_euler(view_rot_deg * (PI / 180.0)).scaled(Vector3.ONE * view_scale)
	return Transform3D(basis, view_pos)
