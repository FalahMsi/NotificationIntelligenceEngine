/**
 * resolver.ts
 * Notification Intelligence Engine - TypeScript
 *
 * Core resolver implementation for determining the next upcoming event.
 */

import {
  NIEvent,
  NIResolverConfig,
  NIUpcomingEventInfo,
  NIDayLabel,
  resolveConfig,
} from './types';

/**
 * Resolves the next upcoming event from a collection of events.
 *
 * This function implements the NIE semantic contract:
 * 1. Filters events to those with `startTime > referenceTime`
 * 2. Filters events within the lookahead window
 * 3. Applies the skip predicate (if configured)
 * 4. Selects the event with the earliest `startTime`
 * 5. Calculates trigger time and day label
 *
 * @param referenceTime - The reference point in time (typically "now")
 * @param events - The collection of events to consider
 * @param config - Configuration for the resolver
 * @returns Information about the next upcoming event, or null if none qualifies
 *
 * @example
 * ```typescript
 * const result = resolveUpcomingEvent(
 *   new Date(),
 *   myEvents,
 *   { timezone: 'America/New_York', triggerLeadTimeMinutes: 15 }
 * );
 * ```
 */
export function resolveUpcomingEvent(
  referenceTime: Date,
  events: readonly NIEvent[],
  config: NIResolverConfig
): NIUpcomingEventInfo | null {
  const resolvedConfig = resolveConfig(config);

  // Calculate the lookahead window end
  const lookaheadMs = resolvedConfig.lookaheadDays * 24 * 60 * 60 * 1000;
  const lookaheadEnd = new Date(referenceTime.getTime() + lookaheadMs);

  // Filter and sort events according to the semantic contract
  const eligibleEvents = events
    // 1. startTime must be strictly greater than referenceTime
    .filter((event) => event.startTime.getTime() > referenceTime.getTime())
    // 2. startTime must be within lookahead window (inclusive)
    .filter((event) => event.startTime.getTime() <= lookaheadEnd.getTime())
    // 3. Apply skip predicate if configured
    .filter((event) => {
      if (resolvedConfig.skipPredicate) {
        return !resolvedConfig.skipPredicate(event);
      }
      return true;
    })
    // 4. Sort by startTime to get chronological order
    .sort((a, b) => a.startTime.getTime() - b.startTime.getTime());

  // Select the first (earliest) eligible event
  const selectedEvent = eligibleEvents[0];
  if (!selectedEvent) {
    return null;
  }

  // Calculate trigger time: startTime - leadTime
  const triggerTimeMs =
    selectedEvent.startTime.getTime() -
    resolvedConfig.triggerLeadTimeMinutes * 60 * 1000;
  const triggerTime = new Date(triggerTimeMs);

  // Calculate day label based on trigger time vs reference time
  const dayLabel = calculateDayLabel(
    triggerTime,
    referenceTime,
    resolvedConfig.timezone
  );

  // Format start time as ISO 8601 in the configured timezone
  const formattedStartTimeISO = formatISO8601(
    selectedEvent.startTime,
    resolvedConfig.timezone
  );

  return {
    event: selectedEvent,
    startTime: selectedEvent.startTime,
    endTime: selectedEvent.endTime,
    triggerTime,
    dayLabel,
    formattedStartTimeISO,
  };
}

/**
 * Calculates the day label by comparing calendar days in the given timezone.
 *
 * @param triggerTime - The calculated trigger time
 * @param referenceTime - The reference time
 * @param timezone - IANA timezone identifier for day boundary calculations
 * @returns The appropriate day label
 */
function calculateDayLabel(
  triggerTime: Date,
  referenceTime: Date,
  timezone: string
): NIDayLabel {
  const triggerDay = getStartOfDayInTimezone(triggerTime, timezone);
  const referenceDay = getStartOfDayInTimezone(referenceTime, timezone);

  // Calculate difference in days (using milliseconds)
  const msPerDay = 24 * 60 * 60 * 1000;
  const dayDifference = Math.round(
    (triggerDay.getTime() - referenceDay.getTime()) / msPerDay
  );

  switch (dayDifference) {
    case 0:
      return 'today';
    case 1:
      return 'tomorrow';
    default:
      return 'later';
  }
}

/**
 * Gets the start of day (midnight) for a date in a specific timezone.
 *
 * @param date - The date to get the start of day for
 * @param timezone - IANA timezone identifier
 * @returns A Date object representing midnight in the specified timezone
 */
function getStartOfDayInTimezone(date: Date, timezone: string): Date {
  // Get the date components in the target timezone
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });

  const parts = formatter.formatToParts(date);
  const year = parseInt(
    parts.find((p) => p.type === 'year')?.value ?? '0',
    10
  );
  const month = parseInt(
    parts.find((p) => p.type === 'month')?.value ?? '0',
    10
  );
  const day = parseInt(parts.find((p) => p.type === 'day')?.value ?? '0', 10);

  // Create a date string for midnight in the target timezone
  // and parse it to get the UTC equivalent
  const dateStr = `${year}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}T00:00:00`;

  // Get the offset for midnight on this day in the target timezone
  const tempDate = new Date(dateStr + 'Z');
  const offsetFormatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hour: 'numeric',
    hour12: false,
    timeZoneName: 'shortOffset',
  });

  // Parse offset from the formatted string (e.g., "12 GMT-4" -> -4)
  const offsetMatch = offsetFormatter
    .format(tempDate)
    .match(/GMT([+-]?\d+(?::\d+)?)/);
  let offsetMinutes = 0;

  if (offsetMatch && offsetMatch[1]) {
    const offsetStr = offsetMatch[1];
    if (offsetStr.includes(':')) {
      const parts = offsetStr.split(':');
      const hours = parseInt(parts[0] ?? '0', 10);
      const mins = parseInt(parts[1] ?? '0', 10);
      offsetMinutes = hours * 60 + (hours < 0 ? -mins : mins);
    } else {
      offsetMinutes = parseInt(offsetStr, 10) * 60;
    }
  }

  // Return midnight in UTC adjusted for the timezone offset
  return new Date(Date.UTC(year, month - 1, day, 0, 0, 0) - offsetMinutes * 60 * 1000);
}

/**
 * Formats a date as ISO 8601 string with timezone offset.
 *
 * @param date - The date to format
 * @param timezone - IANA timezone identifier
 * @returns ISO 8601 formatted string
 */
function formatISO8601(date: Date, timezone: string): string {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
    timeZoneName: 'shortOffset',
  });

  const parts = formatter.formatToParts(date);

  const year = parts.find((p) => p.type === 'year')?.value ?? '0000';
  const month = parts.find((p) => p.type === 'month')?.value ?? '01';
  const day = parts.find((p) => p.type === 'day')?.value ?? '01';
  const hour = parts.find((p) => p.type === 'hour')?.value ?? '00';
  const minute = parts.find((p) => p.type === 'minute')?.value ?? '00';
  const second = parts.find((p) => p.type === 'second')?.value ?? '00';
  const timeZoneName = parts.find((p) => p.type === 'timeZoneName')?.value ?? '';

  // Parse offset from timeZoneName (e.g., "GMT-4" or "GMT+5:30")
  const offsetMatch = timeZoneName.match(/GMT([+-]?)(\d+)(?::(\d+))?/);

  let offsetStr: string;
  if (!offsetMatch) {
    offsetStr = 'Z';
  } else {
    const sign = offsetMatch[1] || '+';
    const hours = (offsetMatch[2] ?? '00').padStart(2, '0');
    const minutes = (offsetMatch[3] ?? '0').padStart(2, '0');

    if (hours === '00' && minutes === '00') {
      offsetStr = 'Z';
    } else {
      offsetStr = `${sign}${hours}:${minutes}`;
    }
  }

  // Handle hour "24" as "00" of next day (some formatters do this)
  const normalizedHour = hour === '24' ? '00' : hour;

  return `${year}-${month}-${day}T${normalizedHour}:${minute}:${second}${offsetStr}`;
}
