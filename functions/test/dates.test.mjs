import assert from "node:assert/strict";
import { test } from "node:test";

import { isoWeekday, localDateStr, utcMidnight } from "../lib/shared/dates.js";

test("localDateStr respeita o fuso da família", () => {
  // 2026-08-11 02:00 UTC = 2026-08-10 23:00 em São Paulo (UTC-3)
  const instant = new Date("2026-08-11T02:00:00Z");
  assert.equal(localDateStr("America/Sao_Paulo", instant), "2026-08-10");
  assert.equal(localDateStr("UTC", instant), "2026-08-11");
});

test("utcMidnight", () => {
  assert.equal(utcMidnight("2026-08-10").toISOString(), "2026-08-10T00:00:00.000Z");
});

test("isoWeekday: 1=segunda … 7=domingo", () => {
  assert.equal(isoWeekday("2026-08-10"), 1); // segunda
  assert.equal(isoWeekday("2026-08-16"), 7); // domingo
});
