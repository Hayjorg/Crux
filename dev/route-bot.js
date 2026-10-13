/* Human-like Route Read bot (dev only, not shipped). Deterministic from a seed.
   Memory model (crux-game-bot): recall error p = 0.04 per hold per 10 s since shown + 0.02 per route length step above 5,
   plus 0.015 per decoy hold touching that hold (interleave), scaled by band; attention lapse per route; fatigue grows sigma 15 %.
   Works in node (module.exports) and in tests.html (window.RouteBot). api = { routeWall, routeShowMs, routeNextLen, routeConst }. */
(function(root){
  function rng(seed){ var a = seed>>>0; return function(){ a = (a+0x6D2B79F5)>>>0; var t = a; t = Math.imul(t ^ (t>>>15), t|1); t ^= t + Math.imul(t ^ (t>>>7), t|61); return ((t ^ (t>>>14))>>>0)/4294967296; }; }
  var BANDS = {
    beginner: { mem:1.3, lapse:0.08, guess:0.15, tapMs:900 },
    average:  { mem:1.0, lapse:0.04, guess:0.2,  tapMs:700 },
    strong:   { mem:0.6, lapse:0.03, guess:0.25, tapMs:520 }
  };
  // Plays one 60 s round on the pure rules. Returns { score, longest, routes:[{n, ok}] }.
  function playRound(api, band, seed){
    var B = BANDS[band], C = api.routeConst, R = rng(seed), t = 0, N = C.start, score = 0, longest = 0, routes = [];
    while(t<C.roundMs){
      var w = api.routeWall((R()*4294967296)>>>0, N), show = api.routeShowMs(N), start = t;
      t += show;
      var lapse = R()<B.lapse, ok = true, elapsed = 0, i;
      var fatigue = 1+0.15*Math.min(1, t/C.roundMs);
      for(i=0;i<w.target.length;i++){
        elapsed += (B.tapMs*(0.75+R()*0.6))*fatigue;
        var h = w.target[i], adj = 0;
        w.decoy.forEach(function(d){ if(Math.abs(d.row-h.row)<=1 && Math.abs(d.col-h.col)<=1) adj++; });
        var age = show*0.5+elapsed;
        var p = B.mem*(0.04*age/10000 + 0.02*Math.max(0, w.n-5) + 0.015*adj);
        if(lapse) p = Math.max(p, 0.5);
        if(R()<p && R()>=B.guess){ ok = false; break; }
      }
      t += elapsed;
      if(t>C.roundMs) break;                      // the clock ran out mid-route: nothing recorded
      routes.push({ n:N, ok:ok });
      if(ok){ score += N; if(N>longest) longest = N; t += C.betweenMs; N = api.routeNextLen(N, false); }
      else { t += C.revealMs; N = api.routeNextLen(N, true); }
    }
    return { score:score, longest:longest, routes:routes };
  }
  // seeds x band -> { byN:{n:{tries, passes}}, mean, max, rounds }
  function table(api, band, seeds, base){
    var byN = {}, sum = 0, max = 0;
    for(var s=0;s<seeds;s++){
      var r = playRound(api, band, (base||1000)+s*7919);
      sum += r.score; if(r.score>max) max = r.score;
      r.routes.forEach(function(x){ var e = byN[x.n] || (byN[x.n] = { tries:0, passes:0 }); e.tries++; if(x.ok) e.passes++; });
    }
    return { byN:byN, mean:sum/seeds, max:max, rounds:seeds };
  }
  var out = { BANDS:BANDS, playRound:playRound, table:table };
  if(typeof module!=="undefined" && module.exports) module.exports = out; else root.RouteBot = out;
})(typeof window!=="undefined" ? window : this);
