import type { LevelDefinition, ShopPrices } from '../contracts';

/**
 * Los 5 niveles de la campaña. Números didácticos (no dimensionamiento real), ajustados con `npm run balance`:
 * cada nivel se gana con una compra razonable + juego atento, y pierde (o baja estrellas) ante cada error típico.
 * Horas: startHour 10 (activación) → endHour 31 (07:00 del día siguiente).
 */
const PRICES: ShopPrices = { panel: 900, battery: 3200, kitZonda: 700, basePackage: 600 };

export const LEVELS: LevelDefinition[] = [
  {
    id: 'casa', order: 1, name: 'Casa familiar',
    subtitle: 'Que la casa tenga luz toda la noche',
    story: 'La familia Quiroga quiere su propia energía solar. Es tu primera obra: armá la fila de paneles, instalá la batería y conectá todo.',
    rows: 1, panelsPerRow: 4, batterySlots: 1,
    panelKw: 0.6, batteryKwh: 7, inverterKw: 3,
    budget: 7400, prices: PRICES, minPanels: 2,
    loads: [
      { from: 0, to: 24, kw: 0.2, label: 'Heladera', essential: true },
      { from: 10, to: 18, kw: 0.3, label: 'Lavarropas y cocina', essential: false },
      { from: 19, to: 23, kw: 0.9, label: 'Luces y TV', essential: true },
    ],
    hasPump: false,
    events: { looseConnector: false, zondaAtHour: null, clouds: [] },
    startHour: 10, endHour: 31, startSoc: 0.2,
    rewards: [10, 10, 15], twoStarSoc: 0.15, threeStarSpend: 0.9,
    requires: null, unlockCostSoles: 0,
  },
  {
    id: 'escuela', order: 2, name: 'Escuela rural',
    subtitle: 'Encontrá la falla y dejá la escuela iluminada',
    story: 'La escuela albergue necesita luz para el turno noche y la guardia. Ojo: uno de los paneles vino con un conector flojo.',
    rows: 2, panelsPerRow: 3, batterySlots: 2,
    panelKw: 0.6, batteryKwh: 7, inverterKw: 4,
    budget: 12000, prices: PRICES, minPanels: 3,
    loads: [
      { from: 0, to: 24, kw: 0.2, label: 'Heladera del comedor', essential: true },
      { from: 10, to: 17, kw: 0.6, label: 'Aulas y computadoras', essential: false },
      { from: 18, to: 22, kw: 1.0, label: 'Turno noche', essential: true },
      { from: 22, to: 7, kw: 0.3, label: 'Luces de guardia', essential: true },
    ],
    hasPump: false,
    events: { looseConnector: true, zondaAtHour: null, clouds: [] },
    startHour: 10, endHour: 31, startSoc: 0.15,
    rewards: [15, 15, 20], twoStarSoc: 0.2, threeStarSpend: 0.9,
    requires: 'casa', unlockCostSoles: 120,
  },
  {
    id: 'finca', order: 3, name: 'Finca en el valle',
    subtitle: 'Regá de día, iluminá de noche… y aguantá el Zonda',
    story: 'En la finca la bomba solar riega las vides al mediodía. A la siesta se anuncia viento Zonda: protegé los paneles y limpialos cuando pase.',
    rows: 2, panelsPerRow: 4, batterySlots: 2,
    panelKw: 0.6, batteryKwh: 7, inverterKw: 5,
    budget: 13500, prices: PRICES, minPanels: 4,
    loads: [
      { from: 0, to: 24, kw: 0.2, label: 'Heladera y cámara de frío', essential: true },
      { from: 11, to: 16, kw: 1.2, label: 'Bomba de riego', essential: true },
      { from: 19, to: 23, kw: 1.0, label: 'Casa y galpón', essential: true },
      { from: 23, to: 7, kw: 0.3, label: 'Luces del patio', essential: false },
    ],
    hasPump: true,
    events: { looseConnector: false, zondaAtHour: 13, clouds: [] },
    startHour: 10, endHour: 31, startSoc: 0.15,
    rewards: [20, 20, 25], twoStarSoc: 0.3, threeStarSpend: 0.9,
    requires: 'escuela', unlockCostSoles: 180,
  },
  {
    id: 'pueblo', order: 4, name: 'Pueblo de montaña',
    subtitle: 'Nubes de mañana, presupuesto justo',
    story: 'Un pueblo entero depende de tu planta. La mañana viene nublada y el presupuesto no alcanza para todo: elegí bien qué comprar.',
    rows: 3, panelsPerRow: 4, batterySlots: 3,
    panelKw: 0.6, batteryKwh: 7, inverterKw: 7,
    budget: 18500, prices: PRICES, minPanels: 6,
    loads: [
      { from: 0, to: 24, kw: 0.4, label: 'Sala de salud', essential: true },
      { from: 10, to: 18, kw: 0.8, label: 'Comercios', essential: false },
      { from: 19, to: 23, kw: 1.4, label: 'Casas', essential: true },
      { from: 23, to: 7, kw: 0.3, label: 'Alumbrado público', essential: true },
    ],
    hasPump: false,
    events: { looseConnector: false, zondaAtHour: null, clouds: [{ from: 10, to: 13, factor: 0.45 }] },
    startHour: 10, endHour: 31, startSoc: 0.15,
    rewards: [25, 25, 30], twoStarSoc: 0.3, threeStarSpend: 0.95,
    requires: 'finca', unlockCostSoles: 240,
  },
  {
    id: 'parque', order: 5, name: 'Parque solar provincial',
    subtitle: 'Todo junto: falla, nubes y Zonda',
    story: 'La gran obra: un parque que abastece a un barrio. Hay un conector flojo, nubes por la mañana y Zonda por la tarde.',
    rows: 4, panelsPerRow: 4, batterySlots: 4,
    panelKw: 0.6, batteryKwh: 7, inverterKw: 9,
    budget: 25000, prices: PRICES, minPanels: 8,
    loads: [
      { from: 0, to: 24, kw: 0.5, label: 'Hospital', essential: true },
      { from: 10, to: 18, kw: 1.0, label: 'Escuelas y oficinas', essential: false },
      { from: 19, to: 23, kw: 1.8, label: 'Barrio', essential: true },
      { from: 23, to: 7, kw: 0.4, label: 'Alumbrado público', essential: true },
    ],
    hasPump: false,
    events: { looseConnector: true, zondaAtHour: 14, clouds: [{ from: 10, to: 12, factor: 0.5 }] },
    startHour: 10, endHour: 31, startSoc: 0.15,
    rewards: [30, 30, 40], twoStarSoc: 0.3, threeStarSpend: 0.93,
    requires: 'pueblo', unlockCostSoles: 300,
  },
];
