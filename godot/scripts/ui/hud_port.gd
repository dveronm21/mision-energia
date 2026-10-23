class_name HudPort
extends RefCounted
## HUD completo de partida (equivale a `Hud.ts`). `GameSession` solo conoce esta superficie;
## la UI real (`scripts/ui/hud.gd`, por construir) la extiende y reemplaza cada sub-panel por
## uno de verdad (Control). Mismo patrón que `SessionPort`.

var mission: MissionPanelPort = MissionPanelPort.new()
var stats: StatsPanelPort = StatsPanelPort.new()
var alert: AlertBannerPort = AlertBannerPort.new()
var prompt: WorldPromptPort = WorldPromptPort.new()
var meter: MeterViewPort = MeterViewPort.new()
var inspect: InspectCardPort = InspectCardPort.new()
var shedding: LoadSheddingPanelPort = LoadSheddingPanelPort.new()
var boosters: BoosterBarPort = BoosterBarPort.new()
var actions: ActionButtonsPort = ActionButtonsPort.new()


## Reinicia el HUD al empezar un nivel.
func reset() -> void:
	alert.hide()
	prompt.hide()
	meter.hide()
	inspect.hide()
	shedding.hide()
	stats.set_visible(false)
	actions.set_meter_on(false)
	actions.set_action("Acercate a algo", &"idle")
	mission.set_collapsed(false)
