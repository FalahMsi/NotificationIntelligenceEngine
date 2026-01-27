/**
 * resolver.test.ts
 * Notification Intelligence Engine - TypeScript Tests
 *
 * Tests for the resolver using the shared test vectors.
 */

import { describe, it, expect, beforeAll } from 'vitest';
import { readFileSync } from 'fs';
import { join } from 'path';
import { resolveUpcomingEvent } from '../src/resolver';
import { NIEvent, NIResolverConfig } from '../src/types';

interface TestEvent {
  id: string;
  startTimeISO: string;
  endTimeISO?: string;
}

interface TestExpected {
  expectedEventId: string | null;
  expectedDayLabel: string | null;
  expectedTriggerTimeISO: string | null;
  expectedEndTimeISO?: string | null;
}

interface TestVector {
  id: string;
  description: string;
  timezone: string;
  referenceTimeISO: string;
  triggerLeadTimeMinutes: number;
  lookaheadDays: number;
  events: TestEvent[];
  skipEventIds: string[];
  expected: TestExpected;
}

interface TestVectorFile {
  description: string;
  version: string;
  vectors: TestVector[];
}

describe('NIResolver', () => {
  let testVectors: TestVector[];

  beforeAll(() => {
    // Load test vectors from the JSON file
    const vectorPath = join(__dirname, '../../test-vectors.json');
    const content = readFileSync(vectorPath, 'utf-8');
    const file: TestVectorFile = JSON.parse(content);
    testVectors = file.vectors;
  });

  it('should have loaded test vectors', () => {
    expect(testVectors.length).toBeGreaterThan(0);
  });

  describe('test vectors', () => {
    // Use a placeholder test that will iterate through vectors
    it('should pass all test vectors', () => {
      for (const vector of testVectors) {
        runTestVector(vector);
      }
    });
  });
});

function runTestVector(vector: TestVector): void {
  // Parse reference time
  const referenceTime = new Date(vector.referenceTimeISO);

  // Parse events
  const events: NIEvent[] = vector.events.map((testEvent) => ({
    id: testEvent.id,
    startTime: new Date(testEvent.startTimeISO),
    endTime: testEvent.endTimeISO ? new Date(testEvent.endTimeISO) : undefined,
  }));

  // Create skip predicate based on skipEventIds
  const skipSet = new Set(vector.skipEventIds);
  const skipPredicate =
    skipSet.size > 0 ? (event: NIEvent) => skipSet.has(event.id) : undefined;

  // Create config
  const config: NIResolverConfig = {
    timezone: vector.timezone,
    lookaheadDays: vector.lookaheadDays,
    triggerLeadTimeMinutes: vector.triggerLeadTimeMinutes,
    skipPredicate,
  };

  // Run resolver
  const result = resolveUpcomingEvent(referenceTime, events, config);

  // Validate result
  const { expectedEventId, expectedDayLabel, expectedTriggerTimeISO, expectedEndTimeISO } =
    vector.expected;

  if (expectedEventId !== null) {
    // Should have a result
    expect(result, `[${vector.id}] Expected event ${expectedEventId} but got null`).not.toBeNull();

    if (!result) return; // TypeScript guard

    // Check event ID
    expect(result.event.id, `[${vector.id}] Event ID mismatch`).toBe(expectedEventId);

    // Check day label
    if (expectedDayLabel !== null) {
      expect(result.dayLabel, `[${vector.id}] Day label mismatch`).toBe(expectedDayLabel);
    }

    // Check trigger time
    if (expectedTriggerTimeISO !== null) {
      const expectedTriggerTime = new Date(expectedTriggerTimeISO);
      expect(
        Math.abs(result.triggerTime.getTime() - expectedTriggerTime.getTime()),
        `[${vector.id}] Trigger time mismatch: got ${result.triggerTime.toISOString()}, expected ${expectedTriggerTimeISO}`
      ).toBeLessThan(1000); // Within 1 second
    }

    // Check end time if expected
    if (expectedEndTimeISO) {
      const expectedEndTime = new Date(expectedEndTimeISO);
      expect(result.endTime, `[${vector.id}] Expected end time but got undefined`).toBeDefined();
      if (result.endTime) {
        expect(
          Math.abs(result.endTime.getTime() - expectedEndTime.getTime()),
          `[${vector.id}] End time mismatch`
        ).toBeLessThan(1000);
      }
    }
  } else {
    // Should be null
    expect(
      result,
      `[${vector.id}] Expected null but got event ${result?.event.id ?? 'unknown'}`
    ).toBeNull();
  }
}
