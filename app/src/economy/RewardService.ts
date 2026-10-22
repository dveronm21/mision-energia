import type { ISaveStore, IWallet } from '../contracts';

interface RewardData { welcomeClaimed: boolean; lastDaily: string | null; }
const KEY = 'rewards';

export const WELCOME_SOLES = 50;
export const DAILY_SOLES = 20;

/** Regalos gratuitos: bienvenida (una vez) y bono diario (una vez por día calendario local). */
export class RewardService {
  private data: RewardData;

  constructor(
    private readonly wallet: IWallet,
    private readonly store: ISaveStore,
    private readonly clock: () => Date = () => new Date(),
  ) {
    this.data = store.load<RewardData>(KEY, { welcomeClaimed: false, lastDaily: null });
  }

  canClaimWelcome(): boolean { return !this.data.welcomeClaimed; }

  /** Devuelve los Soles acreditados (0 si ya se reclamó). */
  claimWelcome(): number {
    if (this.data.welcomeClaimed) return 0;
    this.data.welcomeClaimed = true;
    this.persist();
    this.wallet.add(WELCOME_SOLES, 'Regalo de bienvenida');
    return WELCOME_SOLES;
  }

  canClaimDaily(): boolean { return this.data.lastDaily !== this.today(); }

  claimDaily(): number {
    if (!this.canClaimDaily()) return 0;
    this.data.lastDaily = this.today();
    this.persist();
    this.wallet.add(DAILY_SOLES, 'Bono diario');
    return DAILY_SOLES;
  }

  private today(): string {
    const d = this.clock();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }

  private persist(): void { this.store.save(KEY, this.data); }
}
