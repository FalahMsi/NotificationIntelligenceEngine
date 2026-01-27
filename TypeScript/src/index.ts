/**
 * Notification Intelligence Engine - TypeScript
 *
 * A cross-platform library for deterministic event resolution and notification timing calculations.
 *
 * @packageDocumentation
 *
 * @example
 * ```typescript
 * import { resolveUpcomingEvent, NIEvent, NIResolverConfig } from 'notification-intelligence-engine';
 *
 * const events: NIEvent[] = [
 *   {
 *     id: 'meeting-1',
 *     startTime: new Date('2024-03-15T14:00:00Z'),
 *     label: 'Team Standup'
 *   }
 * ];
 *
 * const config: NIResolverConfig = {
 *   timezone: 'America/New_York',
 *   triggerLeadTimeMinutes: 15
 * };
 *
 * const result = resolveUpcomingEvent(new Date(), events, config);
 *
 * if (result) {
 *   console.log(`Next: ${result.event.label ?? result.event.id}`);
 *   console.log(`Trigger at: ${result.triggerTime.toISOString()}`);
 *   console.log(`Day: ${result.dayLabel}`);
 * }
 * ```
 */

// Re-export all public types
export type {
  NIDayLabel,
  NIEvent,
  NIResolverConfig,
  NIUpcomingEventInfo,
} from './types';

// Re-export the main resolver function
export { resolveUpcomingEvent } from './resolver';
