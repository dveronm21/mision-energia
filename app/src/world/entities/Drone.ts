/**
 * Drone: dron limpiador (booster). Despega del depósito, barre cada fila sucia volando sobre los
 * paneles (al terminar la fila avisa onRowClean) y vuelve. Modelo procedural simple (2 draw calls).
 */
import * as THREE from 'three';

interface Leg { to: THREE.Vector3; row: number | null; }

export class Drone {
  readonly root = new THREE.Group();
  private readonly rotors: THREE.Mesh[] = [];
  private readonly spray: THREE.Mesh;
  private legs: Leg[] = [];
  private busy = false;
  private time = 0;
  private readonly home: THREE.Vector3;

  constructor(home: THREE.Vector3, private readonly onRowClean: (row: number) => void) {
    this.home = home.clone();
    const body = new THREE.MeshStandardMaterial({ color: 0xf1f4f2, roughness: 0.4, metalness: 0.2 });
    const dark = new THREE.MeshStandardMaterial({ color: 0x24423c, roughness: 0.5 });
    const core = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.18, 0.5), body);
    core.castShadow = true;
    this.root.add(core);
    const stripe = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.05, 0.52), new THREE.MeshStandardMaterial({ color: 0xffb82e, emissive: 0xffb82e, emissiveIntensity: 0.4 }));
    stripe.position.y = 0.03;
    this.root.add(stripe);
    for (const [x, z] of [[0.42, 0.42], [-0.42, 0.42], [0.42, -0.42], [-0.42, -0.42]]) {
      const arm = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.05, 0.62), dark);
      arm.position.set(x / 2, 0, z / 2);
      arm.rotation.y = Math.atan2(x, z);
      this.root.add(arm);
      const rotor = new THREE.Mesh(new THREE.BoxGeometry(0.46, 0.015, 0.06), dark);
      rotor.position.set(x, 0.1, z);
      this.root.add(rotor);
      this.rotors.push(rotor);
    }
    this.spray = new THREE.Mesh(new THREE.ConeGeometry(0.9, 1.6, 12, 1, true),
      new THREE.MeshBasicMaterial({ color: 0xbfeaff, transparent: true, opacity: 0.28, depthWrite: false, side: THREE.DoubleSide }));
    this.spray.position.y = -0.85;
    this.spray.visible = false;
    this.root.add(this.spray);
    this.root.position.copy(this.home);
    this.root.visible = false;
  }

  get active(): boolean { return this.busy; }

  /** rows: para cada fila sucia, extremos oeste/este (a la altura de los paneles). */
  start(rows: { row: number; from: THREE.Vector3; to: THREE.Vector3 }[]): void {
    if (!rows.length) return;
    this.legs = [];
    for (const r of rows) {
      this.legs.push({ to: r.from.clone().setY(3.2), row: null });
      this.legs.push({ to: r.to.clone().setY(2.6), row: r.row });
    }
    this.legs.push({ to: this.home.clone().setY(4), row: null }, { to: this.home.clone(), row: null });
    this.root.position.copy(this.home);
    this.root.visible = true;
    this.busy = true;
  }

  update(dt: number): void {
    this.time += dt;
    for (const r of this.rotors) r.rotation.y += dt * 40;
    if (!this.busy) return;
    const leg = this.legs[0];
    const p = this.root.position;
    const d = p.distanceTo(leg.to);
    const speed = leg.row !== null ? 2.6 : 6;
    this.spray.visible = leg.row !== null;
    if (d < 0.08) {
      if (leg.row !== null) this.onRowClean(leg.row);
      this.legs.shift();
      if (!this.legs.length) { this.busy = false; this.root.visible = false; this.spray.visible = false; }
      return;
    }
    p.addScaledVector(leg.to.clone().sub(p).normalize(), Math.min(d, speed * dt));
    this.root.rotation.z = Math.sin(this.time * 3) * 0.05;
    p.y += Math.sin(this.time * 5) * 0.004;
  }
}
