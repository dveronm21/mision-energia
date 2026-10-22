/**
 * HandsController: qué tiene el técnico en las manos (nada, una carga sobre la cabeza, un cable o el
 * multímetro) y su representación 3D en los anclajes del WorkerRig.
 */
import * as THREE from 'three';
import type { WorkerRig } from '../contracts';
import type { ModelFactory } from './assets';
import type { CarriedItem, CableColor, Hands, TerminalId } from './interaction/types';
import type { Pose } from './Player';

export class HandsController {
  private state: Hands = { kind: 'free' };
  private carried: THREE.Object3D | null = null;
  private readonly meter: THREE.Group;
  private readonly tmp = new THREE.Vector3();

  constructor(private readonly f: ModelFactory, private readonly rig: WorkerRig) {
    this.meter = new THREE.Group();
    const body = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.16, 0.045), f.mats.surface({ color: 0xffb82e, roughness: 0.5 }));
    const screen = new THREE.Mesh(new THREE.PlaneGeometry(0.07, 0.05), new THREE.MeshBasicMaterial({ color: 0x9fe8b0, toneMapped: false }));
    screen.position.set(0, 0.035, 0.024);
    this.meter.add(body, screen);
    this.meter.position.set(0, 0, 0.05);
    this.meter.rotation.x = -0.6;
    this.meter.visible = false;
    rig.handAnchor.add(this.meter);
  }

  get hands(): Hands { return this.state; }
  get kind(): Hands['kind'] { return this.state.kind; }
  get isFree(): boolean { return this.state.kind === 'free'; }

  pose(): Pose {
    switch (this.state.kind) {
      case 'carry': return 'carry';
      case 'cable': return 'cable';
      case 'meter': return 'tool';
      default: return 'idle';
    }
  }

  carry(item: CarriedItem): void {
    this.clear();
    this.state = { kind: 'carry', item };
    let obj: THREE.Object3D;
    if (item.kind === 'panel') {
      const p = this.f.createPanel();
      obj = p.root;
      obj.position.set(0, 0.02, 0);
    } else {
      obj = this.f.createCrate(item.kind);
      obj.scale.setScalar(0.55);
      obj.position.set(0, -0.06, 0);
    }
    this.rig.carryAnchor.add(obj);
    this.carried = obj;
  }

  takeCable(color: CableColor, from: TerminalId, fromPoint: THREE.Vector3): void {
    this.clear();
    this.state = { kind: 'cable', color, from, fromPoint: fromPoint.clone() };
  }

  setMeter(on: boolean): void {
    this.clear();
    if (on) this.state = { kind: 'meter' };
    this.meter.visible = on;
  }

  /** Suelta todo (sin dejar nada en el mundo). */
  clear(): void {
    if (this.carried) {
      this.carried.removeFromParent();
      this.carried.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh && m.material !== this.f.mats.crate) (m.material as THREE.Material).dispose(); });
      this.carried = null;
    }
    this.meter.visible = false;
    this.state = { kind: 'free' };
  }

  /** Posición de la mano en el mundo (para el cable en mano). */
  handWorld(out = this.tmp): THREE.Vector3 {
    this.rig.handAnchor.updateWorldMatrix(true, false);
    return this.rig.handAnchor.getWorldPosition(out);
  }
}
