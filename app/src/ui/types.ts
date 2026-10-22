/** Tipos propios de la capa de UI (complementan src/contracts.ts). */

/** Una pantalla administrada por ScreenManager. */
export interface UiScreen {
  readonly root: HTMLElement;
  /** true = se superpone y deja ver la pantalla de abajo (modal, pausa). */
  readonly modal?: boolean;
  /** Pasa a ser la pantalla de arriba de la pila. */
  onEnter?(): void;
  /** Deja de ser la de arriba (porque se apiló otra o se quitó). */
  onLeave?(): void;
  /** Botón "atrás" del sistema. true = lo manejó. */
  onBack?(): boolean;
  /** Se quitó de la pila definitivamente. */
  dispose?(): void;
}

/** Bono diario reclamable desde el menú principal. */
export interface IDailyBonus {
  available(): boolean;
  amount(): number;
  /** Acredita y devuelve lo acreditado (0 si no estaba disponible). */
  claim(): number;
}

export type ObjectiveState = 'todo' | 'now' | 'ok' | 'alert';
export interface MissionObjective { id?: string; text: string; state: ObjectiveState; }

export type ActionState = 'normal' | 'idle' | 'drop';

export interface BoosterSlot { id: string; label: string; icon: string; count: number; }

export interface InspectInfo { title: string; body: string; live?: string | null; }

export type MeterState = 'idle' | 'ok' | 'bad';

export type ToastKind = 'good' | 'bad' | 'info';
