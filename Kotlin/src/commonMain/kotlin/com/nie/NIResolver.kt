/**
 * NIResolver.kt
 * Notification Intelligence Engine - Kotlin
 *
 * Core resolver implementation for determining the next upcoming event.
 */

package com.nie

import kotlinx.datetime.*
import kotlin.time.Duration.Companion.days
import kotlin.time.Duration.Companion.minutes

/**
 * The main resolver for determining the next upcoming event.
 *
 * This resolver implements the semantic contract defined in the NIE specification:
 * 1. Events are selected based on `startTime > referenceTime` (strictly greater)
 * 2. Trigger time is calculated as `startTime - triggerLeadTimeMinutes`
 * 3. Day label is based on comparing trigger time's day to reference time's day
 * 4. Events are filtered by lookahead window and skip predicate
 *
 * ## Usage
 * ```kotlin
 * val result = NIResolver.resolveUpcomingEvent(
 *     referenceTime = Clock.System.now(),
 *     events = myEvents,
 *     config = myConfig
 * )
 * ```
 */
object NIResolver {

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
     * @param referenceTime The reference point in time (typically "now")
     * @param events The collection of events to consider
     * @param config Configuration for the resolver
     * @return Information about the next upcoming event, or null if none qualifies
     */
    fun resolveUpcomingEvent(
        referenceTime: Instant,
        events: List<NIEvent>,
        config: NIResolverConfig
    ): NIUpcomingEventInfo? {

        // Calculate the lookahead window end
        val lookaheadEnd = referenceTime + config.lookaheadDays.days

        // Filter and sort events according to the semantic contract
        val eligibleEvents = events
            // 1. startTime must be strictly greater than referenceTime
            .filter { it.startTime > referenceTime }
            // 2. startTime must be within lookahead window (inclusive)
            .filter { it.startTime <= lookaheadEnd }
            // 3. Apply skip predicate if configured
            .filter { event ->
                config.skipPredicate?.invoke(event)?.not() ?: true
            }
            // 4. Sort by startTime to get chronological order
            .sortedBy { it.startTime }

        // Select the first (earliest) eligible event
        val selectedEvent = eligibleEvents.firstOrNull() ?: return null

        // Calculate trigger time: startTime - leadTime
        val triggerTime = selectedEvent.startTime - config.triggerLeadTimeMinutes.minutes

        // Calculate day label based on trigger time vs reference time
        val dayLabel = calculateDayLabel(
            triggerTime = triggerTime,
            referenceTime = referenceTime,
            timezone = config.timezone
        )

        // Format start time as ISO 8601 in the configured timezone
        val formattedStartTimeISO = formatISO8601(
            instant = selectedEvent.startTime,
            timezone = config.timezone
        )

        return NIUpcomingEventInfo(
            event = selectedEvent,
            startTime = selectedEvent.startTime,
            endTime = selectedEvent.endTime,
            triggerTime = triggerTime,
            dayLabel = dayLabel,
            formattedStartTimeISO = formattedStartTimeISO
        )
    }

    /**
     * Calculates the day label by comparing calendar days in the given timezone.
     *
     * @param triggerTime The calculated trigger time
     * @param referenceTime The reference time
     * @param timezone The timezone for day boundary calculations
     * @return The appropriate day label
     */
    private fun calculateDayLabel(
        triggerTime: Instant,
        referenceTime: Instant,
        timezone: TimeZone
    ): NIDayLabel {
        val triggerDate = triggerTime.toLocalDateTime(timezone).date
        val referenceDate = referenceTime.toLocalDateTime(timezone).date

        val dayDifference = triggerDate.toEpochDays() - referenceDate.toEpochDays()

        return when (dayDifference) {
            0 -> NIDayLabel.TODAY
            1 -> NIDayLabel.TOMORROW
            else -> NIDayLabel.LATER
        }
    }

    /**
     * Formats an instant as ISO 8601 string with timezone offset.
     *
     * @param instant The instant to format
     * @param timezone The timezone for the formatted output
     * @return ISO 8601 formatted string
     */
    private fun formatISO8601(instant: Instant, timezone: TimeZone): String {
        val localDateTime = instant.toLocalDateTime(timezone)
        val offset = timezone.offsetAt(instant)

        // Format: yyyy-MM-ddTHH:mm:ss+HH:MM or yyyy-MM-ddTHH:mm:ssZ
        val dateTime = buildString {
            append(localDateTime.year.toString().padStart(4, '0'))
            append('-')
            append(localDateTime.monthNumber.toString().padStart(2, '0'))
            append('-')
            append(localDateTime.dayOfMonth.toString().padStart(2, '0'))
            append('T')
            append(localDateTime.hour.toString().padStart(2, '0'))
            append(':')
            append(localDateTime.minute.toString().padStart(2, '0'))
            append(':')
            append(localDateTime.second.toString().padStart(2, '0'))
        }

        val totalSeconds = offset.totalSeconds
        return if (totalSeconds == 0) {
            "${dateTime}Z"
        } else {
            val sign = if (totalSeconds >= 0) '+' else '-'
            val absSeconds = kotlin.math.abs(totalSeconds)
            val hours = absSeconds / 3600
            val minutes = (absSeconds % 3600) / 60
            "$dateTime$sign${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}"
        }
    }
}
