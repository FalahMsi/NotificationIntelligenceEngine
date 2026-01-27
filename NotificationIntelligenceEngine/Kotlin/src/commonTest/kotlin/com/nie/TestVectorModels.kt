/**
 * TestVectorModels.kt
 * Notification Intelligence Engine - Kotlin Tests
 *
 * Models for parsing and applying test vectors.
 */

package com.nie

import kotlinx.serialization.Serializable

/**
 * Root structure for the test vectors JSON file.
 */
@Serializable
data class TestVectorFile(
    val description: String,
    val version: String,
    val vectors: List<TestVector>
)

/**
 * A single test vector defining inputs and expected outputs.
 */
@Serializable
data class TestVector(
    val id: String,
    val description: String,
    val timezone: String,
    val referenceTimeISO: String,
    val triggerLeadTimeMinutes: Int,
    val lookaheadDays: Int,
    val events: List<TestEvent>,
    val skipEventIds: List<String>,
    val expected: TestExpected
)

/**
 * An event as defined in a test vector.
 */
@Serializable
data class TestEvent(
    val id: String,
    val startTimeISO: String,
    val endTimeISO: String? = null
)

/**
 * Expected results for a test vector.
 */
@Serializable
data class TestExpected(
    val expectedEventId: String?,
    val expectedDayLabel: String?,
    val expectedTriggerTimeISO: String?,
    val expectedEndTimeISO: String? = null
)
