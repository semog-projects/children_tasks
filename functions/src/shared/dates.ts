/**
 * Utilidades de data para a geração de ocorrências (issue #10).
 *
 * Convenção: "o dia" de uma ocorrência é a data do calendário **local da
 * família**, mas armazenada como Timestamp de meia-noite **UTC** desse dia
 * (`YYYY-MM-DDT00:00:00Z`). O app exibe só a data, nunca a hora, então não
 * há ambiguidade de fuso na leitura.
 */

/** Data local (YYYY-MM-DD) num fuso IANA para o instante `now`. */
export function localDateStr(timeZone: string, now: Date = new Date()): string {
  // 'en-CA' formata como YYYY-MM-DD.
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

/** Timestamp (Date) de meia-noite UTC do dia `YYYY-MM-DD`. */
export function utcMidnight(dateStr: string): Date {
  return new Date(`${dateStr}T00:00:00.000Z`);
}

/** Dia da semana ISO (1=segunda … 7=domingo) para `YYYY-MM-DD`. */
export function isoWeekday(dateStr: string): number {
  const dow = utcMidnight(dateStr).getUTCDay(); // 0=domingo … 6=sábado
  return dow === 0 ? 7 : dow;
}

/** Compara `YYYY-MM-DD` lexicograficamente (mesma ordem cronológica). */
export function dateStrOf(d: Date): string {
  return d.toISOString().slice(0, 10);
}
