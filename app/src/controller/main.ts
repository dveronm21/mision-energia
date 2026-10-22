/** Entrada de la página de control (dist/controller/index.html), servida por el tele. */
import { CONTROLLER_CSS } from './styles';
import { ControllerApp } from './ControllerApp';
import { lockGestures } from './device';

function boot(): void {
  const style = document.createElement('style');
  style.textContent = CONTROLLER_CSS;
  document.head.appendChild(style);
  lockGestures();
  const host = document.getElementById('controller') ?? document.body;
  const app = new ControllerApp(host);
  (window as unknown as { __controller?: ControllerApp }).__controller = app;
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();
