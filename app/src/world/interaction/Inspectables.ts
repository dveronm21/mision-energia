/** Fichas educativas de "Revisar" con datos en vivo de la planta. */
import type { LevelDefinition, SimSnapshot } from '../../contracts';
import { fmt1 } from '../../ui/format';
import type { PlantWorld } from '../PlantWorld';
import type { InspectEntry, InspectProvider } from './types';

export interface LiveSource {
  readonly level: LevelDefinition;
  readonly world: PlantWorld;
  isRunning(): boolean;
  snapshot(): SimSnapshot | null;
}

export const PANEL_VOC = 41;

export class Inspectables implements InspectProvider {
  constructor(private readonly s: LiveSource) {}

  inspectables(out: InspectEntry[]): void {
    const { world: w, level: lv } = this.s;
    const snap = () => (this.s.isRunning() ? this.s.snapshot() : null);
    const kw = fmt1;
    for (const m of w.mounts) {
      out.push({
        id: `mount:${m.row}:${m.index}`, pos: m.approach,
        title: m.filled ? `Panel solar · fila ${m.row + 1}` : 'Estructura vacía',
        body: m.filled
          ? `Convierte la luz del sol en corriente continua. Cada panel aporta hasta ${kw(lv.panelKw)} kW y unos ${PANEL_VOC} V; los paneles de una fila van en serie, así que un conector flojo apaga toda la fila.`
          : 'Acá va un panel solar. La estructura está inclinada para aprovechar mejor el sol de la mañana a la tarde.',
        live: () => (!m.filled ? null : m.isDirty ? 'Con polvo: rinde 35% menos' : null),
      });
    }
    out.push({ id: 'pallet', pos: w.pallet.approach, title: 'Pallet de paneles', body: 'Los paneles que compraste en el taller. Llevalos de a uno hasta las estructuras del campo solar.', live: () => `Quedan ${w.pallet.remaining}` });
    w.pickups.forEach((p, i) => {
      const t = p.kind === 'battery' ? ['Batería embalada', `Batería de litio de ${kw(lv.batteryKwh)} kWh útiles. Va en una de las bases de la sala de equipos.`]
        : p.kind === 'protection' ? ['Protección embalada', 'Fusible y seccionador de corriente continua. Va en la pared, a la izquierda del inversor.']
          : p.kind === 'kit' ? ['Kit anti-Zonda', 'Trabas para las estructuras. Instalalo en el poste amarillo de cualquier fila del campo solar.']
            : ['Panel solar suelto', 'Llevalo a una estructura vacía del campo solar.'];
      out.push({ id: `pickup:${i}`, pos: p.approach, title: t[0], body: t[1] });
    });
    out.push({
      id: 'junction', pos: w.junction.approach, title: 'Caja de conexión del campo',
      body: 'Junta la energía de todas las filas en un circuito de corriente continua. Con el multímetro podés medir la tensión de cada fila.',
      live: () => { const s = snap(); return s ? `Llegan ${kw(s.genKw)} kW del campo solar` : `${w.panelsInstalled()} paneles conectados`; },
    });
    for (const p of w.posts) {
      out.push({
        id: `post:${p.row}`, pos: p.approach, title: `Poste de la fila ${p.row + 1}`,
        body: 'Desde acá se baja la fila a posición horizontal cuando sopla el Zonda y se limpian los paneles cuando pasa el viento.',
        live: () => (w.kitInstalled ? 'Trabas anti-Zonda instaladas' : p.inDefense ? 'En posición de defensa' : w.rowDirty(p.row) ? 'Paneles con polvo' : null),
      });
    }
    out.push({
      id: 'protection', pos: w.protection.approach, title: w.protection.installed ? 'Protección de CC' : 'Lugar de la protección',
      body: 'Fusible y seccionador: si hay un cortocircuito abren el circuito y protegen al inversor. En una instalación real la hace un electricista matriculado.',
    });
    out.push({
      id: 'inverter', pos: w.inverter.approach, title: 'Inversor híbrido',
      body: 'Convierte la corriente continua de paneles y baterías en corriente alterna para la ciudad, y decide cuándo cargar o descargar las baterías.',
      live: () => { const s = snap(); if (!s) return 'En espera'; return s.netKw > 0.05 ? `Cargando baterías con ${kw(s.netKw)} kW` : s.netKw < -0.05 ? `Usando baterías: ${kw(-s.netKw)} kW` : 'En equilibrio'; },
    });
    for (const b of w.batteries) {
      out.push({
        id: `battery:${b.index}`, pos: b.approach, title: b.installed ? 'Batería de litio' : 'Base para batería',
        body: b.installed ? `Guarda la energía que sobra de día para usarla de noche. Capacidad útil: ${kw(lv.batteryKwh)} kWh.` : 'Lugar marcado para una batería.',
        live: () => { const s = snap(); return b.installed && s ? `Carga del banco: ${Math.round(s.socPct * 100)}%` : null; },
      });
    }
    out.push({
      id: 'switchboard', pos: w.switchboard.approach, title: 'Tablero eléctrico',
      body: 'Recibe la corriente alterna del inversor y la reparte hacia la ciudad, con térmicas y disyuntor para cada circuito.',
      live: () => { const s = snap(); return s ? `La ciudad consume ${kw(s.loadKw)} kW` : null; },
    });
    out.push({
      id: 'console', pos: w.console.approach, title: 'Consola de control',
      body: `Cuando todo esté instalado y conectado, activá la planta acá. Necesitás al menos ${lv.minPanels} paneles, la protección, las baterías y los tres cables.`,
    });
    if (w.pump) {
      out.push({
        id: 'pump', pos: w.pump.approach, title: 'Bomba de riego solar',
        body: 'Saca agua del pozo para regar las vides. Consume mucho al mediodía, justo cuando los paneles generan más.',
        live: () => { const s = snap(); return s ? (s.hour % 24 >= 11 && s.hour % 24 < 16 ? 'Regando' : 'Detenida') : null; },
      });
    }
  }
}
