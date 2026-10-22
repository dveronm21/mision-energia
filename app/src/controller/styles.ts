/**
 * CSS de la página de control (tablet en horizontal). Mismo lenguaje visual que el HUD del juego:
 * paleta #0E2420 · #1F3D37 · #FFB82E · #B9781A · #3FA34D · #F28C28, Fredoka + Nunito.
 */
export const CONTROLLER_CSS = String.raw`
@font-face{font-family:'Fredoka';font-weight:500;font-display:swap;src:url(fonts/fredoka-latin-500-normal.woff2) format('woff2')}
@font-face{font-family:'Fredoka';font-weight:600;font-display:swap;src:url(fonts/fredoka-latin-600-normal.woff2) format('woff2')}
@font-face{font-family:'Fredoka';font-weight:700;font-display:swap;src:url(fonts/fredoka-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:'Nunito';font-weight:700;font-display:swap;src:url(fonts/nunito-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:'Nunito';font-weight:800;font-display:swap;src:url(fonts/nunito-latin-800-normal.woff2) format('woff2')}
:root{
  --hud:#0E2420;--hud-2:#1F3D37;--line:#2F5A51;--fg:#fff;--muted:#B7CCC6;--sun:#FFB82E;--sun-dark:#B9781A;--leaf:#3FA34D;--warn:#F28C28;--ink:#10231F;--dust:#3A2A12;
  --pc:#FFB82E;
  --display:'Fredoka','Trebuchet MS',system-ui,sans-serif;--body:'Nunito',system-ui,-apple-system,'Segoe UI',sans-serif;
  --sl:env(safe-area-inset-left,0px);--sr:env(safe-area-inset-right,0px);--st:env(safe-area-inset-top,0px);--sb:env(safe-area-inset-bottom,0px);
  --m:clamp(12px,2.2vh,22px);
  --top:clamp(64px,11vh,92px);
  --act:clamp(190px,min(46vh,29vw),330px);
  --round:clamp(80px,15.5vh,124px);
  color-scheme:dark;
}
*,*::before,*::after{box-sizing:border-box}
html,body{height:100%;margin:0;overflow:hidden;overscroll-behavior:none}
body{background:var(--hud);color:var(--fg);font-family:var(--body);font-size:18px;line-height:1.3;touch-action:none;-webkit-user-select:none;user-select:none;-webkit-tap-highlight-color:transparent;-webkit-text-size-adjust:100%;-webkit-touch-callout:none}
button{font-family:var(--body);color:inherit;cursor:pointer;-webkit-tap-highlight-color:transparent;touch-action:none}
button:focus{outline:none}
button:focus-visible{outline:3px solid var(--sun);outline-offset:3px}
input{-webkit-user-select:text;user-select:text;touch-action:auto;font-family:var(--body)}
h1,h2,p{margin:0}
[hidden]{display:none!important}
.ic{flex:none;display:block}

.c-app{position:fixed;inset:0;overflow:hidden;
  background:radial-gradient(80% 70% at 85% 100%,rgba(255,184,46,.10) 0,rgba(255,184,46,0) 60%),radial-gradient(70% 80% at 10% 90%,rgba(63,163,77,.10) 0,rgba(63,163,77,0) 60%),var(--hud)}
.c-edge{position:absolute;inset:0;pointer-events:none;box-shadow:inset 0 0 0 4px var(--pc);opacity:.9;z-index:1}
.c-edge::after{content:'';position:absolute;inset:0;box-shadow:inset 0 0 70px var(--pc);opacity:.22}

/* ---------- Barra superior ---------- */
.c-top{position:absolute;left:0;right:0;top:0;height:calc(var(--top) + var(--st));padding:calc(var(--st) + 8px) calc(var(--m) + var(--sr)) 8px calc(var(--m) + var(--sl));display:flex;align-items:center;gap:clamp(10px,1.6vw,20px);background:rgba(8,24,21,.75);border-bottom:2px solid rgba(255,255,255,.08);z-index:2}
.c-me{flex:none;display:flex;align-items:center;gap:10px;min-width:0;max-width:26vw;padding:6px 16px 6px 6px;border-radius:999px;background:var(--hud-2);border:3px solid var(--pc)}
.c-ava{flex:none;width:clamp(40px,7vh,56px);height:clamp(40px,7vh,56px);border-radius:50%;background:var(--pc);color:var(--ink);display:flex;align-items:center;justify-content:center;font-family:var(--display);font-weight:700;font-size:clamp(22px,4vh,32px);box-shadow:inset 0 -4px 0 rgba(0,0,0,.18)}
.c-me-txt{min-width:0;display:flex;flex-direction:column;line-height:1.1}
.c-me-name{font-family:var(--display);font-weight:600;font-size:clamp(18px,3.2vh,26px);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.c-me-sub{font-size:clamp(12px,1.9vh,15px);font-weight:800;color:var(--muted);white-space:nowrap}
.c-goal{flex:1;min-width:0;display:flex;flex-direction:column;justify-content:center;gap:2px}
.c-goal-eyebrow{font-size:clamp(11px,1.7vh,14px);font-weight:800;letter-spacing:.14em;text-transform:uppercase;color:var(--sun)}
.c-goal-text{font-family:var(--display);font-weight:600;font-size:clamp(17px,3vh,26px);line-height:1.1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.c-goal-status{font-size:clamp(12px,1.9vh,15px);font-weight:800;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.c-conn{flex:none;display:flex;align-items:center;gap:8px;padding:8px 14px;border-radius:999px;background:rgba(0,0,0,.3);font-weight:800;font-size:clamp(13px,2vh,16px);font-variant-numeric:tabular-nums;color:#DFF3E3}
.c-conn .ic{width:22px;height:22px}
.c-conn[data-q=good]{color:#9EE6A8}.c-conn[data-q=ok]{color:#FFD27A}.c-conn[data-q=bad],.c-conn[data-q=off]{color:#FFB4A8}
.c-pause{flex:none;width:clamp(56px,9vh,76px);height:clamp(56px,9vh,76px);border-radius:50%;border:3px solid rgba(255,255,255,.75);background:var(--hud-2);display:flex;align-items:center;justify-content:center;padding:0;box-shadow:0 4px 0 #0A1A17}
.c-pause.is-down{transform:translateY(3px);box-shadow:0 1px 0 #0A1A17}

/* ---------- Zona del joystick ---------- */
.c-pad{position:absolute;left:0;right:0;bottom:0;top:calc(var(--top) + var(--st))}
.c-zone{position:absolute;left:0;top:0;bottom:0;width:54%;touch-action:none}
.c-zone-hint{position:absolute;left:50%;top:52%;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;gap:14px;pointer-events:none;color:rgba(255,255,255,.55);text-align:center;transition:opacity .15s}
.c-ghost{width:clamp(130px,28vh,220px);height:clamp(130px,28vh,220px);border-radius:50%;border:3px dashed rgba(255,255,255,.28);display:flex;align-items:center;justify-content:center}
.c-ghost::after{content:'';width:42%;height:42%;border-radius:50%;background:rgba(255,255,255,.16)}
.c-zone-hint b{font-family:var(--display);font-weight:600;font-size:clamp(17px,2.8vh,22px);color:rgba(255,255,255,.75)}
.c-zone-hint span{font-size:clamp(13px,2vh,16px);font-weight:800}
.c-zone.is-active .c-zone-hint{opacity:0}
.c-base{position:absolute;left:0;top:0;width:calc(var(--r,100px) * 2);height:calc(var(--r,100px) * 2);margin:calc(var(--r,100px) * -1) 0 0 calc(var(--r,100px) * -1);pointer-events:none;opacity:0;transition:opacity .1s}
.c-zone.is-active .c-base{opacity:1}
.c-ring{position:absolute;inset:0;border-radius:50%;background:rgba(14,36,32,.6);border:4px solid rgba(255,255,255,.7);box-shadow:0 0 0 10px rgba(255,255,255,.06)}
.c-zone.is-run .c-ring{border-color:var(--sun);box-shadow:0 0 0 10px rgba(255,184,46,.22),0 0 40px rgba(255,184,46,.45)}
.c-knob{position:absolute;left:50%;top:50%;width:46%;height:46%;margin:-23% 0 0 -23%;border-radius:50%;background:#fff;box-shadow:0 6px 0 rgba(0,0,0,.28),inset 0 -6px 0 rgba(0,0,0,.08)}
.c-zone.is-run .c-knob{background:#FFE2A1}
.c-run{position:absolute;left:50%;bottom:calc(100% + 14px);transform:translateX(-50%);display:flex;align-items:center;gap:6px;padding:6px 12px;border-radius:999px;background:var(--sun);color:var(--ink);font-weight:800;font-size:15px;white-space:nowrap;opacity:0;transition:opacity .1s}
.c-zone.is-run .c-run{opacity:1}

/* ---------- Botonera derecha ---------- */
.c-btns{position:absolute;right:calc(var(--m) + var(--sr) + 6px);bottom:calc(var(--m) + var(--sb) + 10px);display:flex;align-items:flex-end;gap:clamp(14px,2.4vw,28px)}
.c-col{display:flex;flex-direction:column;gap:clamp(12px,2.6vh,24px);padding-bottom:4px}
.c-round{position:relative;border:none;background:transparent;padding:0;display:flex;flex-direction:column;align-items:center;gap:6px}
.c-round .c-circle{width:var(--round);height:var(--round);border-radius:50%;border:4px solid rgba(255,255,255,.75);background:var(--hud-2);display:flex;align-items:center;justify-content:center;box-shadow:0 6px 0 #0A1A17;transition:transform .06s,box-shadow .06s}
.c-round .c-circle .ic{width:46%;height:46%}
.c-cap{font-size:clamp(13px,2.1vh,17px);font-weight:800;line-height:1;padding:5px 11px;border-radius:999px;background:rgba(8,24,21,.85);white-space:nowrap}
.c-round.is-down .c-circle{transform:translateY(5px);box-shadow:0 1px 0 #0A1A17}
.c-round.is-on .c-circle{background:var(--dust);border-color:var(--sun);color:#FFD27A;box-shadow:0 6px 0 #0A1A17,0 0 24px rgba(255,184,46,.45)}
.c-round.is-on .c-cap{color:#FFD27A}
.c-onoff{position:absolute;top:-4px;right:-6px;min-width:44px;padding:3px 8px;border-radius:999px;background:#4E625D;color:#fff;font-weight:800;font-size:13px;line-height:1.1;text-align:center;border:2px solid var(--hud)}
.c-round.is-on .c-onoff{background:var(--leaf)}
.c-round:disabled{cursor:default}
.c-round:disabled .c-circle{opacity:.4;box-shadow:none}
.c-round:disabled .c-cap{opacity:.55}

.c-act{position:relative;width:var(--act);height:var(--act);border-radius:50%;border:8px solid #FFE2A1;background:radial-gradient(circle at 50% 35%,#FFC94F 0,var(--sun) 60%);color:var(--ink);font-family:var(--display);font-weight:700;font-size:calc(var(--act) * .125);line-height:1.05;padding:0 calc(var(--act) * .12);box-shadow:0 12px 0 var(--sun-dark),0 18px 30px rgba(0,0,0,.35);text-wrap:balance;display:flex;align-items:center;justify-content:center;text-align:center;transition:transform .06s,box-shadow .06s}
.c-act[data-len=m]{font-size:calc(var(--act) * .105)}
.c-act[data-len=l]{font-size:calc(var(--act) * .088)}
.c-act.is-down{transform:translateY(9px);box-shadow:0 3px 0 var(--sun-dark),0 6px 14px rgba(0,0,0,.35)}
.c-act.is-idle{background:#4E625D;border-color:#8FA7A1;color:#F1F5F3;box-shadow:0 12px 0 #2C3B36,0 18px 30px rgba(0,0,0,.3)}
.c-act.is-idle.is-down{box-shadow:0 3px 0 #2C3B36}
.c-act.is-drop{background:#EEF2F1;border-color:#fff;color:var(--ink);box-shadow:0 12px 0 #8FA7A1,0 18px 30px rgba(0,0,0,.3)}
.c-act.is-drop.is-down{box-shadow:0 3px 0 #8FA7A1}
.c-act:disabled{opacity:.55;cursor:default}
.c-act::after{content:'';position:absolute;inset:-8px;border-radius:50%;border:6px solid var(--pc);opacity:0;pointer-events:none}
.c-act.is-pulse::after{animation:actPulse .45s ease-out}
@keyframes actPulse{from{opacity:.9;transform:scale(.96)}to{opacity:0;transform:scale(1.18)}}

/* ---------- Toast ---------- */
.c-toast{position:absolute;left:50%;top:calc(var(--top) + var(--st) + 14px);transform:translateX(-50%);max-width:min(560px,70vw);padding:12px 22px;border-radius:16px;background:#fff;color:var(--ink);font-weight:800;font-size:clamp(16px,2.6vh,20px);text-align:center;box-shadow:0 6px 0 rgba(0,0,0,.25);z-index:4;pointer-events:none;animation:toastIn .2s ease-out}
.c-toast.is-good{background:#DFF3E3}.c-toast.is-bad{background:#FFE7CF}
@keyframes toastIn{from{opacity:0;transform:translate(-50%,-10px)}}

/* ---------- Pantallas de estado ---------- */
.c-over{position:absolute;inset:0;z-index:5;display:flex;align-items:center;justify-content:center;padding:calc(var(--m) + var(--st)) calc(var(--m) + var(--sr)) calc(var(--m) + var(--sb)) calc(var(--m) + var(--sl));background:rgba(8,22,19,.86);backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px)}
.c-card{width:min(640px,100%);max-height:100%;display:flex;flex-direction:column;align-items:center;gap:clamp(12px,2.4vh,20px);text-align:center;padding:clamp(20px,4.5vh,40px) clamp(20px,4vw,44px);border-radius:28px;background:var(--hud-2);border:3px solid var(--line);box-shadow:0 10px 0 rgba(0,0,0,.35)}
.c-card.is-wide{width:min(860px,100%);flex-direction:row;text-align:left;align-items:center;gap:clamp(18px,3.6vw,40px)}
.c-card-col{display:flex;flex-direction:column;gap:clamp(10px,2vh,16px);align-items:flex-start;min-width:0;flex:1}
.c-badge{width:clamp(72px,14vh,108px);height:clamp(72px,14vh,108px);border-radius:50%;background:rgba(0,0,0,.25);display:flex;align-items:center;justify-content:center;color:var(--sun);flex:none}
.c-badge .ic{width:52%;height:52%}
.c-badge.is-bad{color:#FFB4A8}
.c-badge.is-me{background:var(--pc);color:var(--ink);font-family:var(--display);font-weight:700;font-size:clamp(44px,9vh,72px);width:clamp(110px,22vh,170px);height:clamp(110px,22vh,170px);box-shadow:inset 0 -8px 0 rgba(0,0,0,.18),0 0 0 8px rgba(255,255,255,.12)}
.c-eyebrow{font-size:clamp(12px,1.9vh,15px);font-weight:800;letter-spacing:.14em;text-transform:uppercase;color:var(--sun)}
.c-h{font-family:var(--display);font-weight:700;font-size:clamp(28px,5.4vh,44px);line-height:1.05}
.c-p{font-size:clamp(16px,2.7vh,21px);font-weight:700;color:var(--muted);line-height:1.35;text-wrap:balance}
.c-row{display:flex;gap:14px;flex-wrap:wrap;justify-content:center}
.c-btn{display:inline-flex;align-items:center;justify-content:center;gap:10px;min-height:64px;padding:0 32px;border-radius:999px;border:none;font-family:var(--display);font-weight:700;font-size:clamp(20px,3.2vh,26px);touch-action:manipulation}
.c-btn-primary{background:var(--sun);color:var(--ink);box-shadow:0 6px 0 var(--sun-dark)}
.c-btn-primary:active:not(:disabled){transform:translateY(4px);box-shadow:0 2px 0 var(--sun-dark)}
.c-btn-primary:disabled{background:#3B5751;color:#9DB3AD;box-shadow:0 6px 0 #24403A}
.c-btn-secondary{background:transparent;color:#fff;border:3px solid rgba(255,255,255,.5);min-height:58px;font-size:clamp(17px,2.7vh,21px)}
.c-btn-big{min-height:clamp(72px,12vh,96px);padding:0 44px;font-size:clamp(24px,4vh,32px)}
.c-name{width:100%;display:flex;gap:12px}
.c-name input{flex:1;min-width:0;height:72px;border-radius:18px;border:3px solid var(--line);background:#fff;color:var(--ink);font-family:var(--display);font-weight:600;font-size:32px;padding:0 20px;text-align:center}
.c-name input:focus{outline:none;border-color:var(--sun);box-shadow:0 0 0 4px rgba(255,184,46,.35)}
.c-small{font-size:clamp(13px,2vh,16px);font-weight:800;color:var(--muted)}
.c-spin{width:clamp(56px,10vh,80px);height:clamp(56px,10vh,80px);border-radius:50%;border:8px solid rgba(255,255,255,.12);border-top-color:var(--sun);animation:spin .9s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.c-dots::after{content:'';display:inline-block;width:1.1em;text-align:left;animation:dots 1.6s steps(4,end) infinite}
@keyframes dots{0%{content:''}25%{content:'.'}50%{content:'..'}75%,100%{content:'...'}}
.c-tv{display:inline-flex;align-items:center;gap:8px;padding:6px 14px;border-radius:999px;background:rgba(0,0,0,.25);font-weight:800;font-size:clamp(14px,2.2vh,17px);color:#DFF3E3}

/* ---------- Girá la tablet ---------- */
.c-rotate{position:absolute;inset:0;z-index:9;display:none;flex-direction:column;align-items:center;justify-content:center;gap:22px;padding:32px;text-align:center;background:var(--hud)}
.c-rotate .ic{width:120px;height:120px;color:var(--sun);animation:rot 2.2s ease-in-out infinite}
@keyframes rot{0%,30%{transform:rotate(0)}60%,100%{transform:rotate(-90deg)}}
@media (orientation:portrait){.c-rotate{display:flex}}

@media (max-height:520px){.c-top{height:calc(60px + var(--st))}.c-pad{top:calc(60px + var(--st))}.c-goal-status{display:none}}
@media (prefers-reduced-motion:reduce){.c-spin,.c-rotate .ic{animation:none}.c-act.is-pulse::after{animation:none}}
`;
