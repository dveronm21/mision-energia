class_name Technician
extends RefCounted
## Un técnico en la planta: su cuerpo (`Player` + `WorkerVisual`), sus manos y lo que tiene a
## mano en este momento (acción, ficha para revisar, resaltado en el suelo). En el modo de un
## jugador hay uno solo; en el modo TV cooperativo, uno por tablet. El mundo (paneles, cables,
## batería) es uno solo y lo comparten.

## Asiento de la tablet que lo controla (0 o 1); -1 = jugador local (táctil o teclado).
var slot: int = -1
var display_name: String = ""
var color: Color = Color.WHITE
var player: Player
var rig: WorkerVisual
var hands: HandsController
## Resaltado propio (anillo en el suelo de lo que tiene a mano).
var highlights: Highlights
## Cartel flotante con el nombre (y en cooperativo, la acción que tiene a mano). null en solo.
var name_tag: Label3D = null

var action: WorldAction = null
var inspect: InspectEntry = null
var last_prompt: String = ""


func _init(p_player: Player, p_rig: WorkerVisual, p_highlights: Highlights) -> void:
	player = p_player
	rig = p_rig
	hands = HandsController.new(p_rig)
	highlights = p_highlights


## Cartel sobre la cabeza con el nombre en el color del jugador (se ve desde lejos en el tele).
func add_name_tag(p_name: String, p_color: Color) -> void:
	display_name = p_name
	color = p_color
	if name_tag == null:
		name_tag = Label3D.new()
		name_tag.name = "name-tag"
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.no_depth_test = true
		name_tag.fixed_size = true
		name_tag.pixel_size = 0.0016
		name_tag.font = UiTheme.display(700)
		name_tag.font_size = 30
		name_tag.outline_size = 12
		name_tag.outline_modulate = Color(UiTheme.HUD, 0.9)
		name_tag.position = Vector3(0, 2.55, 0)
		player.add_child(name_tag)
	name_tag.modulate = p_color
	set_tag_action("")


## Texto del cartel: el nombre y, si tiene algo a mano, la acción debajo.
func set_tag_action(label: String) -> void:
	if name_tag == null:
		return
	name_tag.text = display_name if label == "" else "%s\n%s" % [display_name, label]
