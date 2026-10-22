/**
 * Equipos de la planta: inversor, protección (se instala), baterías (se instalan en bases),
 * tablero, caja de conexión, consola de activación y bomba.
 * Cada uno conoce su punto de acceso (approach) y su terminal en coordenadas de mundo.
 */
import * as THREE from 'three';
import type { EquipmentModel } from '../../contracts';
import type { ModelFactory } from '../assets';

function worldTerminal(model: EquipmentModel): THREE.Vector3 {
  model.root.updateMatrixWorld(true);
  return model.root.localToWorld(model.terminal.clone());
}

/** Base común: modelo ubicado + punto de acceso al frente (+Z). */
abstract class Placed {
  readonly approach: THREE.Vector3;
  constructor(readonly pos: THREE.Vector3, approachDz: number) {
    this.approach = new THREE.Vector3(pos.x, 0, pos.z + approachDz);
  }
}

export class Inverter extends Placed {
  readonly model: EquipmentModel;
  readonly terminal: THREE.Vector3;
  private lastScreen = '';
  constructor(f: ModelFactory, pos: THREE.Vector3) {
    super(pos, 1.5);
    this.model = f.createInverter();
    this.model.root.position.copy(pos);
    this.terminal = worldTerminal(this.model);
    this.setScreen('STANDBY', '#8fa7a1');
  }
  /** Punto de entrada para cada color (los prensacables están separados). */
  terminalFor(kind: 'pv' | 'bat' | 'ac'): THREE.Vector3 {
    const dx = kind === 'pv' ? -0.3 : kind === 'bat' ? -0.1 : 0.1;
    return this.terminal.clone().add(new THREE.Vector3(dx, 0, 0));
  }
  setScreen(text: string, color?: string): void {
    const key = text + (color ?? '');
    if (key === this.lastScreen) return;
    this.lastScreen = key;
    this.model.setScreen?.(text, color);
  }
}

export class ProtectionSlot extends Placed {
  readonly root = new THREE.Group();
  private readonly ghost: THREE.Mesh;
  private model: EquipmentModel | null = null;
  terminal: THREE.Vector3;
  constructor(private readonly f: ModelFactory, pos: THREE.Vector3) {
    super(pos, 1.5);
    this.root.position.copy(pos);
    this.ghost = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.8, 0.22), f.mats.ghost);
    this.ghost.position.set(0, 1.5, 0.11);
    this.root.add(this.ghost);
    this.terminal = pos.clone().add(new THREE.Vector3(0, 1.06, 0.11));
  }
  get installed(): boolean { return this.model !== null; }
  install(): void {
    if (this.model) return;
    this.model = this.f.createProtectionBox();
    this.root.add(this.model.root);
    this.ghost.visible = false;
    this.terminal = worldTerminal(this.model);
  }
}

export class BatterySlot extends Placed {
  readonly root = new THREE.Group();
  private readonly ghost: THREE.Mesh;
  private model: (EquipmentModel & { setCharge(p: number): void }) | null = null;
  terminal: THREE.Vector3;
  constructor(private readonly f: ModelFactory, readonly index: number, pos: THREE.Vector3) {
    super(pos, 1.3);
    this.root.position.copy(pos);
    this.ghost = new THREE.Mesh(new THREE.BoxGeometry(1.0, 1.4, 0.6), f.mats.ghost);
    this.ghost.position.set(0, 0.7, 0);
    this.root.add(this.ghost);
    this.terminal = pos.clone().add(new THREE.Vector3(0.35, 1.25, 0.34));
  }
  get installed(): boolean { return this.model !== null; }
  install(): void {
    if (this.model) return;
    this.model = this.f.createBattery();
    this.root.add(this.model.root);
    this.ghost.visible = false;
    this.terminal = worldTerminal(this.model);
  }
  setGhostVisible(on: boolean): void { this.ghost.visible = on && !this.model; }
  setCharge(p: number): void { this.model?.setCharge(p); }
}

export class Switchboard extends Placed {
  readonly model: EquipmentModel;
  readonly terminal: THREE.Vector3;
  /** Salida hacia la línea de la ciudad (arriba del gabinete). */
  readonly lineOut: THREE.Vector3;
  constructor(f: ModelFactory, pos: THREE.Vector3) {
    super(pos, 1.5);
    this.model = f.createSwitchboard();
    this.model.root.position.copy(pos);
    this.terminal = worldTerminal(this.model);
    this.lineOut = pos.clone().add(new THREE.Vector3(0.25, 2.1, 0.1));
  }
}

export class JunctionBox extends Placed {
  readonly model: EquipmentModel;
  readonly terminal: THREE.Vector3;
  constructor(f: ModelFactory, pos: THREE.Vector3) {
    super(pos, 1.25);
    this.model = f.createJunctionBox();
    this.model.root.position.copy(pos);
    this.terminal = worldTerminal(this.model);
  }
}

export class ControlConsole extends Placed {
  readonly model: EquipmentModel & { setActive(on: boolean): void };
  constructor(f: ModelFactory, pos: THREE.Vector3) {
    super(pos, 1.25);
    this.model = f.createConsole();
    this.model.root.position.copy(pos);
  }
  setActive(on: boolean): void { this.model.setActive(on); }
}

export class Pump extends Placed {
  readonly model: EquipmentModel & { setRunning(on: boolean): void };
  readonly terminal: THREE.Vector3;
  private running = false;
  constructor(f: ModelFactory, pos: THREE.Vector3) {
    super(pos, 2.6);
    this.model = f.createPump();
    this.model.root.position.copy(pos);
    this.terminal = worldTerminal(this.model);
  }
  setRunning(on: boolean): void {
    if (on === this.running) return;
    this.running = on;
    this.model.setRunning(on);
  }
}
