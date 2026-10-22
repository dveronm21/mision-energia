import type { IScoring, LevelDefinition, LevelResult } from '../contracts';

type ScoringInput = Parameters<IScoring['evaluate']>[1];

const MAX_TIPS = 3;

/**
 * Estrellas según LevelDefinition:
 *  ★ llegó al final · ★★ y batería final ≥ twoStarSoc · ★★★ y gasto ≤ threeStarSpend × presupuesto y sin paneles perdidos.
 * Puntaje: ganando 1000 + batería final (hasta 1000) + ahorro (hasta 500) − 50 por panel perdido;
 * perdiendo, 25 por hora de juego sobrevivida.
 * Tips: consejos didácticos, primero lo que más pesó en el resultado.
 */
export class Scoring implements IScoring {
  evaluate(level: LevelDefinition, input: ScoringInput): LevelResult {
    const soc = clamp01(input.finalSocPct);
    const stars = this.stars(level, input.won, soc, input.spent, input.panelsLost);
    const saved = level.budget > 0 ? clamp01((level.budget - input.spent) / level.budget) : 0;
    const survived = Math.max(0, (input.blackoutHour ?? level.endHour) - level.startHour);
    const score = input.won
      ? Math.max(0, Math.round(1000 + soc * 1000 + saved * 500 - input.panelsLost * 50))
      : Math.round(survived * 25);
    return {
      levelId: level.id, won: input.won, stars, score, finalSocPct: soc, spent: input.spent, budget: level.budget,
      panelsLost: input.panelsLost, blackoutHour: input.won ? null : input.blackoutHour, durationSec: input.durationSec,
      tips: this.tips(level, input, stars),
    };
  }

  stars(level: LevelDefinition, won: boolean, soc: number, spent: number, panelsLost: number): 0 | 1 | 2 | 3 {
    if (!won) return 0;
    if (soc + 1e-9 < level.twoStarSoc) return 1;
    if (spent > level.threeStarSpend * level.budget + 1e-9 || panelsLost > 0) return 2;
    return 3;
  }

  private tips(level: LevelDefinition, i: ScoringInput, stars: number): string[] {
    const t: string[] = [];
    const struggled = !i.won || stars < 2;
    if (i.hadOpenRowAtEnd) t.push('Una fila nunca generó: tenía un conector flojo. Medí con el multímetro en la caja de conexión y reparalo: en serie, un solo panel flojo apaga toda la fila.');
    if (i.hadDirtyRowAtEnd) t.push('Los paneles quedaron con polvo del Zonda y rindieron 35% menos. Cuando pase el viento, limpialos en el poste de cada fila.');
    if (i.panelsLost > 0) t.push(`El Zonda voló ${i.panelsLost === 1 ? 'un panel' : `${i.panelsLost} paneles`}. Cuando suene la alarma, poné cada fila en defensa (horizontal) o instalá las trabas anti-Zonda.`);
    if (struggled && i.batteries < level.batterySlots) t.push(`Con ${i.batteries === 1 ? 'una batería' : `${i.batteries} baterías`} guardás ${fmt(i.batteries * level.batteryKwh)} kWh y la noche pide más. En el taller, probá sumar otra batería.`);
    const maxPanels = level.rows * level.panelsPerRow;
    if (struggled && i.panels !== undefined && i.panels < Math.ceil(maxPanels * 0.75)) t.push('Con pocos paneles las baterías no llegan llenas a la noche. Instalá más paneles para generar el excedente que vas a guardar.');
    if (!i.won && i.nonEssentialOn) t.push('Quedaron encendidas cargas que no son esenciales. De noche, apagá lo que no haga falta para que la energía guardada alcance.');
    if (i.won && stars === 2 && i.spent > level.threeStarSpend * level.budget && i.panelsLost === 0) t.push('¡Muy bien! Para la tercera estrella, buscá la misma luz gastando menos créditos de obra.');
    if (t.length === 0) {
      t.push(i.won
        ? 'De día los paneles alimentaron el consumo y cargaron las baterías; de noche, el inversor usó esa energía guardada.'
        : 'Las baterías no llegaron llenas a la noche. Revisá cuántos paneles y baterías comprás y cuidá la planta durante el día.');
    }
    return t.slice(0, MAX_TIPS);
  }
}

function clamp01(x: number): number { return Math.max(0, Math.min(1, x)); }
function fmt(n: number): string { return (Math.round(n * 10) / 10).toString().replace('.', ','); }
