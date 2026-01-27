/**
 * NITypes.kt
 * Notification Intelligence Engine - Kotlin
 *
 * Core type definitions for the Notification Intelligence Engine.
 * These types form the public API contract.
 */

package com.nie

import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone

/**
 * Represents the relative day classification of a trigger time compared to a reference time.
 *
 * The day label is determined by comparing calendar days in the configured timezone:
 * - [TODAY]: Trigger time falls on the same calendar day as reference time
 * - [TOMORROW]: Trigger time falls on the next calendar day
 * - [LATER]: Trigger time falls on any day beyond tomorrow
 *
 * **Important**: The day label is based on the **trigger time**, not the event start time.
 */
enum class NIDayLabel(val value: String) {
    TODAY("today"),
    TOMORROW("tomorrow"),
    LATER("later");

    companion object {
        fun fromValue(value: String): NIDayLabel = when (value) {
            "today" -> TODAY
            "tomorrow" -> TOMORROW
            "later" -> LATER
            else -> throw IllegalArgumentException("Unknown day label: $value")
        }
    }
}

/**
 * Represents a schedulable event with a start time and optional metadata.
 *
 * Events are the primary input to the resolver. The [startTime] is the only
 * field used for chronological ordering and selection.
 *
 * @property id Unique identifier for this event
 * @property startTime When the event begins. This is the primary field used for selection.
 * @property endTime When the event ends (optional)
 * @property label Human-readable label for the event (optional)
 * @property metadata Arbitrary metadata associated with the event (optional)
 */
data class NIEvent(
    val id: String,
    val startTime: Instant,
    val endTime: Instant? = null,
    val label: String? = null,
    val metadata: Map<String, Any?>? = null
)

/**
 * Configuration for the upcoming event resolver.
 *
 * The resolver uses this configuration to determine:
 * - Which timezone to use for day boundary calculations
 * - How far ahead to look for events
 * - How much lead time to apply for trigger calculations
 * - Which events to skip
 *
 * @property timezone The timezone used for day boundary calculations (required).
 *                    This timezone determines what constitutes "today", "tomorrow", and "later"
 *                    when calculating day labels.
 * @property lookaheadDays Number of days to look ahead for events. Default is 7.
 *                         Events with startTime beyond referenceTime + lookaheadDays are not considered.
 * @property triggerLeadTimeMinutes Minutes before the event start time to calculate the trigger time.
 *                                   Default is 0. Formula: triggerTime = event.startTime - triggerLeadTimeMinutes
 * @property locale BCP-47 locale identifier (optional). NOT used for core semantic calculations.
 *                  May be used by consuming code for formatting purposes.
 * @property skipPredicate Predicate to determine if an event should be skipped (optional).
 *                         If this returns true for an event, that event will not be considered
 *                         for selection, even if it would otherwise be the next upcoming event.
 */
data class NIResolverConfig(
    val timezone: TimeZone,
    val lookaheadDays: Int = 7,
    val triggerLeadTimeMinutes: Int = 0,
    val locale: String? = null,
    val skipPredicate: ((NIEvent) -> Boolean)? = null
)

/**
 * The result of resolving the next upcoming event.
 *
 * Contains the selected event along with calculated timing information.
 *
 * @property event The selected upcoming event
 * @property startTime The event's start time
 * @property endTime The event's end time (if present)
 * @property triggerTime When the notification should be triggered.
 *                       Calculated as: event.startTime - config.triggerLeadTimeMinutes
 * @property dayLabel The relative day classification of the trigger time.
 *                    Based on comparing triggerTime to referenceTime in the configured timezone.
 * @property formattedStartTimeISO ISO 8601 formatted representation of the start time.
 *                                  This provides a deterministic string representation across platforms.
 */
data class NIUpcomingEventInfo(
    val event: NIEvent,
    val startTime: Instant,
    val endTime: Instant?,
    val triggerTime: Instant,
    val dayLabel: NIDayLabel,
    val formattedStartTimeISO: String
)
