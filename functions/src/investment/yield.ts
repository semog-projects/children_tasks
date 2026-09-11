/**
 * Matemática da poupança (issue #73). Porte fiel de
 * `lib/src/features/investment/domain/investment_math.dart` — manter em sincronia.
 */

/** Fração do rendimento paga quando resgatado antes da carência. */
export const EARLY_YIELD_FACTOR = 0.5;

const WEEK_SECONDS = 7 * 24 * 3600;

export interface Lot {
  points: number;
  /** ms desde a época (Date.getTime()). */
  since: number;
}

/** Semanas fracionárias entre dois instantes (ms). Negativo vira 0. */
export function weeksBetween(fromMs: number, toMs: number): number {
  const secs = (toMs - fromMs) / 1000;
  return secs <= 0 ? 0 : secs / WEEK_SECONDS;
}

/** Rendimento bruto de um aporte (juros compostos por semana). */
export function grossYield(
  principal: number,
  weeks: number,
  weeklyRatePct: number,
): number {
  if (principal <= 0 || weeks <= 0 || weeklyRatePct <= 0) return 0;
  const r = weeklyRatePct / 100;
  const value = principal * Math.pow(1 + r, weeks);
  return Math.round(value - principal);
}

/** Rendimento líquido: metade se resgatado antes de [graceDays] dias. */
export function netYield(
  principal: number,
  sinceMs: number,
  nowMs: number,
  weeklyRatePct: number,
  graceDays: number,
): number {
  const gross = grossYield(
    principal,
    weeksBetween(sinceMs, nowMs),
    weeklyRatePct,
  );
  const pastGrace = nowMs >= sinceMs + graceDays * 24 * 3600 * 1000;
  return pastGrace ? gross : Math.round(gross * EARLY_YIELD_FACTOR);
}

/** Quanto a criança recebe ao resgatar a posição inteira agora. */
export function payoutNow(
  lots: Lot[],
  nowMs: number,
  weeklyRatePct: number,
  graceDays: number,
): { payout: number; principal: number; yield: number } {
  let principal = 0;
  let yieldTotal = 0;
  for (const lot of lots) {
    principal += lot.points;
    yieldTotal += netYield(
      lot.points,
      lot.since,
      nowMs,
      weeklyRatePct,
      graceDays,
    );
  }
  return { payout: principal + yieldTotal, principal, yield: yieldTotal };
}
