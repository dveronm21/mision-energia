class_name StormImpact
extends RefCounted
## Regla del golpe de Zonda (pura, igual a `StormImpact.ts`): al entrar en 'zonda-storm', toda fila
## con paneles queda con polvo; cada fila que NO está en defensa pierde su último panel, salvo que se
## haya instalado el kit anti-Zonda. El mundo 3D la aplica una vez al comenzar la tormenta.


func apply(plant: PlantState, kit_installed: bool) -> StormHit:
	var hit: StormHit = StormHit.new()
	var out: PlantState = plant.clone()
	for r: int in plant.panels_per_row.size():
		var n: int = plant.panels_per_row[r]
		var defended: bool = r < plant.row_defense.size() and plant.row_defense[r]
		var lost: int = 1 if (n > 0 and not kit_installed and not defended) else 0
		hit.lost_per_row.append(lost)
		hit.panels_lost += lost
		out.panels_per_row[r] = n - lost
		var was_dirty: bool = r < plant.row_dirty.size() and plant.row_dirty[r]
		if r < out.row_dirty.size():
			out.row_dirty[r] = was_dirty or n > 0
		else:
			out.row_dirty.append(was_dirty or n > 0)
	hit.plant = out
	return hit
