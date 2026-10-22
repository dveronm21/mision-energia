class_name Levels
extends RefCounted
## Los 5 niveles de la campaña (mismos números que `app/src/levels/levels.ts`).
## Números didácticos (no dimensionamiento real), ajustados con el chequeo de balance
## (`tests/balance.gd`): cada nivel se gana con una compra razonable + juego atento, y pierde
## (o baja estrellas) ante cada error típico. Horas: 10 (activación) → 31 (07:00 del día siguiente).


static func prices() -> ShopPrices:
	return ShopPrices.make(900, 3200, 700, 600)


## Instancias nuevas en cada llamada (se pueden modificar sin afectar a otros).
static func all() -> Array[LevelDefinition]:
	return [casa(), escuela(), finca(), pueblo(), parque()]


static func casa() -> LevelDefinition:
	var l: LevelDefinition = LevelDefinition.new()
	l.id = LevelDefinition.CASA
	l.order = 1
	l.name = "Casa familiar"
	l.subtitle = "Que la casa tenga luz toda la noche"
	l.story = "La familia Quiroga quiere su propia energía solar. Es tu primera obra: armá la fila de paneles, instalá la batería y conectá todo."
	l.rows = 1
	l.panels_per_row = 4
	l.battery_slots = 1
	l.panel_kw = 0.6
	l.battery_kwh = 7.0
	l.inverter_kw = 3.0
	l.budget = 7400
	l.prices = prices()
	l.min_panels = 2
	l.loads = [
		LoadBlock.make(0, 24, 0.2, "Heladera", true),
		LoadBlock.make(10, 18, 0.3, "Lavarropas y cocina", false),
		LoadBlock.make(19, 23, 0.9, "Luces y TV", true),
	]
	l.has_pump = false
	l.events = LevelEvents.make(false, LevelEvents.NO_ZONDA, [] as Array[CloudBand])
	l.start_hour = 10.0
	l.end_hour = 31.0
	l.start_soc = 0.2
	l.rewards = [10, 10, 15]
	l.two_star_soc = 0.15
	l.three_star_spend = 0.9
	l.requires = ""
	l.unlock_cost_soles = 0
	return l


static func escuela() -> LevelDefinition:
	var l: LevelDefinition = LevelDefinition.new()
	l.id = LevelDefinition.ESCUELA
	l.order = 2
	l.name = "Escuela rural"
	l.subtitle = "Encontrá la falla y dejá la escuela iluminada"
	l.story = "La escuela albergue necesita luz para el turno noche y la guardia. Ojo: uno de los paneles vino con un conector flojo."
	l.rows = 2
	l.panels_per_row = 3
	l.battery_slots = 2
	l.panel_kw = 0.6
	l.battery_kwh = 7.0
	l.inverter_kw = 4.0
	l.budget = 12000
	l.prices = prices()
	l.min_panels = 3
	l.loads = [
		LoadBlock.make(0, 24, 0.2, "Heladera del comedor", true),
		LoadBlock.make(10, 17, 0.6, "Aulas y computadoras", false),
		LoadBlock.make(18, 22, 1.0, "Turno noche", true),
		LoadBlock.make(22, 7, 0.3, "Luces de guardia", true),
	]
	l.has_pump = false
	l.events = LevelEvents.make(true, LevelEvents.NO_ZONDA, [] as Array[CloudBand])
	l.start_hour = 10.0
	l.end_hour = 31.0
	l.start_soc = 0.15
	l.rewards = [15, 15, 20]
	l.two_star_soc = 0.2
	l.three_star_spend = 0.9
	l.requires = LevelDefinition.CASA
	l.unlock_cost_soles = 120
	return l


static func finca() -> LevelDefinition:
	var l: LevelDefinition = LevelDefinition.new()
	l.id = LevelDefinition.FINCA
	l.order = 3
	l.name = "Finca en el valle"
	l.subtitle = "Regá de día, iluminá de noche… y aguantá el Zonda"
	l.story = "En la finca la bomba solar riega las vides al mediodía. A la siesta se anuncia viento Zonda: protegé los paneles y limpialos cuando pase."
	l.rows = 2
	l.panels_per_row = 4
	l.battery_slots = 2
	l.panel_kw = 0.6
	l.battery_kwh = 7.0
	l.inverter_kw = 5.0
	l.budget = 13500
	l.prices = prices()
	l.min_panels = 4
	l.loads = [
		LoadBlock.make(0, 24, 0.2, "Heladera y cámara de frío", true),
		LoadBlock.make(11, 16, 1.2, "Bomba de riego", true),
		LoadBlock.make(19, 23, 1.0, "Casa y galpón", true),
		LoadBlock.make(23, 7, 0.3, "Luces del patio", false),
	]
	l.has_pump = true
	l.events = LevelEvents.make(false, 13.0, [] as Array[CloudBand])
	l.start_hour = 10.0
	l.end_hour = 31.0
	l.start_soc = 0.15
	l.rewards = [20, 20, 25]
	l.two_star_soc = 0.3
	l.three_star_spend = 0.9
	l.requires = LevelDefinition.ESCUELA
	l.unlock_cost_soles = 180
	return l


static func pueblo() -> LevelDefinition:
	var l: LevelDefinition = LevelDefinition.new()
	l.id = LevelDefinition.PUEBLO
	l.order = 4
	l.name = "Pueblo de montaña"
	l.subtitle = "Nubes de mañana, presupuesto justo"
	l.story = "Un pueblo entero depende de tu planta. La mañana viene nublada y el presupuesto no alcanza para todo: elegí bien qué comprar."
	l.rows = 3
	l.panels_per_row = 4
	l.battery_slots = 3
	l.panel_kw = 0.6
	l.battery_kwh = 7.0
	l.inverter_kw = 7.0
	l.budget = 18500
	l.prices = prices()
	l.min_panels = 6
	l.loads = [
		LoadBlock.make(0, 24, 0.4, "Sala de salud", true),
		LoadBlock.make(10, 18, 0.8, "Comercios", false),
		LoadBlock.make(19, 23, 1.4, "Casas", true),
		LoadBlock.make(23, 7, 0.3, "Alumbrado público", true),
	]
	l.has_pump = false
	l.events = LevelEvents.make(false, LevelEvents.NO_ZONDA, [CloudBand.make(10, 13, 0.45)] as Array[CloudBand])
	l.start_hour = 10.0
	l.end_hour = 31.0
	l.start_soc = 0.15
	l.rewards = [25, 25, 30]
	l.two_star_soc = 0.3
	l.three_star_spend = 0.95
	l.requires = LevelDefinition.FINCA
	l.unlock_cost_soles = 240
	return l


static func parque() -> LevelDefinition:
	var l: LevelDefinition = LevelDefinition.new()
	l.id = LevelDefinition.PARQUE
	l.order = 5
	l.name = "Parque solar provincial"
	l.subtitle = "Todo junto: falla, nubes y Zonda"
	l.story = "La gran obra: un parque que abastece a un barrio. Hay un conector flojo, nubes por la mañana y Zonda por la tarde."
	l.rows = 4
	l.panels_per_row = 4
	l.battery_slots = 4
	l.panel_kw = 0.6
	l.battery_kwh = 7.0
	l.inverter_kw = 9.0
	l.budget = 25000
	l.prices = prices()
	l.min_panels = 8
	l.loads = [
		LoadBlock.make(0, 24, 0.5, "Hospital", true),
		LoadBlock.make(10, 18, 1.0, "Escuelas y oficinas", false),
		LoadBlock.make(19, 23, 1.8, "Barrio", true),
		LoadBlock.make(23, 7, 0.4, "Alumbrado público", true),
	]
	l.has_pump = false
	l.events = LevelEvents.make(true, 14.0, [CloudBand.make(10, 12, 0.5)] as Array[CloudBand])
	l.start_hour = 10.0
	l.end_hour = 31.0
	l.start_soc = 0.15
	l.rewards = [30, 30, 40]
	l.two_star_soc = 0.3
	l.three_star_spend = 0.93
	l.requires = LevelDefinition.PUEBLO
	l.unlock_cost_soles = 300
	return l
