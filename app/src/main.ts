/**
 * Entrada de Misión Energía 0.3 (se abre por file:// dentro de un WebView Android, sin red).
 * Debug para pruebas automáticas: window.ME_DEBUG = true antes de cargar expone window.__me.
 */
import { App } from './app/App';
import { installDebugApi } from './app/DebugApi';

const BASE_CSS = `
#app{position:fixed;inset:0;overflow:hidden;background:#0E2420}
#app canvas{display:block;width:100%;height:100%;touch-action:none;outline:none}
`;

function boot(): void {
  const style = document.createElement('style');
  style.textContent = BASE_CSS;
  document.head.appendChild(style);
  const appEl = document.getElementById('app') as HTMLElement;
  const uiEl = document.getElementById('ui') as HTMLElement;
  const app = new App(appEl, uiEl);
  if ((window as unknown as { ME_DEBUG?: boolean }).ME_DEBUG === true) installDebugApi(app);
  app.start();
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();
