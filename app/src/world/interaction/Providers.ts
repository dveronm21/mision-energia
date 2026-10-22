/**
 * Estrategias de interacción: cada una aporta las acciones de un dominio según el estado de las manos.
 *  - PickupProvider     (manos libres): tomar panel del pallet, cajones y paneles sueltos.
 *  - PlacementProvider  (cargando):     colocar panel, instalar protección / batería / trabas.
 *  - WiringProvider     (libres/cable): tomar un cable de su equipo y conectarlo a otro.
 *  - MeterProvider      (multímetro):   medir filas, medir panel, reconectar conector.
 *  - FieldCareProvider  (manos libres): defensa ante el Zonda y limpieza en el poste de cada fila.
 *  - ConsoleProvider    (manos libres): activar la planta.
 */
import type { CarryKind, ActionProvider, Hands, TerminalId, WorldAction } from './types';
import type { SessionPort } from './SessionPort';

export const ITEM_NAME: Record<CarryKind, string> = { panel: 'panel', battery: 'batería', protection: 'protección', kit: 'kit anti-Zonda' };

export class PickupProvider implements ActionProvider {
  constructor(private readonly s: SessionPort) {}
  collect(h: Hands, out: WorldAction[]): void {
    if (h.kind !== 'free') return;
    const w = this.s.world;
    if (w.pallet.remaining > 0) out.push({ id: 'pallet', label: 'Tomar panel', pos: w.pallet.approach, run: () => this.s.takeFromPallet() });
    w.pickups.forEach((p, i) => out.push({ id: `pickup:${i}:${p.kind}`, label: `Tomar ${ITEM_NAME[p.kind]}`, pos: p.approach, run: () => this.s.takePickup(p) }));
  }
}

export class PlacementProvider implements ActionProvider {
  constructor(private readonly s: SessionPort) {}
  collect(h: Hands, out: WorldAction[]): void {
    if (h.kind !== 'carry') return;
    const w = this.s.world;
    switch (h.item.kind) {
      case 'panel':
        for (const m of w.mounts) if (!m.filled) out.push({ id: `mount:${m.row}:${m.index}`, label: 'Colocar panel', pos: m.approach, run: () => this.s.installPanel(m) });
        break;
      case 'protection':
        if (!w.protection.installed) out.push({ id: 'protection', label: 'Instalar protección', pos: w.protection.approach, run: () => this.s.installProtection() });
        break;
      case 'battery':
        for (const b of w.batteries) if (!b.installed) out.push({ id: `battery:${b.index}`, label: 'Instalar batería', pos: b.approach, run: () => this.s.installBattery(b.index) });
        break;
      case 'kit':
        for (const p of w.posts) out.push({ id: `post:${p.row}`, label: 'Instalar trabas', pos: p.approach, run: () => this.s.installKit(p.row) });
        break;
    }
  }
}

export class WiringProvider implements ActionProvider {
  constructor(private readonly s: SessionPort) {}
  collect(h: Hands, out: WorldAction[]): void {
    const w = this.s.world;
    if (h.kind === 'free') {
      if (this.s.phase !== 'build') return;
      const c = w.cables;
      if (!c.isConnected('orange')) out.push({ id: 'cable:orange', label: 'Tomar cable naranja', pos: w.junction.approach, run: () => this.s.takeCable('orange', 'junction', w.junction.terminal) });
      if (!c.isConnected('blue')) for (const b of w.batteries) if (b.installed) out.push({ id: `cable:blue:${b.index}`, label: 'Tomar cable azul', pos: b.approach, run: () => this.s.takeCable('blue', 'battery', b.terminal) });
      if (!c.isConnected('violet')) out.push({ id: 'cable:violet', label: 'Tomar cable violeta', pos: w.switchboard.approach, run: () => this.s.takeCable('violet', 'switchboard', w.switchboard.terminal) });
      return;
    }
    if (h.kind !== 'cable') return;
    const targets: { id: TerminalId; key: string; name: string; pos: import('three').Vector3 }[] = [
      { id: 'junction', key: 'junction', name: 'a la caja de conexión', pos: w.junction.approach },
      { id: 'inverter', key: 'inverter', name: 'al inversor', pos: w.inverter.approach },
      { id: 'switchboard', key: 'switchboard', name: 'al tablero', pos: w.switchboard.approach },
    ];
    if (w.protection.installed) targets.push({ id: 'protection', key: 'protection', name: 'a la protección', pos: w.protection.approach });
    for (const b of w.batteries) if (b.installed) targets.push({ id: 'battery', key: `battery:${b.index}`, name: 'a la batería', pos: b.approach });
    for (const t of targets) {
      if (t.id === h.from) continue;
      out.push({ id: `connect:${t.key}`, label: `Conectar ${t.name}`, pos: t.pos, run: () => this.s.connectCable(t.id) });
    }
  }
}

export class MeterProvider implements ActionProvider {
  constructor(private readonly s: SessionPort) {}
  collect(h: Hands, out: WorldAction[]): void {
    if (h.kind !== 'meter') return;
    const w = this.s.world;
    out.push({ id: 'measure:rows', label: 'Medir filas', pos: w.junction.approach, run: () => this.s.measureRows() });
    for (const m of w.mounts) {
      if (!m.filled) continue;
      if (m.faulty && m.faultFound) out.push({ id: `repair:${m.row}:${m.index}`, label: 'Reconectar conector', pos: m.approach, run: () => this.s.repairPanel(m) });
      else out.push({ id: `measure:${m.row}:${m.index}`, label: 'Medir panel', pos: m.approach, run: () => this.s.measurePanel(m) });
    }
  }
}

export class FieldCareProvider implements ActionProvider {
  constructor(private readonly s: SessionPort) {}
  collect(h: Hands, out: WorldAction[]): void {
    if (h.kind !== 'free') return;
    const w = this.s.world, ph = this.s.weather;
    const zondaNow = ph === 'zonda-warning' || ph === 'zonda-storm';
    for (const p of w.posts) {
      if (w.panelsInRow(p.row) === 0) continue;
      if (zondaNow && !p.inDefense && !w.kitInstalled) out.push({ id: `defense:${p.row}`, label: `Fila ${p.row + 1}: defensa`, pos: p.approach, run: () => this.s.setDefense(p.row) });
      if (ph !== 'zonda-storm' && w.rowDirty(p.row)) out.push({ id: `clean:${p.row}`, label: `Limpiar fila ${p.row + 1}`, pos: p.approach, run: () => this.s.cleanRow(p.row) });
    }
  }
}

export class ConsoleProvider implements ActionProvider {
  constructor(private readonly s: SessionPort) {}
  collect(h: Hands, out: WorldAction[]): void {
    if (h.kind !== 'free' || this.s.phase !== 'build') return;
    out.push({ id: 'activate', label: 'Activar planta', pos: this.s.world.console.approach, run: () => this.s.tryActivate() });
  }
}
