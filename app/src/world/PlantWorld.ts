/**
 * PlantWorld: arma el mundo 3D de un nivel a partir del LevelLayout (entidades + colisionadores)
 * y responde preguntas sobre el estado físico (paneles por fila, filas abiertas, etc.).
 */
import * as THREE from 'three';
import type { LevelDefinition, Purchase } from '../contracts';
import type { ModelFactory } from './assets';
import { Colliders } from './Colliders';
import { buildLayout, onSlab, type LevelLayout } from './LevelLayout';
import { CableNetwork, type CableRun } from './entities/Cable';
import { City } from './entities/City';
import { Drone } from './entities/Drone';
import { EnergyFlow } from './entities/EnergyFlow';
import { BatterySlot, ControlConsole, Inverter, JunctionBox, ProtectionSlot, Pump, Switchboard } from './entities/Equipment';
import { Mount } from './entities/Mount';
import { Pallet, Pickup } from './entities/Pickups';
import { RowPost } from './entities/RowPost';
import type { CarryKind } from './interaction/types';

export class PlantWorld {
  readonly root = new THREE.Group();
  readonly layout: LevelLayout;
  readonly colliders: Colliders;
  readonly mounts: Mount[] = [];
  readonly rows: Mount[][] = [];
  readonly posts: RowPost[] = [];
  readonly pallet: Pallet;
  readonly pickups: Pickup[] = [];
  readonly junction: JunctionBox;
  readonly inverter: Inverter;
  readonly protection: ProtectionSlot;
  readonly batteries: BatterySlot[] = [];
  readonly switchboard: Switchboard;
  readonly console: ControlConsole;
  readonly pump: Pump | null;
  readonly cables: CableNetwork;
  readonly rowWires: (CableRun | null)[];
  protectionLink: CableRun | null = null;
  readonly pumpWire: CableRun | null = null;
  readonly city: City;
  readonly flow = new EnergyFlow();
  readonly drone: Drone;
  kitInstalled = false;
  private readonly palletLabel: THREE.Sprite;
  private readonly roomLight: THREE.PointLight;
  private readonly lampMat: THREE.MeshBasicMaterial;

  constructor(private readonly f: ModelFactory, readonly level: LevelDefinition, purchase: Purchase, onRowCleanByDrone: (row: number) => void) {
    this.root.name = 'plant-world';
    const L = (this.layout = buildLayout(level, purchase));
    const col = (this.colliders = new Colliders(L.bounds));
    const add = <T extends THREE.Object3D>(o: T): T => { this.root.add(o); return o; };
    const label = (text: string, pos: THREE.Vector3, scale = 0.6, bg?: string) => {
      const s = f.createLabel(text, { scale, bg });
      s.position.copy(pos);
      return add(s);
    };

    // Campo solar
    for (const row of L.rows) {
      const list: Mount[] = [];
      row.mounts.forEach((p, i) => {
        const m = new Mount(f, row.index, i, p);
        add(m.root);
        col.add(p.x, p.z, 1.0, 0.55);
        list.push(m);
        this.mounts.push(m);
      });
      this.rows.push(list);
      const post = new RowPost(f, row.index, row.post);
      add(post.root);
      col.add(row.post.x, row.post.z, 0.22, 0.22);
      this.posts.push(post);
    }
    label('CAMPO SOLAR', L.fieldLabel, 0.75);
    this.rowWires = L.rows.map(() => null);

    this.junction = new JunctionBox(f, L.junction);
    add(this.junction.model.root);
    col.add(L.junction.x, L.junction.z, 0.3, 0.25);

    // Sala de equipos
    const R = L.room;
    const slab = f.createSlab(R.slab.w, R.slab.d);
    slab.position.set(R.slab.x, 0, R.slab.z);
    add(slab);
    const wall = f.createWall(R.slab.w, 3.1);
    wall.position.set(R.slab.x, R.floorY, R.wallZ);
    add(wall);
    const canopy = f.createCanopy(R.slab.w + 0.4, 2.2, 3.4);
    canopy.position.set(R.slab.x, R.floorY, R.wallZ + 0.8);
    add(canopy);
    col.add(R.slab.x, R.wallZ - 0.15, R.slab.w / 2, 0.45);
    label('SALA DE EQUIPOS', R.label, 0.7);
    // Luz de la sala: se enciende de noche con la energía de las baterías (siempre presente para no recompilar shaders).
    this.roomLight = new THREE.PointLight(0xffd9a0, 0, 13, 1.2);
    this.roomLight.position.set(R.slab.x, R.floorY + 2.9, R.wallZ + 1.6);
    add(this.roomLight);
    this.lampMat = new THREE.MeshBasicMaterial({ color: 0x4a4740, toneMapped: false });
    const lamp = new THREE.Mesh(new THREE.BoxGeometry(5, 0.05, 0.12), this.lampMat);
    lamp.position.set(R.slab.x, R.floorY + 3.28, R.wallZ + 1.0);
    add(lamp);

    this.inverter = new Inverter(f, R.inverter);
    add(this.inverter.model.root);
    this.protection = new ProtectionSlot(f, R.protection);
    add(this.protection.root);
    R.batteries.forEach((p, i) => {
      const b = new BatterySlot(f, i, p);
      add(b.root);
      this.batteries.push(b);
    });
    this.switchboard = new Switchboard(f, R.switchboard);
    add(this.switchboard.model.root);
    col.add(R.inverter.x, R.wallZ + 0.2, 0.6, 0.25);
    col.add(R.switchboard.x, R.wallZ + 0.15, 0.5, 0.2);
    this.console = new ControlConsole(f, R.console);
    add(this.console.model.root);
    col.add(R.console.x, R.console.z, 0.45, 0.4);
    label('ACTIVAR PLANTA', R.console.clone().setY(1.75), 0.55, 'rgba(185,120,26,0.94)');

    this.pump = L.pump ? new Pump(f, L.pump) : null;
    if (this.pump && L.pump) {
      add(this.pump.model.root);
      col.add(L.pump.x - 0.35, L.pump.z + 0.75, 0.8, 1.3);
      label('BOMBA DE RIEGO', L.pump.clone().setY(1.9), 0.45);
    }

    // Depósito y pallet
    this.pallet = new Pallet(f, L.pallet, purchase.panels, level.events.looseConnector);
    add(this.pallet.root);
    col.add(L.pallet.x, L.pallet.z, 1.1, 0.66);
    this.palletLabel = label('PANELES', L.pallet.clone().setY(1.3), 0.5);
    for (const c of L.crates) this.addPickup(c.kind, c.pos, false, (c.pos.x * 0.37) % 0.3 - 0.15);
    label('DEPÓSITO', L.depotLabel, 0.6);

    // Cables, ciudad, energía y dron
    this.cables = new CableNetwork(f, (x, z) => this.floorAt(x, z));
    add(this.cables.root);
    this.city = new City(f, L, this.switchboard.lineOut, this.cables);
    add(this.city.root);
    if (this.pump) {
      const pts = this.cables.groundRoute(this.switchboard.terminal, this.pump.terminal, { z: -4.6 });
      this.pumpWire = this.cables.run(pts, 0x55605d, 0.03);
    }
    add(this.flow.mesh);
    this.drone = new Drone(new THREE.Vector3(L.crates[0].pos.x - 1.2, 0.3, L.crates[0].pos.z + 2.4), onRowCleanByDrone);
    add(this.drone.root);
  }

  /** Altura del piso (la platea de la sala está 16 cm arriba). */
  floorAt(x: number, z: number): number {
    return onSlab(this.layout, x, z, -0.05) ? this.layout.room.floorY : 0;
  }

  addPickup(kind: CarryKind, pos: THREE.Vector3, faulty: boolean, yaw = 0): Pickup {
    const p = new Pickup(this.f, kind, pos, faulty, this.colliders, yaw);
    this.root.add(p.root);
    this.pickups.push(p);
    return p;
  }

  removePickup(p: Pickup): void {
    const i = this.pickups.indexOf(p);
    if (i >= 0) this.pickups.splice(i, 1);
    p.dispose();
  }

  /* -------------------------------------------------- consultas de estado físico */

  panelsInRow(r: number): number { return this.rows[r].filter((m) => m.filled).length; }
  panelsInstalled(): number { return this.mounts.filter((m) => m.filled).length; }
  rowOpen(r: number): boolean { return this.rows[r].some((m) => m.filled && m.faulty); }
  anyFaulty(): boolean { return this.mounts.some((m) => m.filled && m.faulty); }
  batteriesInstalled(): number { return this.batteries.filter((b) => b.installed).length; }
  rowDirty(r: number): boolean { return this.rows[r].some((m) => m.isDirty); }

  /** Crea (una vez) el cable de la fila hasta la caja de conexión. */
  ensureRowWire(r: number): void {
    if (this.rowWires[r]) return;
    const row = this.layout.rows[r];
    const pts = this.cables.groundRoute(row.wireStart, this.junction.terminal.clone().add(new THREE.Vector3(-0.12 + r * 0.06, 0, 0)), { x: -3.0 + r * 0.12 });
    this.rowWires[r] = this.cables.run(pts, 0x30383b, 0.025);
  }

  /** Cable fijo protección → inversor (al instalar la protección). */
  linkProtection(): void {
    if (this.protectionLink) return;
    const pts = this.cables.groundRoute(this.protection.terminal, this.inverter.terminalFor('pv'), { z: this.layout.room.wallZ + 0.42 });
    this.protectionLink = this.cables.run(pts, 0xf28c28, 0.03);
  }

  /** Luz de la sala de equipos (0..1). */
  setRoomLight(v: number): void {
    this.roomLight.intensity = v * 9;
    this.lampMat.color.setRGB(0.29 + v * 2.2, 0.28 + v * 1.9, 0.25 + v * 1.4);
  }

  /** dt: tiempo real; droneDt: tiempo del dron (acompaña la velocidad del reloj). */
  update(dt: number, droneDt = dt): void {
    for (const m of this.mounts) m.update(dt);
    this.drone.update(droneDt);
    this.flow.update(dt);
    this.palletLabel.visible = this.pallet.remaining > 0;
  }

  /** Libera geometrías, materiales y texturas propias del nivel. */
  dispose(): void {
    this.root.removeFromParent();
    const geos = new Set<THREE.BufferGeometry>(), mats = new Set<THREE.Material>(), texs = new Set<THREE.Texture>();
    this.root.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.geometry) geos.add(m.geometry);
      const mm = m.material as THREE.Material | THREE.Material[] | undefined;
      if (mm) (Array.isArray(mm) ? mm : [mm]).forEach((x) => {
        mats.add(x);
        const map = (x as THREE.SpriteMaterial).map;
        if (o instanceof THREE.Sprite && map) texs.add(map);
      });
    });
    geos.forEach((g) => g.dispose());
    mats.forEach((m) => m.dispose());
    texs.forEach((t) => t.dispose());
  }
}
