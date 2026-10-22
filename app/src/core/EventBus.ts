import type { GameEvent, IEventBus } from '../contracts';

type AnyHandler = (e: GameEvent) => void;

/** Bus de eventos tipado, sincrónico. Un error en un suscriptor no corta al resto. */
export class EventBus implements IEventBus {
  private readonly handlers = new Map<GameEvent['type'], Set<AnyHandler>>();

  constructor(private readonly onError: (err: unknown) => void = () => {}) {}

  on<T extends GameEvent['type']>(type: T, cb: (e: Extract<GameEvent, { type: T }>) => void): () => void {
    let set = this.handlers.get(type);
    if (!set) { set = new Set(); this.handlers.set(type, set); }
    const h = cb as unknown as AnyHandler;
    set.add(h);
    return () => { set!.delete(h); };
  }

  emit(e: GameEvent): void {
    const set = this.handlers.get(e.type);
    if (!set) return;
    for (const h of Array.from(set)) {
      try { h(e); } catch (err) { this.onError(err); }
    }
  }
}
