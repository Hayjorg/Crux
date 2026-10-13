// node dev/route-bot-run.js [seeds]  : pulls the ROUTE-PURE block out of crux.html and prints band x route-length pass rates.
var fs = require("fs"), path = require("path");
var src = fs.readFileSync(path.join(__dirname, "..", "crux.html"), "utf8");
var m32 = src.match(/function mulberry32\(seed\)\{[^\n]*\n/)[0];
var pure = src.slice(src.indexOf("/*ROUTE-PURE-BEGIN*/"), src.indexOf("/*ROUTE-PURE-END*/"));
var api = new Function(m32+pure+"; return { routeWall:routeWall, routeShowMs:routeShowMs, routeNextLen:routeNextLen, routeCheck:routeCheck, routeWallCheck:routeWallCheck, routeConst:{ start:RR_START, min:RR_MIN, max:RR_MAX, roundMs:RR_ROUND_MS, betweenMs:RR_BETWEEN_MS, revealMs:RR_REVEAL_MS } };")();
var Bot = require("./route-bot.js"), seeds = +process.argv[2] || 400;
var bands = ["beginner", "average", "strong"], res = {}, ns = [];
bands.forEach(function(b){ res[b] = Bot.table(api, b, seeds); Object.keys(res[b].byN).forEach(function(n){ if(ns.indexOf(+n)<0) ns.push(+n); }); });
ns.sort(function(a, b){ return a-b; });
console.log("route length  " + bands.map(function(b){ return (b+"        ").slice(0, 16); }).join(""));
ns.forEach(function(n){
  console.log(("N="+n+"            ").slice(0, 14) + bands.map(function(b){ var e = res[b].byN[n]; return ((e ? Math.round(100*e.passes/e.tries)+"% ("+e.tries+")" : "-")+"                ").slice(0, 16); }).join(""));
});
console.log("\npooled (early N4-5, mid N6-7, top N8-10, peak N9-10):");
[["early", 4, 5], ["mid", 6, 7], ["top", 8, 10], ["peak", 9, 10]].forEach(function(z){
  console.log((z[0]+"            ").slice(0, 14) + bands.map(function(b){
    var tr = 0, ps = 0; for(var n=z[1];n<=z[2];n++){ var e = res[b].byN[n]; if(e){ tr += e.tries; ps += e.passes; } }
    return ((tr ? Math.round(100*ps/tr)+"% ("+tr+")" : "-")+"                ").slice(0, 16); }).join(""));
});
bands.forEach(function(b){ console.log(b+": mean score "+res[b].mean.toFixed(1)+", max "+res[b].max); });
