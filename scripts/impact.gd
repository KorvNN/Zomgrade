extends CPUParticles3D
## Tek seferlik isabet kıvılcımı; bittiğinde kendini siler.


func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.1).timeout
	queue_free()
