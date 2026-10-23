class_name ConnectorFacts
extends RefCounted
## Progreso del evento "conector flojo" de un nivel (equivale al campo `connector` de
## `MissionFacts` en `MissionTracker.ts`).

## Se midieron las filas con el multímetro en la caja de conexión.
var measured: bool = false
## Se encontró, panel por panel, cuál fila da 0 V.
var row_found: bool = false
## Se reconectó el panel con el conector flojo.
var fixed: bool = false
