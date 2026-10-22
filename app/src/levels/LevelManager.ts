import type { ILevelManager, ISaveStore, IWallet, LevelId, LevelProgress, LevelResult } from '../contracts';
import type { LevelCatalog } from './LevelCatalog';

type ProgressMap = Partial<Record<LevelId, LevelProgress>>;
const KEY = 'levels.progress';

/**
 * Progreso de la campaña. Persiste en ISaveStore. El nivel de order 1 está siempre desbloqueado;
 * los demás se desbloquean al completar el requerido o pagando unlockCostSoles.
 * Soles: rewards[k] se acredita la PRIMERA vez que se alcanza la estrella k+1 (no se repiten al rejugar).
 */
export class LevelManager implements ILevelManager {
  private data: ProgressMap;

  constructor(
    private readonly catalog: LevelCatalog,
    private readonly store: ISaveStore,
    private readonly wallet: IWallet,
  ) {
    this.data = store.load<ProgressMap>(KEY, {});
  }

  progress(id: LevelId): LevelProgress {
    const p = this.data[id] ?? { unlocked: false, bestStars: 0, bestScore: 0, completed: false };
    return { ...p, unlocked: this.isUnlocked(id) };
  }

  isUnlocked(id: LevelId): boolean {
    const level = this.catalog.get(id);
    if (level.order === 1 || level.requires === null) return true;
    if (this.data[id]?.unlocked) return true;
    return !!this.data[level.requires]?.completed;
  }

  unlockWithSoles(id: LevelId): boolean {
    if (this.isUnlocked(id)) return true;
    const level = this.catalog.get(id);
    if (!this.wallet.spend(level.unlockCostSoles, `Desbloqueo: ${level.name}`)) return false;
    this.data[id] = { ...this.progress(id), unlocked: true };
    this.persist();
    return true;
  }

  recordResult(result: LevelResult): { solesEarned: number; newlyUnlocked: LevelId | null } {
    const level = this.catalog.get(result.levelId);
    const prev = this.progress(result.levelId);
    let solesEarned = 0;
    for (let s: number = prev.bestStars; s < result.stars; s++) solesEarned += level.rewards[s] ?? 0;
    const next = result.won ? this.catalog.next(level.id) : null;
    const wasNextUnlocked = next ? this.isUnlocked(next.id) : true;
    this.data[level.id] = {
      unlocked: true,
      bestStars: Math.max(prev.bestStars, result.stars) as LevelProgress['bestStars'],
      bestScore: Math.max(prev.bestScore, result.score),
      completed: prev.completed || result.won,
    };
    this.persist();
    if (solesEarned > 0) this.wallet.add(solesEarned, `Estrellas nuevas: ${level.name}`);
    const newlyUnlocked = next && !wasNextUnlocked ? next.id : null;
    return { solesEarned, newlyUnlocked };
  }

  /** Total de estrellas de la campaña (para la pantalla de mapa). */
  totalStars(): number {
    return this.catalog.all().reduce((acc, l) => acc + (this.data[l.id]?.bestStars ?? 0), 0);
  }

  private persist(): void { this.store.save(KEY, this.data); }
}
