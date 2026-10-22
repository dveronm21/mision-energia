/**
 * City: los edificios que abastece la planta, los postes y la línea aérea desde el tablero.
 * De noche, si la planta entrega energía, se iluminan las ventanas.
 */
import * as THREE from 'three';
import type { ModelFactory } from '../assets';
import type { LevelLayout } from '../LevelLayout';
import type { CableNetwork, CableRun } from './Cable';

export class City {
  readonly root = new THREE.Group();
  readonly line: CableRun;
  private readonly lights: ((i: number) => void)[] = [];
  private lit = -1;

  constructor(f: ModelFactory, layout: LevelLayout, lineFrom: THREE.Vector3, cables: CableNetwork) {
    this.root.name = 'city';
    const c = layout.city;
    const g = new THREE.Group();
    g.position.copy(c.origin);
    c.buildings.forEach(([x, z, w, h, d], i) => {
      const b = f.createBuilding(w, h, d, i + 1);
      b.root.position.set(x, 0, z);
      g.add(b.root);
      this.lights.push(b.setLights);
    });
    this.root.add(g);
    const anchors: THREE.Vector3[] = [lineFrom.clone()];
    c.poles.forEach((p, i) => {
      const pole = f.createPowerPole();
      pole.position.copy(p);
      pole.rotation.y = -0.5 + i * 0.05;
      this.root.add(pole);
      pole.updateMatrixWorld(true);
      const a = (pole.userData.wireAnchors as THREE.Vector3[])[1];
      anchors.push(pole.localToWorld(a.clone()));
    });
    anchors.push(c.origin.clone().add(new THREE.Vector3(-1.5, 3, 2)));
    this.line = cables.run(anchors, 0x2a2a2a, 0.03);
    const label = f.createLabel(c.name, { scale: 0.9 });
    label.position.copy(c.label);
    this.root.add(label);
  }

  /** factor 0..1: luz de las ventanas (noche × planta entregando). */
  setLit(factor: number): void {
    const v = Math.round(factor * 50) / 50;
    if (v === this.lit) return;
    this.lit = v;
    for (const l of this.lights) l(v);
  }
}
