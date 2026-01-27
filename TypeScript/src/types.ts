/**
 * types.ts
 * Notification Intelligence Engine - TypeScript
 *
 * Core type definitions for the Notification Intelligence Engine.
 * These types form the public API contract.
 */

/**
 * Represents the relative day classification of a trigger time compared to a reference time.
 *
 * The day label is determined by comparing calendar days in the configured timezone:
 * - `today`: Trigger time falls on the same calendar day as reference time
 * - `tomorrow`: Trigger time falls on the next calendar day
 * - `later`: Trigger time falls on any day beyond tomorrow
 *
 * **Important**: The day label is based on the **trigger time**, not the event start time.
 */
export type NIDayLabel = 'today' | 'tomorrow' | 'later';

/**
 * Represents a schedulable event with a start time and optional metadata.
 *
 * Events are the primary input to the resolver. The `startTime` is the only
 * field used for chronological ordering and selection.
 */
export interface NIEvent {
  /** Unique identifier for this event */
  readonly id: string;

  /** When the event begins. This is the primary field used for selection. */
  readonly startTime: Date;

  /** When the event ends (optional) */
  readonly endTime?: Date;

  /** Human-readable label for the event (optional) */
  readonly label?: string;

  /** Arbitrary metadata associated with the event (optional) */
  readonly metadata?: Record<string, unknown>;
}

/**
 * Configuration for the upcoming event resolver.
 *
 * The resolver uses this configuration to determine:
 * - Which timezone to use for day boundary calculations
 * - How far ahead to look for events
 * - How much lead time to apply for trigger calculations
 * - Which events to skip
 */
export interface NIResolverConfig {
  /**
   * The timezone used for day boundary calculations (required).
   * Must be an IANA timezone identifier (e.g., "America/New_York").
   *
   * This timezone determines what constitutes "today", "tomorrow", and "later"
   * when calculating day labels.
   */
  readonly timezone: string;

  /**
   * Number of days to look ahead for events. Default is 7.
   *
   * Events with `startTime` beyond `referenceTime + lookaheadDays` are not considered.
   */
  readonly lookaheadDays?: number;

  /**
   * Minutes before the event start time to calculate the trigger time. Default is 0.
   *
   * Formula: `triggerTime = event.startTime - triggerLeadTimeMinutes`
   */
  readonly triggerLeadTimeMinutes?: number;

  /**
   * BCP-47 locale identifier (optional).
   *
   * **Note**: This is NOT used for core semantic calculations. It may be used
   * by consuming code for formatting purposes.
   */
  readonly locale?: string;

  /**
   * Predicate to determine if an event should be skipped (optional).
   *
   * If this returns `true` for an event, that event will not be considered
   * for selection, even if it would otherwise be the next upcoming event.
   */
  readonly skipPredicate?: (event: NIEvent) => boolean;
}

/**
 * The result of resolving the next upcoming event.
 *
 * Contains the selected event along with calculated timing information.
 */
export interface NIUpcomingEventInfo {
  /** The selected upcoming event */
  readonly event: NIEvent;

  /** The event's start time */
  readonly startTime: Date;

  /** The event's end time (if present) */
  readonly endTime: Date | undefined;

  /**
   * When the notification should be triggered.
   *
   * Calculated as: `event.startTime - config.triggerLeadTimeMinutes`
   */
  readonly triggerTime: Date;

  /**
   * The relative day classification of the trigger time.
   *
   * Based on comparing `triggerTime` to `referenceTime` in the configured timezone.
   */
  readonly dayLabel: NIDayLabel;

  /**
   * ISO 8601 formatted representation of the start time.
   *
   * This provides a deterministic string representation across platforms.
   */
  readonly formattedStartTimeISO: string;
}

/**
 * Internal resolved configuration with defaults applied.
 */
export interface NIResolvedConfig {
  readonly timezone: string;
  readonly lookaheadDays: number;
  readonly triggerLeadTimeMinutes: number;
  readonly locale: string | undefined;
  readonly skipPredicate: ((event: NIEvent) => boolean) | undefined;
}

/**
 * Applies default values to a resolver configuration.
 *
 * @param config - The user-provided configuration
 * @returns Configuration with all defaults applied
 */
export function resolveConfig(config: NIResolverConfig): NIResolvedConfig {
  return {
    timezone: config.timezone,
    lookaheadDays: config.lookaheadDays ?? 7,
    triggerLeadTimeMinutes: config.triggerLeadTimeMinutes ?? 0,
    locale: config.locale,
    skipPredicate: config.skipPredicate,
  };
}
