import type { IParentalGate } from '../contracts';

/**
 * Control parental antes de pagar con dinero real: una multiplicación de un dígito por un dígito,
 * con ambos factores ≥ 6 (6..9), fácil para un adulto y con poca chance de acertar al azar para un chico chico.
 */
export class ParentalGate implements IParentalGate {
  constructor(private readonly rng: () => number = Math.random) {}

  challenge(): { question: string; answer: number } {
    const a = this.factor(), b = this.factor();
    return { question: `Para seguir, pedile a una persona adulta: ¿cuánto es ${a} × ${b}?`, answer: a * b };
  }

  /** Compara la respuesta escrita (tolera espacios). */
  check(ch: { answer: number }, input: string | number): boolean {
    const n = typeof input === 'number' ? input : Number(String(input).trim());
    return Number.isFinite(n) && n === ch.answer;
  }

  private factor(): number { return 6 + Math.min(3, Math.floor(this.rng() * 4)); }
}
