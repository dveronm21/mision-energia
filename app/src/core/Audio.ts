import type { IAudio, ISaveStore, SfxName } from '../contracts';

type Wave = 'sine' | 'square' | 'sawtooth' | 'triangle';
type Tone = [freq: number, dur: number, type: Wave, vol: number, when?: number, slideTo?: number];

/** Recetas de efectos sintetizados (portadas del prototipo + 'coin' y 'click'). Datos puros. */
export const SFX_RECIPES: Record<SfxName, Tone[]> = {
  pick: [[520, 0.12, 'triangle', 0.12, 0, 780]],
  place: [[180, 0.18, 'square', 0.08, 0, 90], [660, 0.1, 'triangle', 0.08, 0.06]],
  ok: [[660, 0.12, 'triangle', 0.12], [990, 0.18, 'triangle', 0.12, 0.1]],
  bad: [[140, 0.3, 'sawtooth', 0.08]],
  beep: [[1400, 0.08, 'square', 0.06], [1400, 0.08, 'square', 0.06, 0.12]],
  power: [...[262, 330, 392, 523].map((f, i): Tone => [f, 0.5, 'triangle', 0.1, i * 0.12]), [80, 1.2, 'sine', 0.2, 0, 160]],
  alarm: [0, 1, 2].flatMap((i): Tone[] => [[700, 0.18, 'square', 0.07, i * 0.35], [520, 0.18, 'square', 0.07, i * 0.35 + 0.18]]),
  win: [523, 659, 784, 1046].map((f, i): Tone => [f, 0.35, 'triangle', 0.12, i * 0.15]),
  lose: [392, 330, 262, 196].map((f, i): Tone => [f, 0.4, 'sawtooth', 0.06, i * 0.2]),
  coin: [[988, 0.08, 'square', 0.07], [1319, 0.28, 'square', 0.07, 0.07]],
  click: [[1800, 0.03, 'triangle', 0.05]],
};

export type AudioContextFactory = () => AudioContext | null;

export const defaultAudioContextFactory: AudioContextFactory = () => {
  const g = globalThis as { AudioContext?: typeof AudioContext; webkitAudioContext?: typeof AudioContext };
  const Ctor = g.AudioContext || g.webkitAudioContext;
  if (!Ctor) return null;
  try { return new Ctor(); } catch { return null; }
};

const MUTE_KEY = 'audio.muted';

/** Audio con WebAudio sintetizado (sin archivos). Si no hay AudioContext, todos los métodos son no-op. */
export class SynthAudio implements IAudio {
  private ctx: AudioContext | null = null;
  private isMuted: boolean;
  private windWanted = false;
  private wind: { src: AudioBufferSourceNode; gain: GainNode } | null = null;

  constructor(
    private readonly factory: AudioContextFactory = defaultAudioContextFactory,
    private readonly store: ISaveStore | null = null,
  ) {
    this.isMuted = store ? store.load<boolean>(MUTE_KEY, false) : false;
  }

  unlock(): void {
    try {
      if (!this.ctx) this.ctx = this.factory();
      if (this.ctx && this.ctx.state === 'suspended') void this.ctx.resume();
      if (this.windWanted) this.startWind();
    } catch { this.ctx = null; }
  }

  play(name: SfxName): void {
    if (!this.ctx || this.isMuted) return;
    for (const t of SFX_RECIPES[name]) this.tone(...t);
  }

  setWind(on: boolean): void {
    this.windWanted = on;
    if (on) this.startWind(); else this.stopWind();
  }

  setMuted(muted: boolean): void {
    this.isMuted = muted;
    this.store?.save(MUTE_KEY, muted);
    if (muted) this.stopWind(); else if (this.windWanted) this.startWind();
  }

  muted(): boolean { return this.isMuted; }

  private tone(freq: number, dur: number, type: Wave, vol: number, when = 0, slideTo?: number): void {
    const ac = this.ctx!;
    try {
      const t = ac.currentTime + when;
      const o = ac.createOscillator();
      const g = ac.createGain();
      o.type = type;
      o.frequency.setValueAtTime(freq, t);
      if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g).connect(ac.destination);
      o.start(t);
      o.stop(t + dur + 0.05);
    } catch { /* nada */ }
  }

  /** Viento: ruido blanco en loop pasado por un pasabanda (como el Zonda del prototipo). */
  private startWind(): void {
    const ac = this.ctx;
    if (!ac || this.isMuted || this.wind) return;
    try {
      const len = ac.sampleRate * 2;
      const buf = ac.createBuffer(1, len, ac.sampleRate);
      const d = buf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
      const src = ac.createBufferSource();
      src.buffer = buf; src.loop = true;
      const f = ac.createBiquadFilter();
      f.type = 'bandpass'; f.frequency.value = 500; f.Q.value = 0.7;
      const gain = ac.createGain();
      gain.gain.value = 0.0001;
      gain.gain.exponentialRampToValueAtTime(0.12, ac.currentTime + 1.2);
      src.connect(f).connect(gain).connect(ac.destination);
      src.start();
      this.wind = { src, gain };
    } catch { this.wind = null; }
  }

  private stopWind(): void {
    const w = this.wind, ac = this.ctx;
    this.wind = null;
    if (!w || !ac) return;
    try {
      w.gain.gain.exponentialRampToValueAtTime(0.0001, ac.currentTime + 1);
      w.src.stop(ac.currentTime + 1.1);
    } catch { /* nada */ }
  }
}
