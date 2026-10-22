/** RowPost: poste amarillo de cada fila (palanca de defensa contra el Zonda, limpieza y trabas). */
import * as THREE from 'three';
import type { ModelFactory } from '../assets';

export class RowPost {
  readonly root: THREE.Group;
  readonly approach: THREE.Vector3;
  private readonly model: { root: THREE.Group; setDefense(on: boolean): void };
  private defense = false;

  constructor(f: ModelFactory, readonly row: number, pos: THREE.Vector3) {
    this.model = f.createRowPost();
    this.root = this.model.root;
    this.root.position.copy(pos);
    this.root.rotation.y = Math.PI / 2;
    const label = f.createLabel('FILA ' + (row + 1), { scale: 0.5 });
    label.position.set(0, 1.62, 0);
    this.root.add(label);
    this.approach = new THREE.Vector3(pos.x + 0.95, 0, pos.z + 0.55);
  }

  get inDefense(): boolean { return this.defense; }

  setDefense(on: boolean): void {
    this.defense = on;
    this.model.setDefense(on);
  }
}
