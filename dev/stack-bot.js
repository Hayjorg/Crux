// Summit Stack human-like bot (not shipped). node dev/stack-bot.js [seeds]
// Plays the PURE rules from crux.html (between /*STACK-PURE-BEGIN*/ and /*STACK-PURE-END*/) with a noisy timing model.
// Bands (crux-game-bot): beginner sigma 140 ms bias +60 lapse 8 %, average 90/+25/5 %, strong 50/0/3 %; sigma grows 15 % over 45 s.
var fs = require("fs"), path = require("path");
var src = fs.readFileSync(path.join(__dirname, "..", "crux.html"), "utf8");
var a = src.indexOf("/*STACK-PURE-BEGIN*/"), b = src.indexOf("/*STACK-PURE-END*/");
if(a<0 || b<0) throw new Error("pure markers missing");
var R = new Function(src.slice(a, b)+";return {stackCross:stackCross,stackDrop:stackDrop,stackPos:stackPos,C:{base:SS_BASE,floor:SS_FLOOR,summit:SS_SUMMIT}};")();
function mulberry32(a){ return function(){ a |= 0; a = a + 0x6D2B79F5 | 0; var t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function gauss(r){ var u = 1-r(), v = r(); return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*v); }
var BANDS = { beginner:{sigma:140,bias:60,lapse:0.08}, average:{sigma:90,bias:25,lapse:0.05}, strong:{sigma:50,bias:0,lapse:0.03} };
var ROUND = 45000, DROP = 170, FALL = 380, ENTER = 140, CENTER = 180;
function play(band, seed){
  var B = BANDS[band], r = mulberry32(seed*2654435761>>>0), t = 0;
  var tiers = [], n = 0, topC = CENTER, topW = R.C.base, score = 0, peak = 0, peakN = 0, perfects = 0, summit = false, taps = 0;
  var steps = []; // per drop {n, miss, perfect, clean, width}
  var side = r()<0.5 ? -1 : 1;
  while(t < ROUND){
    var cross = R.stackCross(n+1); side = -side; var ph = r()*0.5, t0 = t;
    // ideal: first moment (after the block is visible) the centre is on the tower centre
    var ideal = t0+ENTER, lim = t0+4*cross;
    for(var x=ideal; x<lim; x+=2){ if(Math.abs(CENTER+R.stackPos(x-t0, cross, ph, side)-topC) < 1.5){ ideal = x; break; } }
    var fat = 1+0.15*Math.min(1, t/ROUND), tap;
    if(r() < B.lapse) tap = t0 + ENTER + r()*2*cross;                  // attention lapse: taps at some arbitrary moment
    else tap = ideal + B.bias + gauss(r)*B.sigma*fat;
    tap = Math.max(t0+ENTER, tap);
    if(tap >= ROUND) break;
    taps++;
    var cx = CENTER+R.stackPos(tap-t0, cross, ph, side), res = R.stackDrop(n+1, topW, cx-topC);
    steps.push({ n:n+1, miss:res.miss, perfect:res.perfect, clean:!res.miss && Math.abs(cx-topC) <= topW*0.15, width:topW });
    if(res.miss){
      if(n>0){ var tr = tiers.pop(); n--; score -= tr.pts; var p = tiers[tiers.length-1]; topC = p?p.c:CENTER; topW = p?p.w:R.C.base; }
      t = tap+DROP+FALL;
    } else {
      var pts = res.perfect ? 2 : 1; tiers.push({c:topC+res.shift, w:res.width, pts:pts});
      topC += res.shift; topW = res.width; n++; score += pts; if(res.perfect) perfects++;
      peak = Math.max(peak, score); peakN = Math.max(peakN, n); if(n>=R.C.summit) summit = true;
      t = tap+DROP;
    }
  }
  return { steps:steps, peak:peak, peakN:peakN, perfects:perfects, summit:summit, taps:taps };
}
var seeds = +process.argv[2] || 500;
var bandsOf = [["blocks 1-6",1,6],["blocks 7-14",7,14],["blocks 15-21",15,21],["blocks 22+ (top speed)",22,999]];
var out = { seeds:seeds };
console.log("Summit Stack bot, "+seeds+" seeds per band. keep = drop not toppled; clean = keep and within 15 % of width off-centre; perfect = <= 6 px");
console.log("band      | step                  | drops | keep % | clean % | perfect %");
Object.keys(BANDS).forEach(function(band){
  var rounds = []; for(var s=1;s<=seeds;s++) rounds.push(play(band, s));
  bandsOf.forEach(function(st){
    var d = 0, k = 0, c = 0, p = 0;
    rounds.forEach(function(rd){ rd.steps.forEach(function(x){ if(x.n>=st[1] && x.n<=st[2]){ d++; if(!x.miss) k++; if(x.clean) c++; if(x.perfect) p++; } }); });
    console.log(band.padEnd(9)+" | "+st[0].padEnd(21)+" | "+String(d).padStart(5)+" | "+(d?(100*k/d).toFixed(1):"-").padStart(6)+" | "+(d?(100*c/d).toFixed(1):"-").padStart(7)+" | "+(d?(100*p/d).toFixed(1):"-").padStart(8));
  });
  var tot = 0, mis = 0, rs = 0; rounds.forEach(function(rd){ rd.steps.forEach(function(x){ tot++; if(x.miss) mis++; }); rs += rd.peak; });
  var peaks = rounds.map(function(x){ return x.peak; }).sort(function(a,b){ return a-b; });
  console.log("  -> "+band+": keep "+(100*(1-mis/tot)).toFixed(1)+"%, misses/round "+(mis/seeds).toFixed(2)+", mean peak "+(rs/seeds).toFixed(1)+", median "+peaks[peaks.length>>1]+", max "+peaks[peaks.length-1]+
    ", reach summit "+(100*rounds.filter(function(x){ return x.summit; }).length/seeds).toFixed(1)+"%, rounds with a miss "+(100*rounds.filter(function(x){ return x.steps.some(function(y){ return y.miss; }); }).length/seeds).toFixed(1)+"%");
});
