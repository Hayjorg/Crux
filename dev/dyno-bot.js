// Human-like bot for Dyno (dev only, not shipped). Run: node dev/dyno-bot.js [seeds]
// Pulls the pure rules out of crux.html between DYNO-PURE-BEGIN/END so the numbers always match the shipped rules.
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "..", "crux.html"), "utf8");
const pure = src.slice(src.indexOf("/*DYNO-PURE-BEGIN*/"), src.indexOf("/*DYNO-PURE-END*/"));
const m32 = src.match(/function mulberry32\(seed\)\{[^\n]*\}/)[0];
const R = new Function(m32 + "\n" + pure + "\nreturn { dynoSpec, dynoJudge, dynoRun, dynoIdealHold, DY_ROUND_MS, dynoStep };")();

function rng(seed){ let a = seed>>>0; return () => { a = (a+0x6D2B79F5)>>>0; let t = a; t = Math.imul(t^(t>>>15), t|1); t ^= t+Math.imul(t^(t>>>7), t|61); return ((t^(t>>>14))>>>0)/4294967296; }; }
function gauss(r){ let u = 0, v = 0; while(!u) u = r(); while(!v) v = r(); return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*v); }
// bands (crux-game-bot): sigma / bias / lapse. antic = share of reaction latency (180-260 ms) the player has learned to lead,
// because the meter speed changes every hold (0.8-1.2x) so the swing can't be fully predicted.
const BANDS = {
  beginner: { sigma:140, bias:60, lapse:0.08, antic:0.0 },
  average:  { sigma:90,  bias:25, lapse:0.05, antic:0.4 },
  strong:   { sigma:50,  bias:0,  lapse:0.03, antic:0.45 },
};
function policyFor(band, seed){
  const b = BANDS[band], r = rng(seed*7919+13);
  return (spec, st, i) => {
    const prog = Math.min(1, (st.jumps*1900)/45000);          // fatigue: sigma +15% over the round
    const lat = (180+80*r())*(1-b.antic);
    const gap = Math.max(0, 250+80*gauss(r));
    if(r()<b.lapse) return { gap, hold: spec.T*r() };         // lapse: let go at a random moment
    const err = b.bias+lat+gauss(r)*b.sigma*(1+0.15*prog);
    return { gap, hold: Math.max(0, R.dynoIdealHold(spec)+err) };
  };
}
const N = +process.argv[2] || 300;
const out = {};
for(const band of Object.keys(BANDS)){
  // per-step item pass rate: hold n of the ramp, N seeds x 20 draws
  const steps = [1, 4, 8, 12, 15], items = {};
  for(const n of steps){
    let ok = 0, tot = 0;
    for(let s=1;s<=N;s++){
      const pol = policyFor(band, s*31+n);
      for(let k=0;k<20;k++){
        const spec = R.dynoSpec(s, n), p = pol(spec, { jumps:n }, k);
        ok += R.dynoJudge(spec, p.hold).kind==="latch" ? 1 : 0; tot++;
      }
    }
    items[n] = (100*ok/tot).toFixed(0)+"%";
  }
  const sc = [], falls = [], jumps = [];
  for(let s=1;s<=N;s++){ const r = R.dynoRun(s*977, policyFor(band, s)); sc.push(r.peak); falls.push(r.falls); jumps.push(r.jumps); }
  const mean = a => a.reduce((x, y) => x+y, 0)/a.length;
  out[band] = { items, mean:mean(sc).toFixed(1), max:Math.max(...sc), min:Math.min(...sc), falls:mean(falls).toFixed(1), jumps:mean(jumps).toFixed(1) };
}
// perfect and null players
const perf = [], nul = [];
for(let s=1;s<=N;s++){ perf.push(R.dynoRun(s*977, spec => R.dynoIdealHold(spec)).peak); nul.push(R.dynoRun(s*977, null).peak); }
console.log("item pass rate by hold number (ramp tops out at hold 15):");
console.log("band      " + [1, 4, 8, 12, 15].map(n => ("hold "+n).padEnd(8)).join("") + "  mean  max  falls jumps");
for(const [b, o] of Object.entries(out)) console.log(b.padEnd(10) + [1, 4, 8, 12, 15].map(n => o.items[n].padEnd(8)).join("") + "  " + o.mean.padEnd(6) + String(o.max).padEnd(5) + o.falls.padEnd(6) + o.jumps);
console.log("perfect player: mean "+(perf.reduce((a, b) => a+b, 0)/N).toFixed(1)+" min "+Math.min(...perf)+" max "+Math.max(...perf)+"; null player max "+Math.max(...nul));
