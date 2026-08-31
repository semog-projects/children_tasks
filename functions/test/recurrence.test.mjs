import assert from "node:assert/strict";
import { test } from "node:test";

import { occursOn } from "../lib/tasks/recurrence.js";

const start = new Date("2026-08-10T00:00:00Z"); // segunda-feira

test("once: só no dia de início", () => {
  const r = { type: "once", startDate: start };
  assert.equal(occursOn(r, "2026-08-10"), true);
  assert.equal(occursOn(r, "2026-08-11"), false);
  assert.equal(occursOn(r, "2026-08-09"), false);
});

test("daily: todo dia dentro da janela", () => {
  const r = { type: "daily", startDate: start, endDate: new Date("2026-08-12T00:00:00Z") };
  assert.equal(occursOn(r, "2026-08-09"), false);
  assert.equal(occursOn(r, "2026-08-10"), true);
  assert.equal(occursOn(r, "2026-08-12"), true);
  assert.equal(occursOn(r, "2026-08-13"), false);
});

test("weekly: só nos dias da semana escolhidos", () => {
  // 1=seg, 3=qua, 5=sex
  const r = { type: "weekly", daysOfWeek: [1, 3, 5], startDate: start };
  assert.equal(occursOn(r, "2026-08-10"), true); // seg
  assert.equal(occursOn(r, "2026-08-11"), false); // ter
  assert.equal(occursOn(r, "2026-08-12"), true); // qua
  assert.equal(occursOn(r, "2026-08-14"), true); // sex
  assert.equal(occursOn(r, "2026-08-16"), false); // dom
});

test("weekly sem dias configurados: nunca", () => {
  const r = { type: "weekly", daysOfWeek: [], startDate: start };
  assert.equal(occursOn(r, "2026-08-10"), false);
});
