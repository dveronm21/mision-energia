/**
 * CSS de toda la UI como string (UiRoot lo inyecta una vez).
 * Paleta del prototipo: #0E2420 · #1F3D37 · #FFB82E · #B9781A · #3FA34D · #F28C28 · blanco.
 * Fuentes locales en public/fonts (url relativa a index.html).
 */
export const UI_CSS = String.raw`
@font-face{font-family:'Fredoka';font-weight:500;font-display:swap;src:url(fonts/fredoka-latin-500-normal.woff2) format('woff2')}
@font-face{font-family:'Fredoka';font-weight:600;font-display:swap;src:url(fonts/fredoka-latin-600-normal.woff2) format('woff2')}
@font-face{font-family:'Fredoka';font-weight:700;font-display:swap;src:url(fonts/fredoka-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:'Nunito';font-weight:600;font-display:swap;src:url(fonts/nunito-latin-600-normal.woff2) format('woff2')}
@font-face{font-family:'Nunito';font-weight:700;font-display:swap;src:url(fonts/nunito-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:'Nunito';font-weight:800;font-display:swap;src:url(fonts/nunito-latin-800-normal.woff2) format('woff2')}
@font-face{font-family:'Share Tech Mono';font-weight:400;font-display:swap;src:url(fonts/share-tech-mono-latin-400-normal.woff2) format('woff2')}

:root{
  --hud:#0E2420; --hud-2:#1F3D37; --hud-line:#2F5A51;
  --fg:#FFFFFF; --muted:#B7CCC6; --sun:#FFB82E; --sun-dark:#B9781A; --sun-ink:#7A4E0E;
  --leaf:#3FA34D; --leaf-dark:#2E7D3A; --ink:#10231F; --ink-2:#2A4741; --ink-3:#4A635D;
  --warn:#F28C28; --danger:#B3261E; --dust:#3A2A12; --paper:#FFFFFF; --paper-2:#F1F5F3; --line:#D5DCDA;
  --display:'Fredoka','Trebuchet MS',system-ui,sans-serif;
  --body:'Nunito',system-ui,-apple-system,'Segoe UI',sans-serif;
  --mono:'Share Tech Mono',ui-monospace,'Consolas',monospace;
  --sl:env(safe-area-inset-left,0px); --sr:env(safe-area-inset-right,0px);
  --st:env(safe-area-inset-top,0px); --sb:env(safe-area-inset-bottom,0px);
  /* Métricas del HUD (se achican en pantallas bajas) */
  --m:12px; --mis-w:300px; --st-w:220px; --pause:52px; --joy:132px; --act:128px; --round:76px; --gap:12px; --bst:56px;
  --lane-top:220px;
  color-scheme:dark;
}
html,body{height:100%;margin:0;overflow:hidden}
body{background:var(--hud);color:var(--fg);font-family:var(--body);touch-action:none;-webkit-user-select:none;user-select:none;-webkit-tap-highlight-color:transparent;-webkit-text-size-adjust:100%}

.ui-root{position:fixed;inset:0;z-index:10;pointer-events:none;font-family:var(--body);color:var(--fg);font-size:16px;line-height:1.35}
.ui-root *,.ui-root *::before,.ui-root *::after{box-sizing:border-box}
.ui-layer{position:absolute;inset:0;pointer-events:none}
.ui-layer[hidden]{display:none}
.ui-hud{z-index:1}.ui-screens{z-index:2}.ui-top{z-index:3}
.ui-root button{font-family:var(--body);cursor:pointer;-webkit-tap-highlight-color:transparent;touch-action:manipulation;color:inherit}
.ui-root button:disabled{cursor:not-allowed}
.ui-root :focus{outline:none}
.ui-root :focus-visible{outline:3px solid var(--sun);outline-offset:3px}
.ui-root input{-webkit-user-select:text;user-select:text;touch-action:auto;font-family:var(--body)}
.ui-root h1,.ui-root h2,.ui-root h3,.ui-root p{margin:0}
.ui-root [hidden]{display:none!important}
.ic{flex:none;display:block}
.sr-only,.wc-sr,.ls-state{position:absolute!important;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
.eyebrow{font-size:13px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;color:var(--sun)}

/* ---------- Botones genéricos ---------- */
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:48px;padding:0 20px;border-radius:999px;border:none;font-family:var(--display)!important;font-weight:600;font-size:18px;line-height:1.1;text-align:center;transition:transform .08s,box-shadow .08s}
.btn-primary{background:var(--sun);color:var(--ink)!important;box-shadow:0 5px 0 var(--sun-dark)}
.btn-primary:active:not(:disabled){transform:translateY(3px);box-shadow:0 2px 0 var(--sun-dark)}
.btn-secondary{background:var(--hud-2);color:#fff!important;border:2px solid var(--hud-line);box-shadow:0 4px 0 #0A1A17}
.btn-secondary:active:not(:disabled){transform:translateY(3px);box-shadow:0 1px 0 #0A1A17}
.btn-ghost{background:transparent;border:2px solid currentColor}
.btn-danger{background:var(--danger);color:#fff!important;box-shadow:0 4px 0 #6E1712}
.btn-big{min-height:64px;padding:0 34px;font-size:24px;font-weight:700}
.btn:disabled{background:#D5DCDA;color:#4E625D!important;box-shadow:0 4px 0 #A9B5B1;border-color:transparent}
.btn-ghost:disabled{background:transparent;opacity:.5;box-shadow:none}
.icon-btn{flex:none;width:48px;height:48px;border-radius:50%;border:2px solid var(--hud-line);background:var(--hud-2);display:flex;align-items:center;justify-content:center;padding:0}
.link-btn{min-height:48px;background:none;border:none;padding:0 6px;font-weight:800;font-size:15px;text-decoration:underline;text-underline-offset:3px}

/* ---------- Toast ---------- */
.ui-toast{position:absolute;top:calc(var(--m) + var(--st));left:calc(16px + var(--sl));right:calc(16px + var(--sr));margin:0 auto;width:fit-content;max-width:min(460px,calc(100% - 32px));background:#fff;color:var(--ink);border-radius:14px;padding:10px 16px;font-size:16px;font-weight:800;box-shadow:0 6px 0 rgba(16,35,31,.25);text-align:center;pointer-events:none;animation:toastIn .2s ease-out}
.ui-toast.is-bad{background:#FFE7CF}
.ui-toast.is-good{background:#DFF3E3}
.ui-root.hud-mode .ui-toast{top:calc(var(--m) + var(--st) + var(--alert-h,0px));left:calc(var(--m) + var(--sl) + var(--mis-w) + 12px);right:calc(var(--m) + var(--sr) + var(--pause) + var(--st-w) + 20px);max-width:none}
@keyframes toastIn{from{opacity:0;transform:translateY(-8px)}}

/* ---------- HUD ---------- */
.hud{position:absolute;inset:0;pointer-events:none}
.hud>*,.hud-lane-top>*,.hud-lane-bottom>*{pointer-events:auto}
.hud-lane-top,.hud-lane-bottom{pointer-events:none!important;position:absolute;display:flex;flex-direction:column;align-items:center;gap:8px}
.hud-lane-top{top:calc(var(--m) + var(--st));left:calc(var(--m) + var(--sl) + var(--mis-w) + 12px);right:calc(var(--m) + var(--sr) + var(--pause) + var(--st-w) + 20px)}
.hud-lane-bottom{bottom:calc(var(--m) + var(--sb));top:calc(var(--m) + var(--st) + var(--lane-top));justify-content:flex-end;
  left:calc(var(--m) + var(--sl) + max(var(--joy), calc(var(--bst) * 3 + 16px)) + 12px);
  right:calc(var(--m) + var(--sr) + var(--act) + var(--round) * 2 + 32px + var(--gap) * 2 + 12px)}

.hud-panel,.hud-mission,.hud-stats,.hud-shed{background:rgba(14,36,32,.92);border:1px solid var(--hud-line);border-radius:16px}
.hud-mission{position:absolute;left:calc(var(--m) + var(--sl));top:calc(var(--m) + var(--st));width:var(--mis-w);padding:4px 6px 10px 14px}
.mis-head{display:flex;align-items:center;gap:8px;min-height:48px}
.mis-title{flex:1;min-width:0;font-family:var(--display);font-weight:700;font-size:18px;line-height:1.1;color:#fff}
.mis-timer{font-family:var(--display);font-size:15px;color:var(--muted);font-variant-numeric:tabular-nums}
.mis-toggle{flex:none;width:48px;height:48px;border:none;background:transparent;border-radius:12px;display:flex;align-items:center;justify-content:center;padding:0}
.mis-toggle .ic{transform:rotate(90deg);transition:transform .15s}
.hud-mission.is-collapsed .mis-toggle .ic{transform:rotate(-90deg)}
.hud-mission.is-collapsed{padding-bottom:4px}
.hud-mission.is-collapsed .mis-list{display:none}
.mis-list{list-style:none;margin:2px 0 0;padding:0 8px 0 0;display:flex;flex-direction:column;gap:6px;font-size:14px;font-weight:700}
.mis-item{display:flex;gap:8px;align-items:flex-start;color:var(--muted)}
.mis-dot{flex:none;width:16px;height:16px;border-radius:50%;border:2px solid var(--muted);margin-top:2px}
.mis-item.is-ok{color:#fff}
.mis-item.is-ok .mis-dot{background:var(--leaf);border-color:var(--leaf)}
.mis-item.is-now{color:#fff;font-weight:800}
.mis-item.is-now .mis-dot{border-color:var(--sun);box-shadow:0 0 0 3px rgba(255,184,46,.3)}
.mis-item.is-alert{color:#FFD27A}
.mis-item.is-alert .mis-dot{border-color:var(--warn);background:var(--warn)}

.hud-pause{position:absolute;top:calc(var(--m) + var(--st));right:calc(var(--m) + var(--sr));width:var(--pause);height:var(--pause);border-radius:50%;border:3px solid rgba(255,255,255,.7);background:rgba(14,36,32,.85);display:flex;align-items:center;justify-content:center;padding:0}

.hud-stats{position:absolute;top:calc(var(--m) + var(--st));right:calc(var(--m) + var(--sr) + var(--pause) + 8px);width:var(--st-w);padding:10px 14px 12px;display:flex;flex-direction:column;gap:6px}
.st-top{display:flex;align-items:baseline;justify-content:space-between;gap:8px}
.st-clock{font-family:var(--display);font-size:32px;font-weight:600;line-height:1;font-variant-numeric:tabular-nums}
.st-phase{font-size:13px;color:var(--muted);font-weight:800;letter-spacing:.06em;text-transform:uppercase}
.hud-stats.is-night .st-phase{color:#A9C8FF}
.hud-stats.is-blackout .st-phase{color:#FFB4A8}
.st-row{display:flex;align-items:center;gap:6px;font-size:14px;font-weight:700;font-variant-numeric:tabular-nums;color:var(--muted)}
.st-row span{flex:1}
.st-row b{font-family:var(--display);font-weight:600;font-size:17px;color:#fff}
.st-bar{height:12px;border-radius:999px;background:var(--hud-2);overflow:hidden}
.st-fill{height:100%;width:0;background:var(--leaf);transition:width .25s linear}
.st-bar.is-low .st-fill{background:var(--warn)}

.hud-alert{display:flex;align-items:center;gap:12px;padding:10px 16px;border-radius:18px;background:var(--dust);border:3px solid var(--sun);max-width:100%;color:#fff}
.al-icon{color:var(--sun)}
.al-body{min-width:0}
.al-body b{display:block;font-family:var(--display);font-size:20px;line-height:1.1;color:#FFD27A}
.al-text{font-size:14px;font-weight:700}
.al-count{flex:none;font-family:var(--display);font-size:26px;font-weight:700;color:var(--sun);font-variant-numeric:tabular-nums;min-width:54px;text-align:right}
.hud-alert.is-urgent{animation:alertPulse .8s ease-in-out infinite alternate}
@keyframes alertPulse{to{border-color:var(--warn);background:#4A2A0E}}

.hud-prompt{position:absolute;left:0;top:0;background:var(--sun);color:var(--ink);font-weight:800;font-size:14px;padding:5px 10px;border-radius:10px;white-space:nowrap;pointer-events:none!important;box-shadow:0 3px 0 var(--sun-dark);will-change:transform}

.hud-meter{width:250px;flex:none;border-radius:26px;background:var(--sun);border:5px solid var(--sun-dark);padding:14px;color:var(--ink);box-shadow:0 8px 0 rgba(0,0,0,.25);display:flex;flex-direction:column;gap:8px}
.mt-screen{border-radius:12px;background:#C9D8B6;border:4px solid #2A2A2A;padding:8px 12px;text-align:right}
.mt-value{font-family:var(--mono);font-size:38px;line-height:1;color:#1A1A1A}
.mt-unit{font-family:var(--mono);font-size:14px;color:#1A1A1A;margin-top:4px}
.mt-note{font-size:14px;font-weight:800;line-height:1.3}
.hud-meter.is-ok .mt-screen{background:#BFE3B4}
.hud-meter.is-bad .mt-screen{background:#F3C6A5}

.hud-inspect{position:relative;width:min(440px,100%);max-height:100%;display:flex;flex-direction:column;background:#fff;color:var(--ink);border-radius:18px;box-shadow:0 8px 0 rgba(16,35,31,.25)}
.ins-head{flex:none;display:flex;align-items:flex-start;gap:4px;padding:4px 4px 0 18px}
.ins-head h2{flex:1;min-width:0;padding-top:10px}
.ins-scroll{overflow:auto;touch-action:pan-y;padding:4px 18px 16px;overscroll-behavior:contain}
.hud-inspect h2{font-family:var(--display);font-size:22px;font-weight:700;line-height:1.15}
.hud-inspect p{font-size:15px;line-height:1.45;color:var(--ink-2)}
.ins-live{margin-top:10px;padding:8px 10px;border-radius:10px;background:#E6F4EA;font-weight:800;font-size:14px}
.ins-close{position:relative;flex:none;width:48px;height:48px;border-radius:50%;border:none;background:transparent;color:var(--ink)!important;display:flex;align-items:center;justify-content:center;padding:0;z-index:1}
.ins-close::before{content:'';position:absolute;inset:6px;border-radius:50%;background:#EEF2F1;z-index:-1}

.hud-shed{width:min(440px,100%);max-height:100%;overflow:auto;touch-action:pan-y;padding:10px 12px 12px;display:flex;flex-direction:column;gap:6px}
.ls-head{display:flex;align-items:center;gap:8px;color:var(--sun)}
.ls-head b{flex:1;font-family:var(--display);font-size:19px;color:#fff}
.ls-saving{font-size:13px;font-weight:800;color:#9EE6A8}
.ls-hint{font-size:13px;font-weight:700;color:var(--muted);line-height:1.3}
.ls-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}
.ls-switch{display:flex;align-items:center;gap:10px;min-height:52px;padding:6px 10px;border-radius:14px;border:2px solid var(--leaf);background:#173A2C;text-align:left}
.ls-knob{flex:none;position:relative;width:36px;height:22px;border-radius:999px;background:var(--leaf)}
.ls-knob::after{content:'';position:absolute;top:3px;left:17px;width:16px;height:16px;border-radius:50%;background:#fff;transition:left .15s}
.ls-txt{display:flex;flex-direction:column;min-width:0;overflow-wrap:anywhere;hyphens:auto}
.ls-txt b{font-size:14px;line-height:1.15}
.ls-txt small{font-size:12px;font-weight:700;color:var(--muted)}
.ls-switch.is-off{border-color:#5D736E;background:var(--hud-2)}
.ls-switch.is-off .ls-knob{background:#5D736E}
.ls-switch.is-off .ls-knob::after{left:3px}
.ls-switch.is-off .ls-txt b{color:var(--muted);text-decoration:line-through}

.hud-joy{position:absolute;left:calc(var(--m) + var(--sl) + 8px);bottom:calc(var(--m) + var(--sb) + 8px);width:var(--joy);height:var(--joy);border-radius:50%;background:rgba(14,36,32,.55);border:3px solid rgba(255,255,255,.55);touch-action:none}
.hud-joy.is-active{border-color:rgba(255,255,255,.9)}
.joy-knob{position:absolute;left:50%;top:50%;width:44%;height:44%;transform:translate(0,0);margin:-22% 0 0 -22%;border-radius:50%;background:rgba(255,255,255,.92);box-shadow:0 4px 0 rgba(0,0,0,.25);pointer-events:none}

.hud-boosters{position:absolute;left:calc(var(--m) + var(--sl));bottom:calc(var(--m) + var(--sb) + var(--joy) + 22px);display:flex;gap:8px}
.bst-btn{position:relative;width:var(--bst);height:var(--bst);border-radius:16px;border:2px solid rgba(255,255,255,.6);background:rgba(14,36,32,.88);color:var(--sun)!important;display:flex;align-items:center;justify-content:center;padding:0}
.bst-count{position:absolute;top:-7px;right:-7px;min-width:24px;height:24px;padding:0 5px;border-radius:999px;background:var(--sun);color:var(--ink);font-family:var(--display);font-weight:700;font-size:14px;line-height:24px;text-align:center;border:2px solid var(--hud)}
.bst-btn:disabled{opacity:.5;color:var(--muted)!important}
.bst-btn:disabled .bst-count{background:#8FA7A1}

.hud-btns{position:absolute;right:calc(var(--m) + var(--sr));bottom:calc(var(--m) + var(--sb));display:flex;align-items:flex-end;gap:var(--gap)}
.hud-round{min-width:var(--round);border:none;background:transparent;display:flex;flex-direction:column;align-items:center;gap:3px;padding:0}
.hr-circle{width:var(--round);height:var(--round);border-radius:50%;border:3px solid rgba(255,255,255,.7);background:rgba(14,36,32,.85);display:flex;align-items:center;justify-content:center}
.hr-cap{font-size:12px;font-weight:800;line-height:1;padding:3px 7px;border-radius:999px;background:rgba(14,36,32,.85);white-space:nowrap}
.hud-round:disabled{opacity:.45}
.hud-round.is-on .hr-circle{background:var(--dust);border-color:var(--sun);color:#FFD27A}
.hud-round.is-on .hr-cap{color:#FFD27A}
.hud-act{width:var(--act);height:var(--act);border-radius:999px;border:5px solid #FFE2A1;background:var(--sun);color:var(--ink)!important;font-family:var(--display)!important;font-size:19px;font-weight:700;line-height:1.1;padding:0 16px;box-shadow:0 7px 0 var(--sun-dark);text-wrap:balance}
.hud-act:active:not(:disabled){transform:translateY(4px);box-shadow:0 3px 0 var(--sun-dark)}
.hud-act.is-idle{background:#4E625D;border-color:#8FA7A1;color:#F1F5F3!important;box-shadow:0 7px 0 #2C3B36}
.hud-act.is-drop{background:#EEF2F1;border-color:#fff;box-shadow:0 7px 0 #8FA7A1}
.hud-act:disabled{opacity:.6}

/* ---------- Saldo ---------- */
.wallet-chip{position:relative;display:inline-flex;align-items:center;gap:6px;min-height:44px;padding:0 14px 0 8px;border-radius:999px;background:rgba(14,36,32,.9);border:2px solid var(--hud-line);color:#fff;font-family:var(--display);font-weight:600;font-size:20px;font-variant-numeric:tabular-nums;white-space:nowrap}
.wallet-chip.is-btn{min-height:48px;padding-right:6px}
.wc-ic{color:var(--sun)}
.wc-plus{display:flex;align-items:center;justify-content:center;width:32px;height:32px;border-radius:50%;background:var(--sun);color:var(--ink);margin-left:4px}
.wallet-chip.is-bump{animation:chipBump .45s ease-out}
@keyframes chipBump{40%{transform:scale(1.12);border-color:var(--sun)}}
.wc-float{position:absolute;right:10px;top:100%;font-size:17px;font-weight:700;color:var(--sun);pointer-events:none;animation:floatUp 1.1s ease-out forwards;text-shadow:0 2px 0 rgba(0,0,0,.4)}
@keyframes floatUp{from{transform:translateY(-14px)}to{transform:translateY(10px);opacity:0}}

/* ---------- Pantallas: estructura ---------- */
.scr{position:absolute;inset:0;pointer-events:auto}
.scr-in{animation:scrIn .18s ease-out}
.scr-out{animation:scrOut .18s ease-in forwards;pointer-events:none}
.scr-modal.scr-in .mdl-card{animation:popIn .2s ease-out}
@keyframes scrIn{from{opacity:0;transform:translateY(10px)}}
@keyframes scrOut{to{opacity:0;transform:translateY(6px)}}
@keyframes popIn{from{transform:scale(.94);opacity:.4}}

.pg{position:absolute;inset:0;display:flex;flex-direction:column;color:#fff;
  background:radial-gradient(ellipse at 85% -20%,rgba(255,184,46,.28),transparent 55%),radial-gradient(ellipse at -10% 120%,rgba(63,163,77,.22),transparent 50%),linear-gradient(180deg,#183A34,#0E2420 70%);
  padding:var(--st) var(--sr) var(--sb) var(--sl)}
.pg-head{flex:none;display:flex;align-items:center;gap:12px;padding:10px 16px 6px;min-height:64px}
.pg-titles{flex:1;min-width:0}
.pg-title{font-family:var(--display);font-weight:700;font-size:28px;line-height:1.05}
.pg-titles .eyebrow{font-size:12px}
.pg-right{display:flex;align-items:center;gap:10px;flex:none}
.pg-body{flex:1;min-height:0;overflow:auto;touch-action:pan-y;overscroll-behavior:contain;padding:6px 16px 14px;-webkit-overflow-scrolling:touch}
.pg-foot{flex:none;display:flex;align-items:center;gap:16px;padding:10px 16px 12px;background:rgba(9,24,21,.75);border-top:1px solid var(--hud-line)}

.mdl{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;background:rgba(9,24,21,.72);padding:calc(16px + var(--st)) calc(16px + var(--sr)) calc(16px + var(--sb)) calc(16px + var(--sl))}
.mdl-card{position:relative;background:#fff;color:var(--ink);border-radius:24px;padding:22px;box-shadow:0 10px 0 rgba(0,0,0,.22);max-height:100%;overflow:auto;touch-action:pan-y;overscroll-behavior:contain}
.mdl-card .eyebrow,.lm-card .eyebrow,.shop-card .eyebrow{color:var(--sun-ink)}
.mdl-card h2{font-family:var(--display);font-weight:700;font-size:30px;line-height:1.05}
.mdl-card p{font-size:16px;line-height:1.45;color:var(--ink-2)}
.mdl-card .btn-ghost{color:var(--ink)}

.confirm{display:flex;flex-direction:column;gap:10px;width:100%}
.confirm-q{font-weight:800;font-size:16px}
.confirm-btns{display:flex;gap:10px;flex-wrap:wrap;justify-content:flex-end}

.stars{display:inline-flex;gap:2px;color:var(--sun)}
.stars .is-off{color:rgba(255,255,255,.35)}

/* ---------- Splash ---------- */
.splash{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;overflow:hidden;cursor:pointer;
  background:radial-gradient(circle at 50% 120%,rgba(255,184,46,.55),rgba(242,140,40,.15) 35%,transparent 60%),linear-gradient(180deg,#0B1E1B,#163631 60%,#2A4A2E);
  padding:var(--st) var(--sr) var(--sb) var(--sl)}
.splash-rays{position:absolute;left:50%;bottom:-60vmax;width:120vmax;height:120vmax;margin-left:-60vmax;border-radius:50%;background:repeating-conic-gradient(rgba(255,184,46,.06) 0 4deg,transparent 4deg 15deg);animation:spin 60s linear infinite;pointer-events:none}
@keyframes spin{to{transform:rotate(360deg)}}
.splash-center{position:relative;display:flex;flex-direction:column;align-items:center;gap:18px;text-align:center;padding:0 24px}
.splash-tag{font-size:18px;font-weight:700;color:var(--muted);max-width:520px;text-wrap:balance}
.splash-tap{display:inline-flex;align-items:center;gap:10px;min-height:60px;padding:0 30px;border:none;border-radius:999px;background:var(--sun);color:var(--ink)!important;font-family:var(--display)!important;font-weight:700;font-size:24px;box-shadow:0 6px 0 var(--sun-dark);animation:breathe 1.6s ease-in-out infinite}
@keyframes breathe{50%{transform:scale(1.05)}}
.splash-foot{position:absolute;bottom:calc(10px + var(--sb));left:0;right:0;text-align:center;font-size:13px;font-weight:700;color:var(--muted)}

.logo{display:inline-flex;align-items:center;gap:16px}
.logo-sun{flex:none;width:84px;height:84px;border-radius:50%;background:var(--sun);color:var(--ink);display:flex;align-items:center;justify-content:center;box-shadow:0 0 0 8px rgba(255,184,46,.22),0 6px 0 var(--sun-dark)}
.logo-sun .ic{width:56px;height:56px}
.logo-words{display:flex;flex-direction:column;align-items:flex-start;font-family:var(--display);font-weight:700;line-height:.95;letter-spacing:.04em}
.logo-a{font-size:44px;color:#fff}
.logo-b{font-size:52px;color:var(--sun)}

/* ---------- Menú principal ---------- */
.pg-menu .mm-top{flex:none;display:flex;justify-content:flex-end;padding:10px 16px 0}
.mm-main{flex:1;min-height:0;display:flex;align-items:center;justify-content:center;gap:clamp(20px,5vw,64px);padding:0 24px 16px;overflow:auto;touch-action:pan-y}
.mm-hero{flex:1 1 0;max-width:460px;display:flex;flex-direction:column;gap:16px}
.mm-tag{font-size:17px;font-weight:700;color:var(--muted);max-width:420px}
.mm-actions{flex:1 1 0;max-width:420px;display:flex;flex-direction:column;gap:12px}
.mm-actions>.btn-big{width:100%}
.mm-tiles{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}
.mm-tile{min-height:80px;border-radius:18px;border:2px solid var(--hud-line);background:var(--hud-2);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;font-family:var(--display);font-weight:600;font-size:16px;padding:6px;box-shadow:0 4px 0 #0A1A17}
.mm-tile .ic{color:var(--sun)}
.mm-tile:active{transform:translateY(3px);box-shadow:0 1px 0 #0A1A17}
.mm-bonus{display:flex;align-items:center;gap:10px;min-height:60px;padding:6px 8px 6px 12px;border-radius:16px;background:rgba(255,255,255,.06);border:2px dashed var(--hud-line)}
.mm-bonus.is-ready{border:2px solid var(--sun);background:rgba(255,184,46,.12)}
.mm-bonus.is-claimed{border-style:solid;border-color:var(--leaf)}
.mm-bonus-ic{color:var(--sun);flex:none}
.mm-bonus-txt{flex:1;display:flex;flex-direction:column;min-width:0}
.mm-bonus-txt b{font-family:var(--display);font-weight:600;font-size:17px}
.mm-bonus-txt small{font-size:14px;font-weight:700;color:var(--muted)}

/* ---------- Mapa de niveles ---------- */
.pg-map .pg-body{position:relative;overflow:hidden}
.lm-map{position:relative;width:100%;height:100%;min-height:230px}
.lm-path{position:absolute;inset:0;width:100%;height:100%;overflow:visible}
.lm-road{fill:none;stroke:rgba(255,255,255,.10);stroke-width:26;stroke-linecap:round}
.lm-dash{fill:none;stroke:var(--sun);stroke-width:4;stroke-dasharray:2 12;stroke-linecap:round;opacity:.8}
.lm-node{position:absolute;width:150px;margin-left:-75px;margin-top:-38px;display:flex;flex-direction:column;align-items:center;gap:4px;text-align:center}
.lm-bubble{width:76px;height:76px;border-radius:50%;border:4px solid #FFE2A1;background:var(--sun);color:var(--ink)!important;display:flex;align-items:center;justify-content:center;padding:0;box-shadow:0 6px 0 var(--sun-dark)}
.lm-bubble:active{transform:translateY(3px);box-shadow:0 3px 0 var(--sun-dark)}
.lm-num{font-family:var(--display);font-weight:700;font-size:34px;line-height:1}
.lm-node.is-done .lm-bubble{background:#FFD27A}
.lm-node.is-next .lm-bubble{animation:ring 1.6s ease-out infinite}
@keyframes ring{0%{box-shadow:0 6px 0 var(--sun-dark),0 0 0 0 rgba(255,184,46,.6)}100%{box-shadow:0 6px 0 var(--sun-dark),0 0 0 18px rgba(255,184,46,0)}}
.lm-node.is-locked .lm-bubble{background:#4E625D;border-color:#8FA7A1;color:#F1F5F3!important;box-shadow:0 6px 0 #2C3B36}
.lm-node.is-new .lm-bubble{animation:popIn .4s ease-out}
.lm-name{font-family:var(--display);font-weight:600;font-size:17px;line-height:1.1;text-shadow:0 2px 4px rgba(0,0,0,.5);text-wrap:balance}
.lm-node.is-locked .lm-name{color:var(--muted)}
.lm-cost{display:inline-flex;align-items:center;gap:4px;padding:2px 8px;border-radius:999px;background:rgba(0,0,0,.35);color:var(--sun);font-weight:800;font-size:13px}
.lm-sheet{position:absolute;inset:0;z-index:2;display:flex;align-items:center;justify-content:center;background:rgba(9,24,21,.72);padding:calc(12px + var(--st)) calc(16px + var(--sr)) calc(12px + var(--sb)) calc(16px + var(--sl))}
.lm-card{width:min(520px,100%);max-height:100%;overflow:auto;touch-action:pan-y;background:#fff;color:var(--ink);border-radius:22px;padding:18px 20px;display:flex;flex-direction:column;gap:10px;box-shadow:0 10px 0 rgba(0,0,0,.22)}
.lm-card-head{display:flex;align-items:center;gap:12px}
.lm-card-head h2{font-family:var(--display);font-size:26px;line-height:1.05}
.lm-card-ic{flex:none;width:48px;height:48px;border-radius:50%;background:#EEF2F1;display:flex;align-items:center;justify-content:center}
.lm-card p{font-size:15px;line-height:1.4;color:var(--ink-2)}
.lm-card .lm-short{font-weight:800;color:#9A4A06}
.lm-card-btns{display:flex;gap:10px;flex-wrap:wrap;justify-content:flex-end}
.lm-card .btn-ghost{color:var(--ink)}

/* ---------- Taller ---------- */
.ws-grid{display:grid;grid-template-columns:minmax(0,.85fr) minmax(0,1.15fr);gap:16px;align-items:start}
.ws-story{display:flex;flex-direction:column;gap:8px;padding-top:4px}
.ws-sub{font-family:var(--display);font-weight:700;font-size:26px;line-height:1.1;text-wrap:balance}
.ws-text{font-size:16px;line-height:1.45;color:#DCE7E3}
.ws-facts{list-style:none;margin:4px 0 0;padding:0;display:flex;flex-direction:column;gap:6px}
.ws-facts li{display:flex;gap:8px;align-items:flex-start;font-size:14px;font-weight:700;color:var(--muted)}
.ws-facts li .ic{color:var(--sun);margin-top:1px}
.ws-facts li.is-warn{color:#FFD27A}
.ws-facts li.is-warn .ic{color:var(--warn)}
.ws-shop{background:#fff;color:var(--ink);border-radius:20px;padding:12px;display:flex;flex-direction:column;gap:8px}
.ws-shop .eyebrow{color:var(--sun-ink);padding:2px 4px}
.ws-item{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:10px;align-items:center;padding:8px 10px;border-radius:16px;background:var(--paper-2)}
.ws-ic{width:42px;height:42px;border-radius:12px;background:#fff;color:var(--sun-dark);display:flex;align-items:center;justify-content:center}
.ws-txt{display:flex;flex-direction:column;min-width:0}
.ws-txt b{font-family:var(--display);font-weight:600;font-size:18px;line-height:1.15}
.ws-txt small{font-size:13px;font-weight:700;color:var(--ink-3);line-height:1.3}
.ws-stepper{display:flex;align-items:center;gap:6px}
.ws-step{width:48px;height:48px;border-radius:14px;border:none;background:var(--hud);color:#fff!important;display:flex;align-items:center;justify-content:center;padding:0}
.ws-step:disabled{opacity:.3}
.ws-out{min-width:34px;text-align:center;font-family:var(--display);font-size:26px;font-weight:600;font-variant-numeric:tabular-nums}
.ws-item.is-fixed .ws-ic{color:var(--leaf-dark)}
.ws-incl{font-weight:800;color:var(--leaf-dark);padding:0 8px}
.ws-boosters{display:flex;flex-direction:column;gap:6px;padding-top:4px}
.ws-bst-title{font-family:var(--display);font-weight:600;font-size:17px;padding:0 4px}
.ws-bst-empty{display:flex;align-items:center;gap:6px;flex-wrap:wrap;font-size:14px;font-weight:700;color:var(--ink-3);padding:0 4px}
.ws-bst-empty .link-btn{color:var(--ink)}
.ws-bst-list{display:flex;flex-wrap:wrap;gap:8px}
.ws-bst{display:flex;align-items:center;gap:8px;min-height:52px;padding:4px 8px 4px 10px;border-radius:14px;border:2px solid var(--line);background:#fff;color:var(--ink)!important;text-align:left}
.ws-bst .ic:first-child{color:var(--sun-dark)}
.ws-bst-txt{display:flex;flex-direction:column}
.ws-bst-txt b{font-size:14px;line-height:1.1}
.ws-bst-txt small{font-size:12px;font-weight:700;color:var(--ink-3)}
.ws-bst-check{width:28px;height:28px;border-radius:50%;background:var(--paper-2);display:flex;align-items:center;justify-content:center}
.ws-bst.is-on{border-color:var(--leaf-dark);background:#E6F4EA}
.ws-bst.is-on .ws-bst-check{background:var(--leaf-dark);color:#fff}
.ws-budget{flex:1;min-width:0;display:flex;flex-direction:column;gap:5px}
.ws-budget-row{display:flex;justify-content:space-between;align-items:baseline;font-weight:800;color:var(--muted);font-size:14px}
.ws-budget-row b{font-family:var(--display);font-size:22px;color:#fff;font-variant-numeric:tabular-nums}
.ws-bar{height:12px;border-radius:999px;background:rgba(255,255,255,.14);overflow:hidden}
.ws-bar div{height:100%;width:0;background:var(--sun);transition:width .2s}
.ws-bar.is-over div{background:var(--warn)}
.ws-summary{font-size:13px;font-weight:700;color:var(--muted)}
.ws-foot-right{display:flex;align-items:center;gap:12px;flex:none}
.ws-warn{max-width:220px;font-size:14px;font-weight:800;color:#FFD27A;text-align:right;line-height:1.25}
.pg-workshop .pg-foot .btn{min-height:56px;font-size:22px;padding:0 28px}

/* ---------- Tienda ---------- */
.tabs{display:flex;gap:4px;padding:4px;border-radius:999px;background:rgba(0,0,0,.25);border:1px solid var(--hud-line)}
.tab{display:inline-flex;align-items:center;gap:6px;min-height:48px;padding:0 16px;border-radius:999px;border:none;background:transparent;font-family:var(--display)!important;font-weight:600;font-size:17px}
.tab .ic{color:var(--sun)}
.tab.is-on{background:var(--sun);color:var(--ink)!important}
.tab.is-on .ic{color:var(--ink)}
.demo-banner{flex:none;display:flex;align-items:center;gap:8px;margin:0 16px 8px;padding:8px 12px;border-radius:12px;background:#FFF1DC;color:var(--ink);border-left:6px solid var(--sun);font-weight:800;font-size:15px}
.demo-banner .ic{color:var(--sun-ink)}
.shop-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}
.shop-empty{color:var(--muted);font-weight:700;padding:20px 0}
.shop-card{display:flex;flex-direction:column;gap:8px;background:#fff;color:var(--ink);border-radius:18px;padding:14px;box-shadow:0 5px 0 rgba(0,0,0,.2)}
.sc-head{display:flex;align-items:center;gap:12px}
.sc-ic{position:relative;flex:none;width:52px;height:52px;border-radius:50%;background:#FFF1DC;color:var(--sun-ink);display:flex;align-items:center;justify-content:center}
.sc-swatch{position:absolute;right:-4px;bottom:-4px;width:24px;height:24px;border-radius:50%;border:3px solid #fff;box-shadow:0 0 0 1px var(--line)}
.sc-titles{min-width:0;display:flex;flex-direction:column;gap:2px}
.sc-titles h3{font-family:var(--display);font-weight:600;font-size:19px;line-height:1.1}
.sc-amount{display:inline-flex;align-items:center;gap:4px;font-weight:800;color:var(--sun-ink);font-size:15px}
.sc-owned{font-size:13px;font-weight:800;color:var(--leaf-dark)}
.sc-desc{font-size:14px;line-height:1.4;color:var(--ink-2);flex:1}
.sc-foot{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-top:auto}
.sc-foot .btn{flex:1 1 auto}
.sc-foot .btn-ghost{color:var(--ink)}
.sc-note{font-size:12px;font-weight:800;color:var(--ink-3)}
.sc-foot.is-confirm{flex-direction:column;align-items:stretch;gap:8px;background:var(--paper-2);border-radius:14px;padding:8px}
.sc-q{font-weight:800;font-size:15px;color:var(--ink)}
.sc-btns{display:flex;gap:8px}
.sc-btns .btn{flex:1;padding:0 12px}
.sc-equipped{display:inline-flex;align-items:center;gap:6px;min-height:48px;font-weight:800;color:var(--leaf-dark)}
.sheet{position:absolute;inset:0;z-index:3;display:flex;align-items:center;justify-content:center;background:rgba(9,24,21,.72);padding:16px}
.sheet-card{width:min(420px,100%);display:flex;flex-direction:column;align-items:center;gap:10px;text-align:center}
.sheet-card h2{font-size:26px}
.sheet-ic{width:60px;height:60px;border-radius:50%;display:flex;align-items:center;justify-content:center;background:#E6F4EA;color:var(--leaf-dark)}
.sheet-card.is-bad .sheet-ic{background:#FFE7CF;color:#9A4A06}
.sheet-btns{display:flex;gap:10px;flex-wrap:wrap;justify-content:center;margin-top:4px}
.spinner{width:52px;height:52px;border-radius:50%;border:6px solid #EEF2F1;border-top-color:var(--sun);animation:spin .8s linear infinite}

/* ---------- Control parental ---------- */
.pgm{width:min(600px,100%);display:grid;grid-template-columns:minmax(0,1fr) auto;gap:20px;align-items:center}
.pgm.is-shake{animation:shake .35s}
@keyframes shake{25%{transform:translateX(-8px)}75%{transform:translateX(8px)}}
.pgm-left{display:flex;flex-direction:column;gap:8px;align-items:flex-start}
.pgm-title{font-size:24px!important}
.pgm-q{font-family:var(--display);font-weight:600;font-size:28px;line-height:1.1}
.pgm-display{display:block;min-width:140px;padding:6px 14px;border-radius:14px;border:3px solid var(--ink);font-family:var(--display);font-weight:700;font-size:36px;line-height:1.1;text-align:center;font-variant-numeric:tabular-nums}
.pgm-display.is-empty{color:#8FA7A1}
.pgm-msg{min-height:20px;font-weight:800;font-size:14px;color:#9A4A06}
.pgm-cancel{color:var(--ink)}
.pgm-keys{display:grid;grid-template-columns:repeat(3,64px);grid-auto-rows:52px;gap:8px}
.pgm-key{border:none;border-radius:14px;background:var(--paper-2);color:var(--ink)!important;font-family:var(--display)!important;font-weight:700;font-size:26px;display:flex;align-items:center;justify-content:center;box-shadow:0 3px 0 var(--line);padding:0}
.pgm-key:active{transform:translateY(2px);box-shadow:0 1px 0 var(--line)}
.pgm-key.is-fn{background:#EEF2F1}
.pgm-key.is-ok{background:var(--leaf-dark);color:#fff!important;box-shadow:0 3px 0 #1D5426}

/* ---------- Vestuario ---------- */
.wr-grid{display:grid;grid-template-columns:minmax(180px,.8fr) minmax(0,1.2fr);gap:20px;align-items:start}
.wr-preview{display:flex;flex-direction:column;align-items:center;gap:6px;position:sticky;top:0}
.wr-svg{width:100%;max-width:240px;height:auto;max-height:calc(100vh - 140px)}
.wr-name{font-weight:800;color:var(--muted);font-size:14px;text-align:center}
.wr-options{display:flex;flex-direction:column;gap:14px}
.wr-sec h2{display:flex;align-items:center;gap:8px;font-family:var(--display);font-weight:600;font-size:20px;margin-bottom:8px}
.wr-sec h2 .ic{color:var(--sun)}
.wr-swatches{display:flex;flex-wrap:wrap;gap:10px}
.wr-sw{position:relative;width:76px;min-height:84px;border:none;background:transparent;display:flex;flex-direction:column;align-items:center;gap:4px;padding:4px 0}
.wr-dot{width:52px;height:52px;border-radius:50%;border:3px solid rgba(255,255,255,.85);box-shadow:0 4px 0 rgba(0,0,0,.3)}
.wr-sw.is-on .wr-dot{box-shadow:0 0 0 4px var(--sun),0 4px 0 rgba(0,0,0,.3)}
.wr-sw.is-locked .wr-dot{opacity:.55}
.wr-badge{position:absolute;top:0;right:6px;width:24px;height:24px;border-radius:50%;background:var(--sun);color:var(--ink);display:flex;align-items:center;justify-content:center;border:2px solid var(--hud)}
.wr-badge.is-lock{background:#4E625D;color:#fff}
.wr-label{font-size:12px;font-weight:800;line-height:1.15;text-align:center;color:#E4ECEA}
.wr-info{display:flex;flex-direction:column;align-items:center;gap:6px;text-align:center;font-weight:800;font-size:14px;color:#FFD27A}
.wr-info:empty{display:none}

/* ---------- Resultado ---------- */
.rs{width:min(860px,100%);display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);grid-template-areas:'left right' 'btns btns';gap:14px 22px}
.rs-left{grid-area:left;display:flex;flex-direction:column;gap:8px}
.rs-right{grid-area:right;display:flex;flex-direction:column;gap:10px}
.rs-btns{grid-area:btns;display:flex;gap:10px;flex-wrap:wrap;justify-content:flex-end}
.rs-btns .btn{flex:0 1 auto}
.rs-title{font-size:32px}
.rs-sub{font-weight:700}
.rs-stars{display:flex;gap:6px}
.rs-star{color:#C9D3D0}
.rs-star.is-on{color:var(--sun);filter:drop-shadow(0 3px 0 var(--sun-dark))}
.rs-star.is-wait{transform:scale(0);opacity:0}
.rs-star.is-pop{animation:starPop .45s cubic-bezier(.3,1.6,.5,1)}
@keyframes starPop{0%{transform:scale(0) rotate(-30deg);opacity:0}100%{transform:scale(1);opacity:1}}
.rs-kpis{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}
.rs-kpi{background:var(--paper-2);border-radius:14px;padding:8px 10px;font-size:13px;font-weight:700;color:var(--ink-3);display:flex;flex-direction:column;gap:2px}
.rs-kpi b{display:flex;align-items:center;gap:4px;font-family:var(--display);font-weight:600;font-size:24px;color:var(--ink);font-variant-numeric:tabular-nums}
.rs-kpi b .ic{color:var(--sun-dark)}
.rs-unlock{display:flex;align-items:center;gap:8px;padding:10px 12px;border-radius:14px;background:#FFF1DC;font-weight:800}
.rs-tips{background:#E6F4EA;border-radius:16px;padding:12px 14px}
.rs-tips-t{display:flex;align-items:center;gap:6px;font-family:var(--display);font-weight:600;font-size:18px;color:var(--leaf-dark);margin-bottom:4px}
.rs-tips ul{margin:0;padding-left:20px;display:flex;flex-direction:column;gap:4px;font-size:15px;line-height:1.4;color:var(--ink-2)}
.mdl-result .btn-secondary{background:var(--hud)}

/* ---------- Pausa ---------- */
.pm{width:min(480px,100%);display:flex;flex-direction:column;gap:12px}
.pm-head{display:flex;align-items:center;gap:12px}
.pm-ic{width:48px;height:48px;border-radius:50%;background:var(--paper-2);display:flex;align-items:center;justify-content:center}
.pm>.btn-big{width:100%}
.pm-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
.pm-grid .btn{padding:0 12px;font-size:16px}
.pm-sound{grid-column:1/-1}
.pm .btn.is-armed{background:var(--danger);border-color:var(--danger)}

/* ---------- Ajustes ---------- */
.set-list{max-width:760px;margin:0 auto;display:flex;flex-direction:column;gap:10px}
.set-row{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:12px;align-items:center;padding:10px 14px;border-radius:16px;background:var(--hud-2);border:1px solid var(--hud-line)}
.set-ic{width:44px;height:44px;border-radius:12px;background:rgba(255,255,255,.07);color:var(--sun);display:flex;align-items:center;justify-content:center}
.set-ic.is-danger{color:#FF9C8F}
.set-txt{display:flex;flex-direction:column;min-width:0}
.set-txt b{font-family:var(--display);font-weight:600;font-size:18px}
.set-txt small{font-size:14px;font-weight:700;color:var(--muted)}
.set-row .btn-ghost{color:#fff}
.seg{display:flex;padding:4px;gap:4px;border-radius:999px;background:rgba(0,0,0,.3)}
.seg-btn{min-height:48px;min-width:72px;padding:0 14px;border:none;border-radius:999px;background:transparent;font-family:var(--display)!important;font-weight:600;font-size:17px}
.seg-btn.is-on{background:var(--sun);color:var(--ink)!important}
.switch{position:relative;width:72px;height:48px;border:none;background:transparent;padding:0}
.switch::before{content:'';position:absolute;left:4px;right:4px;top:8px;bottom:8px;border-radius:999px;background:#5D736E;transition:background .15s}
.switch .switch-knob{position:absolute;top:12px;left:10px;width:24px;height:24px;border-radius:50%;background:#fff;transition:left .15s}
.switch.is-on::before{background:var(--leaf-dark)}
.switch.is-on .switch-knob{left:38px}
.set-reset{display:flex;flex-direction:column;gap:8px}
.set-confirm{display:flex;flex-direction:column;gap:8px;padding:10px 14px;border-radius:16px;background:rgba(179,38,30,.16);border:1px solid #6E1712}
.set-confirm label{font-weight:700;font-size:15px}
.set-confirm-row{display:flex;gap:10px;flex-wrap:wrap;align-items:center}
.set-confirm-row .btn-ghost{color:#fff}
.set-input{height:48px;width:170px;border-radius:12px;border:2px solid #fff;background:#fff;color:var(--ink);padding:0 12px;font-size:20px;font-weight:800;letter-spacing:.15em;text-transform:uppercase}
.set-about{display:flex;flex-direction:column;align-items:center;gap:2px;padding:12px 0 4px;font-size:14px;font-weight:700;color:var(--muted)}

/* ---------- Pantallas angostas ---------- */
@media (max-width:700px){
  .ws-grid,.wr-grid{grid-template-columns:minmax(0,1fr)}
  .rs{grid-template-columns:minmax(0,1fr);grid-template-areas:'left' 'right' 'btns'}
  .mm-main{flex-direction:column;justify-content:flex-start;padding-top:8px}
}

/* ---------- Celulares en horizontal: pantallas bajas ---------- */
@media (max-height:520px){
  :root{--m:10px;--mis-w:250px;--st-w:172px;--pause:48px;--joy:112px;--act:100px;--round:60px;--gap:10px;--bst:52px;--lane-top:136px}
  .hud-mission{padding:0 4px 8px 12px;border-radius:12px}
  .mis-title{font-size:15px}
  .mis-timer{font-size:13px}
  .mis-list{font-size:13px}
  .mis-item:not(.is-now):not(.is-alert){display:none}
  .hud-stats{padding:7px 10px 9px;gap:3px;border-radius:12px}
  .st-clock{font-size:24px}
  .st-phase{font-size:11px}
  .st-row{font-size:12px}
  .st-row b{font-size:14px}
  .st-bar{height:9px}
  .ui-toast{font-size:14px;padding:8px 12px}
  .hud-alert{padding:6px 12px;gap:8px;border-radius:14px}
  .al-icon .ic{width:26px;height:26px}
  .al-body b{font-size:16px}
  .al-text{font-size:12.5px}
  .al-count{font-size:20px;min-width:44px}
  .hud-joy{left:calc(var(--m) + var(--sl) + 4px);bottom:calc(var(--m) + var(--sb) + 2px)}
  .hud-boosters{bottom:calc(var(--m) + var(--sb) + var(--joy) + 14px)}
  .hud-act{font-size:15px;padding:0 8px;border-width:4px}
  .hr-cap{font-size:11px;padding:2px 6px}
  .hud-round .ic{width:22px;height:22px}
  .hud-meter{width:230px;padding:9px;gap:5px;border-radius:20px;border-width:4px}
  .mt-value{font-size:26px}
  .mt-unit{font-size:12px}
  .mt-note{font-size:12px}
  .hud-inspect h2{font-size:18px}
  .hud-inspect p{font-size:13.5px}
  .ins-scroll{padding:2px 14px 12px}
  .ins-head{padding-left:14px}
  .ins-head h2{padding-top:12px}
  .hud-shed{padding:8px 10px;gap:5px}
  .ls-head b{font-size:16px}
  .ls-hint{font-size:12px}
  .ls-switch{min-height:48px;padding:4px 6px;gap:6px}
  .ls-knob{width:30px;height:18px}
  .ls-knob::after{width:12px;height:12px;left:15px}
  .ls-txt b{font-size:13px}

  .pg-head{min-height:56px;padding:6px 14px 4px}
  .pg-title{font-size:23px}
  .pg-body{padding:4px 14px 10px}
  .pg-foot{padding:7px 14px 8px}
  .wallet-chip{font-size:18px}
  .btn-big{min-height:56px;font-size:21px}
  .mdl{padding:calc(10px + var(--st)) calc(16px + var(--sr)) calc(10px + var(--sb)) calc(16px + var(--sl))}
  .mdl-card{padding:14px 18px;border-radius:18px}
  .mdl-card h2{font-size:24px}
  .mdl-card p{font-size:14px}

  .logo-sun{width:60px;height:60px}
  .logo-sun .ic{width:40px;height:40px}
  .logo-a{font-size:32px}
  .logo-b{font-size:38px}
  .splash-center{gap:12px}
  .splash-tag{font-size:15px}
  .splash-tap{min-height:54px;font-size:21px}

  .pg-menu .mm-top{padding:8px 14px 0}
  .mm-main{padding:0 20px 10px}
  .mm-tag{font-size:15px}
  .mm-actions{gap:9px}
  .mm-tile{min-height:66px;font-size:15px}
  .mm-tile .ic{width:26px;height:26px}
  .mm-bonus{min-height:54px}

  .lm-bubble{width:62px;height:62px}
  .lm-num{font-size:28px}
  .lm-node{margin-top:-31px;width:140px;margin-left:-70px}
  .lm-name{font-size:15px}
  .lm-card{padding:14px 16px;gap:8px}
  .lm-card-head h2{font-size:22px}

  .ws-sub{font-size:21px}
  .ws-text{font-size:14px}
  .ws-facts li{font-size:13px}
  .ws-shop{padding:8px;gap:6px}
  .ws-item{padding:5px 8px;gap:8px}
  .ws-ic{width:36px;height:36px}
  .ws-txt b{font-size:16px}
  .ws-txt small{font-size:12px}
  .ws-out{font-size:22px;min-width:28px}
  .ws-budget-row b{font-size:18px}
  .ws-summary{font-size:12px}
  .ws-warn{font-size:13px;max-width:180px}
  .pg-workshop .pg-foot .btn{min-height:52px;font-size:20px}

  .demo-banner{margin:0 14px 6px;padding:6px 10px;font-size:14px}
  .tab{padding:0 12px;font-size:15px}
  .shop-card{padding:10px 12px;gap:6px}
  .sc-ic{width:44px;height:44px}
  .sc-titles h3{font-size:17px}
  .sc-desc{font-size:13px}

  .pgm{gap:16px}
  .pgm-title{font-size:20px!important}
  .pgm-q{font-size:24px}
  .pgm-display{font-size:30px}
  .pgm-keys{grid-template-columns:repeat(3,60px);grid-auto-rows:48px;gap:7px}

  .wr-svg{max-width:150px}
  .wr-sw{width:68px;min-height:76px}
  .wr-dot{width:46px;height:46px}
  .wr-sec h2{font-size:17px;margin-bottom:4px}
  .wr-options{gap:8px}

  .rs{gap:8px 18px}
  .rs-title{font-size:24px}
  .rs-star .ic{width:40px;height:40px}
  .rs-kpi{padding:6px 8px;font-size:12px}
  .rs-kpi b{font-size:19px}
  .rs-tips{padding:8px 12px}
  .rs-tips-t{font-size:16px}
  .rs-tips ul{font-size:13.5px}
  .rs-unlock{padding:6px 10px;font-size:14px}

  .pm{gap:9px}
  .set-row{padding:7px 12px}
  .set-txt b{font-size:16px}
  .set-txt small{font-size:13px}
}
/* ---------- Tablets ---------- */
@media (min-height:700px) and (min-width:900px){
  .logo-sun{width:116px;height:116px}
  .logo-sun .ic{width:76px;height:76px}
  .logo-a{font-size:60px}
  .logo-b{font-size:72px}
  .mm-hero{max-width:540px}
  .mm-tag{font-size:20px}
  .mm-actions{max-width:500px;gap:16px}
  .mm-actions>.btn-big{min-height:80px;font-size:30px}
  .mm-tile{min-height:104px;font-size:19px}
  .mm-tile .ic{width:36px;height:36px}
  .lm-bubble{width:96px;height:96px}
  .lm-num{font-size:42px}
  .lm-node{margin-top:-48px;width:180px;margin-left:-90px}
  .lm-name{font-size:20px}
  .pgm-keys{grid-template-columns:repeat(3,80px);grid-auto-rows:64px;gap:10px}
}
@media (max-height:320px){
  .mm-hero .mm-tag{display:none}
}

@media (prefers-reduced-motion:reduce){
  .ui-root *,.ui-root *::before,.ui-root *::after{animation-duration:.001ms!important;animation-iteration-count:1!important;transition-duration:.001ms!important}
  .splash-rays{animation:none}
}
`;
