/**
 * CONTRATOS ENTRE MÓDULOS — Misión Energía 0.3
 *
 * Este archivo es la fuente de verdad de las interfaces entre equipos:
 *  - Dominio (sim/, levels/, economy/, core/)  → lógica pura, sin three.js ni DOM (salvo SaveStore/Audio).
 *  - Gráficos (world/assets/)                  → modelos, materiales, ambiente, post-proceso (three.js).
 *  - Juego + UI (world/, ui/, main.ts)          → integra todo.
 *
 * Regla: no cambiar firmas acá sin actualizar a todos los consumidores.
 * Unidades: potencia en kW, energía en kWh, hora del día en horas decimales (10.5 = 10:30),
 * la noche siguiente se representa con horas > 24 (30 = 06:00 del día siguiente).
 */

import type * as THREE from 'three';

/* ======================================================================
 * 1. NIVELES
 * ==================================================================== */

export type LevelId = 'casa' | 'escuela' | 'finca' | 'pueblo' | 'parque';

/** Perfil de consumo: kW por franja horaria. Se evalúa por hora del día (0..24). */
export interface LoadBlock { from: number; to: number; kw: number; label: string; essential: boolean; }

export interface LevelEvents {
  /** Un panel viene con conector flojo: abre su fila (en serie) hasta que se repare con el multímetro. */
  looseConnector: boolean;
  /** Viento Zonda: hora del día en que empieza el aviso, o null si no hay. */
  zondaAtHour: number | null;
  /** Nubes: lista de franjas con factor de irradiancia (0..1). */
  clouds: { from: number; to: number; factor: number }[];
}

export interface ShopPrices {
  panel: number;        // créditos de obra por panel
  battery: number;      // por batería
  kitZonda: number;     // trabas anti-Zonda
  basePackage: number;  // inversor + protección + tablero (obligatorio)
}

export interface LevelDefinition {
  id: LevelId;
  order: number;                 // 1..5
  name: string;                  // "Casa familiar"
  subtitle: string;              // una línea de objetivo
  story: string;                 // 1-2 frases de contexto
  rows: number;                  // filas de paneles (cada fila en serie)
  panelsPerRow: number;
  batterySlots: number;
  panelKw: number;               // kW pico por panel (didáctico)
  batteryKwh: number;            // kWh útiles por batería
  inverterKw: number;            // límite de potencia del inversor
  budget: number;                // créditos de obra disponibles en el taller
  prices: ShopPrices;
  minPanels: number;             // mínimo para poder activar
  loads: LoadBlock[];            // consumo de la ciudad / finca
  hasPump: boolean;              // nivel con bomba solar (carga diurna extra en loads)
  events: LevelEvents;
  startHour: number;             // hora al activar (ej. 10)
  endHour: number;               // hora de fin (ej. 31 = 07:00 del día siguiente)
  startSoc: number;              // carga inicial de baterías (0..1)
  /** Recompensa en tokens (Soles) por 1, 2 y 3 estrellas. */
  rewards: [number, number, number];
  /** Estrellas: 1 = llega al final; 2 = y batería final ≥ twoStarSoc; 3 = y gasto ≤ threeStarSpend del presupuesto (0..1) y sin paneles perdidos. */
  twoStarSoc: number;
  threeStarSpend: number;
  /** Nivel requerido para desbloquear (o null). También se puede desbloquear antes pagando unlockCostSoles. */
  requires: LevelId | null;
  unlockCostSoles: number;
}

/** Compra que el jugador hace en el taller antes de construir. */
export interface Purchase { panels: number; batteries: number; kitZonda: boolean; }

export interface LevelProgress { unlocked: boolean; bestStars: 0 | 1 | 2 | 3; bestScore: number; completed: boolean; }

export interface ILevelCatalog {
  all(): LevelDefinition[];
  get(id: LevelId): LevelDefinition;
}

export interface ILevelManager {
  progress(id: LevelId): LevelProgress;
  isUnlocked(id: LevelId): boolean;
  /** Desbloqueo anticipado pagando Soles (usa la billetera). Devuelve false si no alcanza. */
  unlockWithSoles(id: LevelId): boolean;
  /** Registra un resultado; actualiza mejores marcas, desbloquea el siguiente y acredita Soles por estrellas NUEVAS. */
  recordResult(result: LevelResult): { solesEarned: number; newlyUnlocked: LevelId | null };
}

/* ======================================================================
 * 2. SIMULADOR ENERGÉTICO (puro, determinista, testeable)
 * ==================================================================== */

/** Estado físico de la planta que el mundo 3D le informa al simulador en cada paso. */
export interface PlantState {
  /** Paneles instalados por fila. */
  panelsPerRow: number[];
  /** Fila abierta por conector flojo (no genera). */
  rowOpen: boolean[];
  /** Fila con polvo (rinde dustLoss menos). */
  rowDirty: boolean[];
  /** Fila en posición de defensa (horizontal, rinde 0.55). */
  rowDefense: boolean[];
  batteries: number;
  protectionInstalled: boolean;
  cablesOk: boolean;           // los 3 cables conectados correctamente
  /** Cargas que el jugador apagó en "Salvá la ciudad" (por label). */
  shedLoads: string[];
  /** [AGREGADO 0.3, opcional] kWh extra de la "batería de emergencia" (booster boost_battery).
   *  Se lee solo en start(): suma esa capacidad al banco y la entrega ya cargada. */
  bonusKwh?: number;
}

export interface SimSnapshot {
  hour: number;
  irradiance: number;   // 0..1 (sol × nubes × tormenta)
  genKw: number;
  loadKw: number;
  netKw: number;        // gen - load (positivo = carga baterías)
  socKwh: number;
  capKwh: number;
  socPct: number;       // 0..1
  isNight: boolean;
  blackout: boolean;
  finished: boolean;
  won: boolean;
}

export type WeatherPhase = 'calm' | 'zonda-warning' | 'zonda-storm' | 'zonda-over';

export interface IEnergySimulator {
  /** Inicializa con nivel y planta al activar. */
  start(level: LevelDefinition, plant: PlantState): void;
  /** Avanza dtHours de reloj de juego con el estado actual de la planta. */
  step(dtHours: number, plant: PlantState, weather: WeatherPhase): SimSnapshot;
  snapshot(): SimSnapshot;
}

/* ======================================================================
 * 3. ECONOMÍA: TOKENS (Soles), CATÁLOGO, PAGOS
 * ==================================================================== */

/** Moneda premium del juego. Se gana jugando y se puede comprar. */
export const TOKEN_NAME = 'Soles';

export type ProductKind = 'token-pack' | 'booster' | 'cosmetic' | 'level-unlock';

export interface Product {
  id: string;                  // 'pack_small', 'boost_hint', 'skin_helmet_blue', ...
  kind: ProductKind;
  title: string;
  description: string;
  /** Para token-pack: cuántos Soles entrega. */
  soles?: number;
  /** Para token-pack: precio en moneda real (centavos) — en demo se muestra como "precio de prueba". */
  priceCents?: number;
  currency?: 'ARS' | 'USD';
  /** Para booster/cosmetic: precio en Soles. */
  costSoles?: number;
  /** Booster consumible (se descuenta al usar) o permanente. */
  consumable?: boolean;
  icon: string;                // id de ícono SVG del set de UI
}

export interface Inventory { [productId: string]: number; }

export interface IWallet {
  balance(): number;
  add(amount: number, reason: string): void;
  /** Gasta si alcanza; devuelve false si no. */
  spend(amount: number, reason: string): boolean;
  history(): { at: number; delta: number; reason: string }[];
  onChange(cb: (balance: number) => void): () => void;
}

export interface IInventory {
  count(productId: string): number;
  grant(productId: string, qty: number): void;
  consume(productId: string): boolean;
  equippedCosmetic(slot: 'helmet' | 'vest'): string | null;
  equip(slot: 'helmet' | 'vest', productId: string | null): void;
}

export type PaymentStatus = 'approved' | 'cancelled' | 'failed' | 'pending';
export interface PaymentResult { status: PaymentStatus; orderId: string; productId: string; message?: string; }

/**
 * Proveedor de pago intercambiable. Hoy: DemoPaymentProvider (simulado).
 * Mañana: MercadoPagoProvider (Checkout Pro + validación en servidor) o GooglePlayBillingProvider.
 * Regla de seguridad: un proveedor real NUNCA acredita tokens del lado del cliente sin una
 * confirmación del servidor (verifyOnServer). El demo marca sus órdenes con prefijo "DEMO-".
 */
export interface IPaymentProvider {
  readonly id: 'demo' | 'mercadopago' | 'googleplay';
  readonly isDemo: boolean;
  purchase(product: Product): Promise<PaymentResult>;
  /** Para proveedores reales: confirma con el backend antes de acreditar. Demo: aprueba. */
  verifyOnServer(result: PaymentResult): Promise<boolean>;
}

export interface IShop {
  catalog(): Product[];
  /** Compra un pack de Soles con dinero real (vía proveedor) y acredita si se verifica. */
  buyTokenPack(productId: string): Promise<PaymentResult>;
  /** Compra un booster / cosmético con Soles. */
  buyWithSoles(productId: string): boolean;
}

/** Control parental: pregunta simple antes de cualquier compra con dinero real. */
export interface IParentalGate {
  /** Genera un desafío (ej. "¿Cuánto es 7 × 8?"). */
  challenge(): { question: string; answer: number };
}

/* ======================================================================
 * 4. RESULTADOS Y PUNTAJE
 * ==================================================================== */

export interface LevelResult {
  levelId: LevelId;
  won: boolean;
  stars: 0 | 1 | 2 | 3;
  score: number;
  finalSocPct: number;
  spent: number;
  budget: number;
  panelsLost: number;
  blackoutHour: number | null;
  durationSec: number;
  tips: string[];                // consejos didácticos según qué falló
}

export interface IScoring {
  evaluate(level: LevelDefinition, input: {
    won: boolean; finalSocPct: number; spent: number; panelsLost: number;
    blackoutHour: number | null; durationSec: number;
    hadOpenRowAtEnd: boolean; hadDirtyRowAtEnd: boolean; batteries: number;
    /** [AGREGADO 0.3, opcional] paneles instalados (para el consejo "pocos paneles"). */
    panels?: number;
    /** [AGREGADO 0.3, opcional] true si quedaron cargas no esenciales encendidas de noche. */
    nonEssentialOn?: boolean;
  }): LevelResult;
}

/* ======================================================================
 * 5. INFRAESTRUCTURA
 * ==================================================================== */

/** Persistencia en localStorage con versión y respaldo en memoria si falla. */
export interface ISaveStore {
  load<T>(key: string, fallback: T): T;
  save<T>(key: string, value: T): void;
  clearAll(): void;
}

export type GameEvent =
  | { type: 'wallet-changed'; balance: number }
  | { type: 'level-started'; levelId: LevelId }
  | { type: 'level-finished'; result: LevelResult }
  | { type: 'toast'; text: string; kind?: 'good' | 'bad' | 'info' }
  | { type: 'sfx'; name: SfxName };

export interface IEventBus {
  on<T extends GameEvent['type']>(type: T, cb: (e: Extract<GameEvent, { type: T }>) => void): () => void;
  emit(e: GameEvent): void;
}

export type SfxName = 'pick' | 'place' | 'ok' | 'bad' | 'beep' | 'power' | 'alarm' | 'win' | 'lose' | 'coin' | 'click';

export interface IAudio {
  unlock(): void;               // llamar en el primer toque del usuario
  play(name: SfxName): void;
  setWind(on: boolean): void;
  setMuted(muted: boolean): void;
  muted(): boolean;
}

/* ======================================================================
 * 6. GRÁFICOS (world/assets) — fábricas que usa el mundo 3D
 * ==================================================================== */

export type QualityLevel = 'low' | 'medium' | 'high';

export interface GraphicsSettings {
  quality: QualityLevel;        // low: sin sombras suaves ni bloom; high: sombras 2048 + bloom
  pixelRatioCap: number;        // 1.0 / 1.5 / 2.0
}

/** Modelos procedurales (sin archivos externos). Todos con origen en el piso (y=0) y mirando a +Z. */
export interface IModelFactory {
  /** Personaje técnico con casco y chaleco; devuelve rig con huesos simples para animar. */
  createWorker(colors?: { helmet?: number; vest?: number }): WorkerRig;
  /** Panel solar (2.0 × 1.15 m) con marco, celdas y vidrio. Tiene un material de polvo activable. */
  createPanel(): PanelModel;
  /** Estructura de montaje inclinada; `tilt` es el grupo donde va el panel (rotation.x = inclinación). */
  createMount(): { root: THREE.Group; tilt: THREE.Group; ghost: THREE.Object3D };
  createInverter(): EquipmentModel;          // con pantalla (setScreen)
  createBattery(): EquipmentModel & { setCharge(pct: number): void };
  createProtectionBox(): EquipmentModel;
  createSwitchboard(): EquipmentModel;       // tablero
  createJunctionBox(): EquipmentModel;
  createConsole(): EquipmentModel & { setActive(on: boolean): void };
  createPump(): EquipmentModel & { setRunning(on: boolean): void };
  createCrate(kind: 'battery' | 'protection' | 'kit' | 'panel'): THREE.Group;
  createPallet(count: number): { root: THREE.Group; setCount(n: number): void };
  createRowPost(): { root: THREE.Group; setDefense(on: boolean): void };
  createTree(variant: number): THREE.Group;
  createBuilding(w: number, h: number, d: number, variant: number): { root: THREE.Group; setLights(intensity: number): void };
  createPowerPole(): THREE.Group;
  /** Cable con caída realista entre dos puntos (catenaria aprox.), con color. Devuelve curva para partículas. */
  createCable(points: THREE.Vector3[], color: number, radius?: number): { mesh: THREE.Mesh; curve: THREE.Curve<THREE.Vector3>; setGlow(v: number): void };
  /** Etiqueta flotante legible (sprite). */
  createLabel(text: string, opts?: { bg?: string; scale?: number }): THREE.Sprite;
}

export interface WorkerRig {
  root: THREE.Group;
  /** Anclaje sobre la cabeza para objetos cargados. */
  carryAnchor: THREE.Group;
  /** Anclaje en la mano derecha (multímetro, cable). */
  handAnchor: THREE.Group;
  /** speed 0..1, pose de brazos. */
  animate(dt: number, speed: number, pose: 'idle' | 'carry' | 'cable' | 'tool'): void;
  setCosmetics(c: { helmet?: number; vest?: number }): void;
}

export interface PanelModel { root: THREE.Group; setDirty(on: boolean): void; setGlow(v: number): void; }

export interface EquipmentModel {
  root: THREE.Group;
  /** Punto (local) donde llegan/salen los cables. */
  terminal: THREE.Vector3;
  setScreen?(text: string, color?: string): void;
}

/** Ambiente: cielo, luces, terreno, montañas, polvo, estrellas, niebla. */
export interface IEnvironment {
  readonly scene: THREE.Scene;
  /** hour: hora del día; zonda: 0..1 intensidad de tormenta; clouds: 0..1. */
  update(dt: number, hour: number, opts: { zonda: number; clouds: number; follow: THREE.Vector3 }): void;
  /** Factor 0..1 de noche (para luces de la ciudad). */
  nightFactor(): number;
}

export interface IRendererFacade {
  readonly renderer: THREE.WebGLRenderer;
  readonly camera: THREE.PerspectiveCamera;
  render(scene: THREE.Scene): void;
  resize(w: number, h: number): void;
  setQuality(s: GraphicsSettings): void;
}
