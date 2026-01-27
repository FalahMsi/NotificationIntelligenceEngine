/**
 * NIResolverTest.kt
 * Notification Intelligence Engine - Kotlin Tests
 *
 * Tests for the NIResolver using the shared test vectors.
 */

package com.nie

import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class NIResolverTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun loadTestVectors(): List<TestVector> {
        // In JVM tests, load from resources
        val resourceStream = this::class.java.classLoader
            ?.getResourceAsStream("test-vectors.json")
            ?: throw IllegalStateException("Could not find test-vectors.json")

        val content = resourceStream.bufferedReader().use { it.readText() }
        val file = json.decodeFromString<TestVectorFile>(content)
        return file.vectors
    }

    @Test
    fun testAllVectors() {
        val vectors = loadTestVectors()
        assert(vectors.isNotEmpty()) { "No test vectors loaded" }

        for (vector in vectors) {
            runTestVector(vector)
        }
    }

    private fun runTestVector(vector: TestVector) {
        // Parse reference time
        val referenceTime = Instant.parse(vector.referenceTimeISO)

        // Parse events
        val events = vector.events.map { testEvent ->
            NIEvent(
                id = testEvent.id,
                startTime = Instant.parse(testEvent.startTimeISO),
                endTime = testEvent.endTimeISO?.let { Instant.parse(it) }
            )
        }

        // Get timezone
        val timezone = TimeZone.of(vector.timezone)

        // Create skip predicate based on skipEventIds
        val skipSet = vector.skipEventIds.toSet()
        val skipPredicate: ((NIEvent) -> Boolean)? = if (skipSet.isEmpty()) null else { event ->
            event.id in skipSet
        }

        // Create config
        val config = NIResolverConfig(
            timezone = timezone,
            lookaheadDays = vector.lookaheadDays,
            triggerLeadTimeMinutes = vector.triggerLeadTimeMinutes,
            skipPredicate = skipPredicate
        )

        // Run resolver
        val result = NIResolver.resolveUpcomingEvent(
            referenceTime = referenceTime,
            events = events,
            config = config
        )

        // Validate result
        val expectedEventId = vector.expected.expectedEventId
        if (expectedEventId != null) {
            // Should have a result
            assertNotNull(result, "[${vector.id}] Expected event $expectedEventId but got null")

            // Check event ID
            assertEquals(
                expectedEventId,
                result.event.id,
                "[${vector.id}] Event ID mismatch"
            )

            // Check day label
            vector.expected.expectedDayLabel?.let { expectedDayLabel ->
                assertEquals(
                    expectedDayLabel,
                    result.dayLabel.value,
                    "[${vector.id}] Day label mismatch"
                )
            }

            // Check trigger time
            vector.expected.expectedTriggerTimeISO?.let { expectedTriggerTimeISO ->
                val expectedTriggerTime = Instant.parse(expectedTriggerTimeISO)
                assertEquals(
                    expectedTriggerTime.epochSeconds,
                    result.triggerTime.epochSeconds,
                    "[${vector.id}] Trigger time mismatch"
                )
            }

            // Check end time if expected
            vector.expected.expectedEndTimeISO?.let { expectedEndTimeISO ->
                val expectedEndTime = Instant.parse(expectedEndTimeISO)
                assertNotNull(result.endTime, "[${vector.id}] Expected end time but got null")
                assertEquals(
                    expectedEndTime.epochSeconds,
                    result.endTime!!.epochSeconds,
                    "[${vector.id}] End time mismatch"
                )
            }
        } else {
            // Should be null
            assertNull(result, "[${vector.id}] Expected null but got event ${result?.event?.id ?: "unknown"}")
        }
    }
}
