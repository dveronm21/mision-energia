/**
 * CSS de la sala de espera del tele. Unidad --u = 1% del alto de un lienzo 16:9 (escala igual en
 * 1280×720 y 1920×1080). Área segura de TV: 5% en cada borde.
 */
export const LOBBY_CSS = String.raw`
@font-face{font-family:'Fredoka';font-weight:600;font-display:swap;src:url(fonts/fredoka-latin-600-normal.woff2) format('woff2')}
@font-face{font-family:'Fredoka';font-weight:700;font-display:swap;src:url(fonts/fredoka-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:'Nunito';font-weight:700;font-display:swap;src:url(fonts/nunito-latin-700-normal.woff2) format('woff2')}
@font-face{font-family:'Nunito';font-weight:800;font-display:swap;src:url(fonts/nunito-latin-800-normal.woff2) format('woff2')}
@font-face{font-family:'Share Tech Mono';font-weight:400;font-display:swap;src:url(fonts/share-tech-mono-latin-400-normal.woff2) format('woff2')}
.rl{--u:min(1vh,.5625vw);--sun:#FFB82E;--sun-dark:#B9781A;--ink:#10231F;--hud:#0E2420;--hud2:#1F3D37;--line:#2F5A51;--muted:#C3D6D0;--leaf:#3FA34D;
  position:fixed;inset:0;z-index:50;overflow:hidden;color:#fff;font-family:'Nunito',system-ui,sans-serif;
  background:radial-gradient(70% 90% at 92% 4%,rgba(255,184,46,.20) 0,rgba(255,184,46,0) 55%),radial-gradient(120% 100% at 80% 0%,#1F3D37 0,#0E2420 62%);
  -webkit-user-select:none;user-select:none}
.rl[hidden]{display:none}
.rl *,.rl *::before,.rl *::after{box-sizing:border-box}
.rl h1,.rl p{margin:0}
.rl::before{content:'';position:absolute;right:-14vh;top:-14vh;width:44vh;height:44vh;border-radius:50%;background:radial-gradient(circle,#FFD27A 0,#FFB82E 45%,rgba(255,184,46,0) 70%);opacity:.18;pointer-events:none}
.rl-safe{position:absolute;inset:5vh 5vw;display:grid;grid-template-columns:auto minmax(0,1fr);gap:calc(var(--u)*6);align-items:center}

.rl-qrcol{display:flex;flex-direction:column;align-items:center;gap:calc(var(--u)*2.2);width:calc(var(--u)*60)}
.rl-qrcard{background:#fff;border-radius:calc(var(--u)*3.2);padding:calc(var(--u)*2);box-shadow:0 calc(var(--u)*1.2) 0 rgba(0,0,0,.35),0 0 0 calc(var(--u)*.8) var(--sun)}
.rl-qr{width:calc(var(--u)*52);height:calc(var(--u)*52);display:flex;align-items:center;justify-content:center}
.rl-qr svg{width:100%;height:100%;display:block}
.rl-noqr{display:flex;flex-direction:column;gap:calc(var(--u)*1.5);align-items:center;text-align:center;color:var(--ink);padding:calc(var(--u)*4)}
.rl-noqr b{font-family:'Fredoka',sans-serif;font-size:calc(var(--u)*6)}
.rl-noqr span{font-size:calc(var(--u)*3.2);font-weight:800}
.rl-scan{font-size:calc(var(--u)*3.6);font-weight:800;line-height:1.25;text-align:center;text-wrap:balance}
.rl-url{font-family:'Share Tech Mono',ui-monospace,monospace;font-size:calc(var(--u)*4.2);color:var(--sun);background:rgba(0,0,0,.28);border:calc(var(--u)*.3) solid var(--line);border-radius:999px;padding:calc(var(--u)*.6) calc(var(--u)*3);letter-spacing:.02em;white-space:nowrap;max-width:100%;overflow:hidden;text-overflow:ellipsis}
.rl-url.is-off{color:var(--muted)}

.rl-main{display:flex;flex-direction:column;gap:calc(var(--u)*4);min-width:0}
.rl-head{display:flex;flex-direction:column;gap:calc(var(--u)*1.2)}
.rl-eyebrow{font-size:calc(var(--u)*2.8);font-weight:800;letter-spacing:.14em;text-transform:uppercase;color:var(--sun)}
.rl-title{font-family:'Fredoka',sans-serif;font-weight:700;font-size:calc(var(--u)*8);line-height:1.02;letter-spacing:-.01em}
.rl-sub{font-size:calc(var(--u)*3.2);font-weight:700;color:var(--muted);line-height:1.3}

.rl-slots{display:flex;flex-direction:column;gap:calc(var(--u)*2.4)}
.rl-slot{--pc:#F28C28;display:flex;align-items:center;gap:calc(var(--u)*3);min-height:calc(var(--u)*16);padding:calc(var(--u)*2) calc(var(--u)*3);border-radius:calc(var(--u)*3);background:rgba(31,61,55,.92);border:calc(var(--u)*.5) solid var(--pc);box-shadow:0 calc(var(--u)*.8) 0 rgba(0,0,0,.3)}
.rl-slot.is-empty{background:rgba(14,36,32,.55);border-style:dashed;border-color:var(--line);box-shadow:none}
.rl-slot.is-off{border-style:dashed}
.rl-avatar{position:relative;flex:none;width:calc(var(--u)*11);height:calc(var(--u)*11);border-radius:50%;background:var(--pc);color:var(--ink);display:flex;align-items:center;justify-content:center;box-shadow:inset 0 calc(var(--u)*-.8) 0 rgba(0,0,0,.18)}
.rl-num{font-family:'Fredoka',sans-serif;font-weight:700;font-size:calc(var(--u)*6.2);line-height:1}
.rl-helmet{display:none}
.rl-slot.is-empty .rl-avatar{background:transparent;border:calc(var(--u)*.5) dashed var(--pc);color:var(--pc);box-shadow:none;opacity:.8}
.rl-slot.is-off .rl-avatar{opacity:.55}
.rl-info{flex:1;min-width:0;display:flex;flex-direction:column;gap:calc(var(--u)*.6)}
.rl-name{font-family:'Fredoka',sans-serif;font-weight:600;font-size:calc(var(--u)*5.2);line-height:1.05;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.rl-slot.is-empty .rl-name{color:var(--muted)}
.rl-slot.is-empty .rl-name::after{content:'';display:inline-block;width:1.2em;text-align:left;animation:rlDots 1.6s steps(4,end) infinite}
@keyframes rlDots{0%{content:''}25%{content:'.'}50%{content:'..'}75%,100%{content:'...'}}
.rl-status{font-size:calc(var(--u)*2.9);font-weight:800;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.rl-slot.is-off .rl-status{color:#FFD27A}
.rl-ping{flex:none;display:flex;align-items:center;gap:calc(var(--u)*1);font-family:'Share Tech Mono',monospace;font-size:calc(var(--u)*3.2);padding:calc(var(--u)*.8) calc(var(--u)*1.8);border-radius:999px;background:rgba(0,0,0,.3)}
.rl-ping[hidden]{display:none}
.rl-bars{display:flex;align-items:flex-end;gap:calc(var(--u)*.4);height:calc(var(--u)*2.8)}
.rl-bars i{display:block;width:calc(var(--u)*.8);border-radius:2px;background:rgba(255,255,255,.25)}
.rl-bars i:nth-child(1){height:40%}.rl-bars i:nth-child(2){height:70%}.rl-bars i:nth-child(3){height:100%}
.rl-ping[data-q=good] i,.rl-ping[data-q=ok] i:nth-child(-n+2),.rl-ping[data-q=bad] i:nth-child(1){background:var(--leaf)}
.rl-ping[data-q=ok] i:nth-child(-n+2){background:var(--sun)}
.rl-ping[data-q=bad] i:nth-child(1){background:#F28C28}
.rl-kick{flex:none;display:flex;align-items:center;gap:calc(var(--u)*.8);min-height:calc(var(--u)*7.4);padding:0 calc(var(--u)*2.2);border-radius:999px;border:calc(var(--u)*.35) solid rgba(255,255,255,.45);background:transparent;color:#fff;font:800 calc(var(--u)*2.8) 'Nunito',sans-serif;cursor:pointer}
.rl-kick[hidden]{display:none}
.rl-kick svg{width:calc(var(--u)*3);height:calc(var(--u)*3)}

.rl-foot{display:flex;flex-direction:column;gap:calc(var(--u)*1.6)}
.rl-actions{display:flex;gap:calc(var(--u)*2.4);align-items:center}
.rl-btn{display:inline-flex;align-items:center;justify-content:center;gap:calc(var(--u)*1.4);min-height:calc(var(--u)*11);padding:0 calc(var(--u)*5.5);border-radius:999px;border:none;font-family:'Fredoka',sans-serif;font-weight:700;font-size:calc(var(--u)*4.8);cursor:pointer;transition:transform .12s,box-shadow .12s}
.rl-btn svg{width:calc(var(--u)*4.2);height:calc(var(--u)*4.2)}
.rl-btn-primary{background:var(--sun);color:var(--ink);box-shadow:0 calc(var(--u)*.9) 0 var(--sun-dark)}
.rl-btn-primary:disabled{background:#3B5751;color:#9DB3AD;box-shadow:0 calc(var(--u)*.9) 0 #24403A;cursor:default}
.rl-btn-secondary{background:var(--hud2);color:#fff;border:calc(var(--u)*.35) solid var(--line);font-size:calc(var(--u)*3.6);min-height:calc(var(--u)*9);padding:0 calc(var(--u)*3.6)}
.rl-hint{font-size:calc(var(--u)*2.9);font-weight:800;color:var(--muted)}
.rl :focus{outline:none}
.rl button:focus{outline:calc(var(--u)*.7) solid #fff;outline-offset:calc(var(--u)*.6);transform:scale(1.05)}
.rl .rl-btn-primary:focus{box-shadow:0 calc(var(--u)*.9) 0 var(--sun-dark),0 0 calc(var(--u)*4) rgba(255,184,46,.65)}
@media (prefers-reduced-motion:reduce){.rl-slot.is-empty .rl-name::after{animation:none;content:'…'}.rl button:focus{transform:none}}
`;
