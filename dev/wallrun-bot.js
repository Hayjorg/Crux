// Wall Run human-like bot (crux-game-bot). Runs the PURE rules only, extracted from crux.html. Deterministic: seeded.
// Usage: node dev/wallrun-bot.js [seeds=300]
const fs = require("fs"), path = require("path");
const src = fs.readFileSync(path.join(__dirname, "..", "crux.html"), "utf8");
const m32 = src.match(/function mulberry32\(seed\)\{[^\n]*\n/)[0];
const consts = src.match(/var WR_ROUND_MS[^\n]*\n/)[0];
const pure = src.split("/*WALLRUN-PURE-BEGIN*/")[1].split("/*WALLRUN-PURE-END*/")[0];
const R = new Function(m32 + consts + pure + "return {wallPhase,wallNotes,wallRound,wallHalf,wallLook,WR_ROUND_MS,WR_FLOOR};")();
const N = Number(process.argv[2]) || 300;
function gauss(rnd){ let u = 0, v = 0; while(u===0) u = rnd(); while(v===0) v = rnd(); return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*v); }
const BANDS = {
  beginner: { sigma:140, bias:60, lapse:0.08, px:10 },
  average:  { sigma:90,  bias:25, lapse:0.05, px:8 },
  strong:   { sigma:50,  bias:0,  lapse:0.03, px:6 }
};
// stress: optional extra assumption (not in the skill): timing noise grows with tempo and lane distance (thumb travel)
function play(notes, band, rnd, stress){
  const taps = []; let prev = -1e9, prevLane = 1;
  for(const n of notes){
    if(n.due>=R.WR_ROUND_MS) break;
    if(rnd()<band.lapse) continue;
    const u = n.due/R.WR_ROUND_MS, d = Math.abs(n.lane-prevLane);
    let sg = band.sigma*(1+0.15*u);
    if(stress) sg *= 1+stress*R.wallPhase(n.due).u*(d>0 ? 0.5+0.5*d : 0.25);
    let t = n.due+band.bias+gauss(rnd)*sg;
    // motor floor: a thumb cannot tap faster than 110 ms + 55 ms per lane crossed; cue must have been visible 220 ms (latency) + travel
    t = Math.max(t, prev+110+55*d, n.due-R.wallLook(n)+220+55*d);
    // spatial: lane is ~106 px wide; error N(0, px) crosses into a neighbour beyond 53 px
    let lane = n.lane, x = gauss(rnd)*band.px;
    if(x>53) lane = Math.min(2, lane+1); else if(x<-53) lane = Math.max(0, lane-1);
    taps.push({ t:Math.round(t), lane }); prev = t; prevLane = n.lane;
  }
  return taps;
}
function seedFor(i){ return (i*2654435761)>>>0; }
function run(label, bandName, stress){
  const band = BANDS[bandName], steps = [0,0,0,0], tot = [0,0,0,0];
  let score = 0, max = 0, perfect = 0, slips = 0, scores = [];
  for(let i=1;i<=N;i++){
    const sd = seedFor(i), notes = R.wallNotes(sd), rnd = (function(){ let a = sd^0xB07; return function(){ a = (a+0x6D2B79F5)>>>0; let t = a; t = Math.imul(t^(t>>>15), t|1); t ^= t+Math.imul(t^(t>>>7), t|61); return ((t^(t>>>14))>>>0)/4294967296; }; })();
    const taps = play(notes, band, rnd, stress), st = R.wallRound(notes, taps);
    const live = notes.filter(n => n.due<R.WR_ROUND_MS);
    live.forEach(n => { const q = Math.min(3, Math.floor(n.due/(R.WR_ROUND_MS/4))); tot[q]++; if(st.done[n.i]===1) steps[q]++; });
    score += st.peak; max = Math.max(max, st.peak); slips += st.slips; if(st.slips===0) perfect++; scores.push(st.peak);
  }
  scores.sort((a,b)=>a-b);
  const pr = steps.map((s,q) => (100*s/tot[q]).toFixed(0)+"%");
  const all = (100*steps.reduce((a,b)=>a+b,0)/tot.reduce((a,b)=>a+b,0)).toFixed(0)+"%";
  console.log(label.padEnd(22), pr.join("  ").padEnd(24), all.padStart(5), String((score/N).toFixed(1)).padStart(7), String(scores[Math.floor(N*0.1)]).padStart(5), String(scores[Math.floor(N*0.9)]).padStart(5), String(max).padStart(5), (slips/N).toFixed(1).padStart(7), (100*perfect/N).toFixed(0).padStart(5)+"%");
}
const notesAll = []; for(let i=1;i<=N;i++) notesAll.push(R.wallNotes(seedFor(i)).filter(n=>n.due<R.WR_ROUND_MS).length);
console.log("seeds", N, "| holds per round: mean", (notesAll.reduce((a,b)=>a+b,0)/N).toFixed(1), "min", Math.min(...notesAll), "max", Math.max(...notesAll));
console.log("pass rate by quarter of the 45 s round (Q4 = hardest, 33.75-45 s)");
console.log("band".padEnd(22), "Q1   Q2   Q3   Q4".padEnd(24), "all".padStart(5), "mean".padStart(7), "p10".padStart(5), "p90".padStart(5), "max".padStart(5), "slips".padStart(7), "clean".padStart(6));
for(const b of ["beginner","average","strong"]) run(b, b, 0);
for(const b of ["beginner","average","strong"]) run(b+" +tempo stress", b, 1);
// null bot and spam bot
(function(){
  let nullMax = 0, spam = 0, spamMax = 0;
  for(let i=1;i<=N;i++){
    const notes = R.wallNotes(seedFor(i)); nullMax = Math.max(nullMax, R.wallRound(notes, []).peak);
    const taps = []; for(let t=0, k=0;t<R.WR_ROUND_MS;t+=150, k++) taps.push({ t, lane:k%3 });
    const p = R.wallRound(notes, taps).peak; spam += p; spamMax = Math.max(spamMax, p);
  }
  console.log("null bot (no taps): max score", nullMax, "| spam bot (cycles lanes at 6.7 Hz): mean", (spam/N).toFixed(1), "max", spamMax);
})();
