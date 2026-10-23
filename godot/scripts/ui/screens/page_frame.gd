class_name PageFrame
extends RefCounted
## Estructura común de página devuelta por `UiCommon.page_frame()` (equivale a `PageFrame`
## de `screens/common.ts`): cabecera (atrás + título + extras), cuerpo con scroll interno,
## pie opcional.

var root: Control
var body: VBoxContainer
## null si la página no pidió pie.
var footer: HBoxContainer
