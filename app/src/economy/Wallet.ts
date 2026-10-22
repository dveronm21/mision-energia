import type { IEventBus, ISaveStore, IWallet } from '../contracts';

interface WalletData { balance: number; history: { at: number; delta: number; reason: string }[]; }
const KEY = 'wallet';
const HISTORY_MAX = 100;

/** Billetera de Soles persistente con historial (últimos 100 movimientos). Montos enteros positivos. */
export class Wallet implements IWallet {
  private data: WalletData;
  private readonly listeners = new Set<(balance: number) => void>();

  constructor(
    private readonly store: ISaveStore,
    private readonly bus: IEventBus | null = null,
    private readonly now: () => number = () => Date.now(),
  ) {
    const d = store.load<WalletData>(KEY, { balance: 0, history: [] });
    this.data = { balance: Math.max(0, Math.floor(d.balance || 0)), history: Array.isArray(d.history) ? d.history : [] };
  }

  balance(): number { return this.data.balance; }

  add(amount: number, reason: string): void {
    const a = Math.floor(amount);
    if (!(a > 0)) return;
    this.apply(a, reason);
  }

  spend(amount: number, reason: string): boolean {
    const a = Math.ceil(amount);
    if (!(a >= 0) || a > this.data.balance) return false;
    if (a > 0) this.apply(-a, reason);
    return true;
  }

  history(): { at: number; delta: number; reason: string }[] { return this.data.history.map((h) => ({ ...h })); }

  onChange(cb: (balance: number) => void): () => void {
    this.listeners.add(cb);
    return () => { this.listeners.delete(cb); };
  }

  private apply(delta: number, reason: string): void {
    this.data.balance += delta;
    this.data.history.push({ at: this.now(), delta, reason });
    if (this.data.history.length > HISTORY_MAX) this.data.history.splice(0, this.data.history.length - HISTORY_MAX);
    this.store.save(KEY, this.data);
    const b = this.data.balance;
    this.listeners.forEach((cb) => cb(b));
    this.bus?.emit({ type: 'wallet-changed', balance: b });
  }
}
