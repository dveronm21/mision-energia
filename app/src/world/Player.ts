/**
 * Player: el técnico. Movimiento relativo a la cámara con joystick/teclado, giro suave,
 * colisiones con Colliders, altura del piso (platea de la sala) y animación del WorkerRig.
 */
import * as THREE from 'three';
import type { WorkerRig } from '../contracts';
import type { Colliders } from './Colliders';

export type Pose = 'idle' | 'carry' | 'cable' | 'tool';

const RADIUS = 0.38;
const SPEED = 5.0;

export class Player {
  readonly root: THREE.Group;
  private heading = Math.PI;
  private speed01 = 0;
  private y = 0;
  /** Multiplicador de velocidad (carga, viento). */
  speedFactor = 1;
  pose: Pose = 'idle';

  constructor(
    readonly rig: WorkerRig,
    private readonly colliders: Colliders,
    private readonly floorAt: (x: number, z: number) => number,
    spawn: THREE.Vector3,
  ) {
    this.root = rig.root;
    this.root.position.copy(spawn);
    this.root.rotation.y = this.heading;
  }

  get position(): THREE.Vector3 { return this.root.position; }

  /** Vector "adelante" del personaje en XZ. */
  forward(out = new THREE.Vector3()): THREE.Vector3 {
    return out.set(Math.sin(this.heading), 0, Math.cos(this.heading));
  }

  /** mx, my en −1..1 (my −1 = avanzar), camYaw = ángulo de la cámara alrededor del jugador. */
  update(dt: number, mx: number, my: number, camYaw: number): void {
    const mag = Math.min(1, Math.hypot(mx, my));
    const p = this.root.position;
    if (mag > 0.08) {
      const fx = -Math.sin(camYaw), fz = -Math.cos(camYaw);
      const rx = Math.cos(camYaw), rz = -Math.sin(camYaw);
      let dx = rx * mx - fx * my, dz = rz * mx - fz * my;
      const l = Math.hypot(dx, dz) || 1;
      dx /= l; dz /= l;
      const v = SPEED * mag * this.speedFactor;
      p.x += dx * v * dt;
      p.z += dz * v * dt;
      const target = Math.atan2(dx, dz);
      let d = target - this.heading;
      d = Math.atan2(Math.sin(d), Math.cos(d));
      this.heading += d * Math.min(1, dt * 12);
      this.root.rotation.y = this.heading;
    }
    this.colliders.resolve(p, RADIUS);
    const floor = this.floorAt(p.x, p.z);
    this.y += (floor - this.y) * Math.min(1, dt * 14);
    p.y = this.y;
    this.speed01 += ((mag > 0.08 ? mag : 0) - this.speed01) * Math.min(1, dt * 10);
    this.rig.animate(dt, this.speed01, this.pose);
  }

  /** Teletransporte (debug y reinicio). */
  teleport(x: number, z: number, faceTo?: THREE.Vector3): void {
    const p = this.root.position;
    p.set(x, 0, z);
    this.colliders.resolve(p, RADIUS);
    this.y = this.floorAt(p.x, p.z);
    p.y = this.y;
    if (faceTo) {
      this.heading = Math.atan2(faceTo.x - p.x, faceTo.z - p.z);
      this.root.rotation.y = this.heading;
    }
  }
}
