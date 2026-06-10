extends StaticBody3D
## M1 test hedefi: hasar alır, canı bitince yok olur.
## M2'de zombiler de aynı take_damage sözleşmesini kullanacak.

@export var max_health := 30.0

var health: float


func _ready() -> void:
	health = max_health


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()
		return
	# vuruş geri bildirimi: kısa bir küçülüp geri büyüme
	scale = Vector3.ONE * 0.9
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)
