// Checks the web calendar logic: every category mix and budget fills 24 days with unique, allowed items,
// gift links round-trip, and layouts place each day once with day 24 on a wide door.
import { readFileSync } from "node:fs";
import vm from "node:vm";

const ctx = { window: {}, TextEncoder, TextDecoder, btoa, atob, Uint8Array, console };
vm.createContext(ctx);
for (const f of ["docs/content.js", "docs/calendar.js"]) vm.runInContext(readFileSync(f, "utf8"), ctx);
vm.runInContext(`globalThis.T={CATS,TIERS,ITEMS,BY_ID,pick,layout,encodeDays,decodeDays,b64e,b64d}`, ctx);
const T = ctx.T;
const cats = T.CATS.map(c => c[0]);
let checks = 0;
const fail = m => { console.error("FAIL", m); process.exit(1); };
for (let mask = 1; mask < 256; mask++) {
  const sel = cats.filter((_, i) => mask & (1 << i));
  for (const budget of T.TIERS) {
    const max = T.TIERS.indexOf(budget);
    for (let seed = 1; seed <= 6; seed++) {
      const days = T.pick(sel, budget, seed * 7919 + mask);
      if (days.length !== 24) fail(`${sel} ${budget} got ${days.length}`);
      if (new Set(days).size !== 24) fail(`${sel} ${budget} repeats`);
      for (const id of days) {
        const it = T.BY_ID[id];
        if (!sel.includes(it.category)) fail(`${id} outside ${sel}`);
        if (T.TIERS.indexOf(it.budget) > max) fail(`${id} over budget ${budget}`);
      }
      if (sel.length >= 3) {
        const counts = {};
        days.forEach(id => counts[T.BY_ID[id].category] = (counts[T.BY_ID[id].category] || 0) + 1);
        if (Object.keys(counts).length !== sel.length) fail(`${sel} missing a category`);
      }
      const back = T.decodeDays(T.encodeDays(days));
      if (back.join() !== days.join()) fail("encode round trip");
      checks++;
    }
  }
}
// Excluding opened items still fills the rest.
const base = T.pick(["humor"], "none", 42);
const keep = new Set(base.slice(0, 12));
const fresh = T.pick(["humor"], "none", 43, keep);
if (fresh.some(id => keep.has(id))) fail("exclude leaked");
if (fresh.length < 12) fail("exclude short");
for (let seed = 0; seed < 2000; seed++) {
  const s = T.layout(seed * 104729);
  const ds = s.map(x => x.day).sort((a, b) => a - b);
  if (ds.join() !== [...Array(24)].map((_, i) => i + 1).join()) fail(`layout days ${seed}`);
  const cells = s.reduce((a, x) => a + x.w, 0);
  if (cells !== 28) fail("layout cells");
  if (s.find(x => x.day === 24).w !== 2) fail("day 24 not wide");
}
const name = "Zoë & 祖母";
if (T.b64d(T.b64e(name)) !== name) fail("utf8 link text");
console.log(`PASS ${checks} calendars, 2000 layouts`);
