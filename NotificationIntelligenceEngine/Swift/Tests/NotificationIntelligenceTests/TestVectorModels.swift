// TestVectorModels.swift
// Notification Intelligence Engine - Swift Tests
//
// Models for parsing and applying test vectors.

import Foundation

/// Root structure for the test vectors JSON file.
struct TestVectorFile: Codable {
    let description: String
    let version: String
    let vectors: [TestVector]

    enum CodingKeys: String, CodingKey {
        case description = "description"
        case version = "version"
        case vectors = "vectors"
    }
}

/// A single test vector defining inputs and expected outputs.
struct TestVector: Codable {
    let id: String
    let description: String
    let timezone: String
    let referenceTimeISO: String
    let triggerLeadTimeMinutes: Int
    let lookaheadDays: Int
    let events: [TestEvent]
    let skipEventIds: [String]
    let expected: TestExpected
}

/// An event as defined in a test vector.
struct TestEvent: Codable {
    let id: String
    let startTimeISO: String
    let endTimeISO: String?
}

/// Expected results for a test vector.
struct TestExpected: Codable {
    let expectedEventId: String?
    let expectedDayLabel: String?
    let expectedTriggerTimeISO: String?
    let expectedEndTimeISO: String?
}
