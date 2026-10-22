/**
 * API de depuración para pruebas automáticas. Sólo se instala si window.ME_DEBUG === true antes de cargar.
 * window.__me: estado, acciones disponibles (etiqueta + posición), teletransporte, ejecutar acción,
 * velocidad del reloj y draw calls.
 */
import type { App } from './App';

export function installDebugApi(app: App): void {
  const ses = () => {
    const s = app.session;
    if (!s) throw new Error('No hay partida en curso');
    return s;
  };
  const find = (q: string) => {
    const list = ses().availableActions();
    const p = ses().player.position;
    const matches = list.filter((a) => a.id === q || a.label === q || a.label.startsWith(q));
    matches.sort((a, b) => Math.hypot(a.pos.x - p.x, a.pos.z - p.z) - Math.hypot(b.pos.x - p.x, b.pos.z - p.z));
    return matches[0] ?? null;
  };
  const api = {
    app,
    get session() { return app.session; },
    state() {
      const s = app.session;
      const top = app.ui.screens.top();
      const base = { screen: top ? top.constructor.name : null, screens: app.ui.screens.size, balance: app.services.wallet.balance() };
      if (!s) return { ...base, phase: null };
      return {
        ...base,
        level: s.level.id, phase: s.phase, weather: s.weather, hour: s.gameHour, paused: s.paused,
        hands: s.hands.kind, action: s.currentActionLabel, snap: s.snapshot(),
        panels: s.world.panelsInstalled(), batteries: s.world.batteriesInstalled(), kit: s.world.kitInstalled,
        rowsDirty: s.world.rows.map((_, r) => s.world.rowDirty(r)), rowsOpen: s.world.rows.map((_, r) => s.world.rowOpen(r)),
        defense: s.world.posts.map((p) => p.inDefense), lost: s.lostPanels, connector: { ...s.connector },
        player: { x: s.player.position.x, z: s.player.position.z }, drone: s.world.drone.active,
        cosmetics: s.cosmetics, shed: s.shedLoads,
      };
    },
    actions() {
      return ses().availableActions().map((a) => ({ id: a.id, label: a.label, x: +a.pos.x.toFixed(2), z: +a.pos.z.toFixed(2) }));
    },
    teleport(x: number, z: number) {
      const s = ses();
      s.player.teleport(x, z);
      s.camRig.snap();
      s.forceInteractionUpdate();
    },
    /** Lleva al jugador al punto de acceso de la acción (por id, etiqueta o prefijo) y devuelve la acción elegida. */
    goTo(q: string): string | null {
      const a = find(q);
      if (!a) return null;
      const s = ses();
      s.player.teleport(a.pos.x, a.pos.z);
      s.camRig.snap();
      s.forceInteractionUpdate();
      return s.currentActionLabel;
    },
    /** goTo + ejecutar la acción. */
    act(q: string): string | null {
      const l = api.goTo(q);
      if (!l) return null;
      ses().doAction();
      return l;
    },
    clock(mult: number) { ses().timeScale = mult; },
    /** Orienta la cámara (para capturas). */
    camera(yaw: number, pitch?: number, dist?: number) {
      const r = ses().camRig;
      r.yaw = yaw;
      if (pitch !== undefined) r.pitch = pitch;
      if (dist !== undefined) r.dist = dist;
      r.snap();
    },
    drawCalls() {
      const r = app.renderer.renderer;
      const scene = (app.session?.world.root.parent ?? null) as import('three').Scene | null;
      if (!scene) return null;
      app.renderer.render(scene);
      const total = app.renderer.stats.calls, tris = app.renderer.stats.triangles;
      r.info.reset();
      r.shadowMap.autoUpdate = false;
      r.render(scene, app.renderer.camera);
      const main = r.info.render.calls;
      r.shadowMap.autoUpdate = true;
      return { total, main, triangles: tris, geometries: r.info.memory.geometries, textures: r.info.memory.textures };
    },
  };
  (window as unknown as { __me: typeof api }).__me = api;
}
