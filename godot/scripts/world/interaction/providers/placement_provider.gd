class_name PlacementProvider
extends ActionProvider
## Cargando algo: colocar panel, instalar protección / batería / trabas (equivale a
## `PlacementProvider` de `interaction/Providers.ts`).

var _s: SessionPort


func _init(session: SessionPort) -> void:
	_s = session


func collect(hands: HandsState, out: Array[WorldAction]) -> void:
	if hands.kind != HandsState.KIND_CARRY:
		return
	var w: PlantWorld = _s.world()
	match hands.item_kind:
		&"panel":
			for m: Mount in w.mounts:
				if not m.filled():
					out.append(WorldAction.new("mount:%d:%d" % [m.row, m.index], "Colocar panel", m.approach, _s.install_panel.bind(m)))
		&"protection":
			if not w.protection.installed():
				out.append(WorldAction.new("protection", "Instalar protección", w.protection.approach, _s.install_protection))
		&"battery":
			for b: BatterySlot in w.batteries:
				if not b.installed():
					out.append(WorldAction.new("battery:%d" % b.index, "Instalar batería", b.approach, _s.install_battery.bind(b.index)))
		&"kit":
			for p: RowPost in w.posts:
				out.append(WorldAction.new("post:%d" % p.row, "Instalar trabas", p.approach, _s.install_kit.bind(p.row)))
