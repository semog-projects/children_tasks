import { dateStrOf, isoWeekday } from "../shared/dates.js";

export type RecurrenceType = "once" | "daily" | "weekly";

export interface Recurrence {
  type: RecurrenceType;
  daysOfWeek?: number[]; // 1=seg … 7=dom
  startDate: Date;
  endDate?: Date | null;
}

/**
 * A recorrência gera uma ocorrência no dia `dateStr` (YYYY-MM-DD)?
 * `startDate`/`endDate` são comparados só pela parte de data.
 */
export function occursOn(recurrence: Recurrence, dateStr: string): boolean {
  const start = dateStrOf(recurrence.startDate);
  if (dateStr < start) return false;

  if (recurrence.endDate) {
    const end = dateStrOf(recurrence.endDate);
    if (dateStr > end) return false;
  }

  switch (recurrence.type) {
    case "once":
      return dateStr === start;
    case "daily":
      return true;
    case "weekly": {
      const days = recurrence.daysOfWeek ?? [];
      return days.includes(isoWeekday(dateStr));
    }
    default:
      return false;
  }
}
