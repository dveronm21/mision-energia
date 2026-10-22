class_name SimulatorOptions
extends RefCounted
## Parámetros físicos del simulador (valores por defecto = DEFAULT_SIM_OPTIONS de la web).

## Eficiencia de carga de baterías (0..1).
var charge_efficiency: float = 0.95
## Pérdida de una fila con polvo (0..1).
var dust_loss: float = 0.35
## Rendimiento de una fila en posición de defensa (horizontal).
var defense_factor: float = 0.55
## Irradiancia remanente durante la tormenta de Zonda.
var storm_factor: float = 0.25
## Paso interno máximo (h) para que el resultado no dependa del frame rate.
var max_substep_hours: float = 0.05
