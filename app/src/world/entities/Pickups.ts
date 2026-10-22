/**
 * Cosas que se levantan del piso: el pallet de paneles, los cajones del depósito
 * y los paneles sueltos (soltados por el jugador o arrancados por el Zonda).
 */
import * as THREE from 'three';
import type { ModelFactory } from '../assets';
import type { Aabb, Colliders } from '../Colliders';
import type { CarryKind } from '../interaction/types';

export class Pallet {
  readonly root: THREE.Group;
  readonly approach: THREE.Vector3;
  private readonly model: { root: THREE.Group; setCount(n: number): void };
  private left: number;
  /** Índice (en orden de retiro) del panel que viene con el conector flojo, o -1. */
  private readonly faultyIndex: number;
  private taken = 0;

  constructor(f: ModelFactory, pos: THREE.Vector3, count: number, looseConnector: boolean) {
    this.model = f.createPallet(count);
    this.root = this.model.root;
    this.root.position.copy(pos);
    this.root.rotation.y = 0.06;
    this.left = count;
    this.faultyIndex = looseConnector && count > 0 ? Math.min(count - 1, 1) : -1;
    this.approach = new THREE.Vector3(pos.x, 0, pos.z + 1.35);
  }

  get remaining(): number { return this.left; }

  /** Retira un panel. Devuelve si viene con conector flojo. */
  take(): boolean {
    if (this.left <= 0) return false;
    this.left--;
    this.model.setCount(this.left);
    return this.taken++ === this.faultyIndex;
  }
}

/** Objeto en el piso que se puede levantar: cajón (batería, protección, kit) o panel suelto. */
export class Pickup {
  readonly root: THREE.Group;
  readonly approach: THREE.Vector3;
  private readonly box: Aabb;

  constructor(
    f: ModelFactory,
    readonly kind: CarryKind,
    pos: THREE.Vector3,
    readonly faulty: boolean,
    private readonly colliders: Colliders,
    yaw = 0,
  ) {
    this.root = new THREE.Group();
    this.root.name = 'pickup-' + kind;
    if (kind === 'panel') {
      const p = f.createPanel();
      p.root.position.y = 0.06;
      this.root.add(p.root);
      this.box = colliders.add(pos.x, pos.z, 0.2, 0.2);
    } else {
      this.root.add(f.createCrate(kind));
      this.box = colliders.add(pos.x, pos.z, 0.45, 0.45);
    }
    this.root.position.copy(pos);
    this.root.rotation.y = yaw;
    this.approach = new THREE.Vector3(pos.x, 0, pos.z + (kind === 'panel' ? 1.0 : 1.1));
  }

  dispose(): void {
    this.colliders.remove(this.box);
    this.root.removeFromParent();
    this.root.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.isMesh && this.kind === 'panel') (m.material as THREE.Material).dispose();
    });
  }
}
