# Notification Intelligence Engine (NIE)

A cross-platform library for deterministic event resolution and notification timing calculations.

## Quick Start (1 minute)

**What it does:**  
Given a list of events and a reference time, NIE deterministically answers:
> *What is the next upcoming event, and when should I trigger a notification?*

### Swift (iOS)

```swift
import NotificationIntelligence

let events = [
    NIEvent(
        id: "shift-1",
        startTime: Date(timeIntervalSince1970: 1710518400),
        label: "Night Shift"
    )
]

let config = NIResolverConfig(
    timezone: TimeZone.current,
    triggerLeadTimeMinutes: 30
)

if let result = NIResolver.resolveUpcomingEvent(
    referenceTime: Date(),
    events: events,
    config: config
) {
    print(result.dayLabel)      // today / tomorrow / later
    print(result.triggerTime)   // when to notify
}

**Designed for production scheduling systems.** Used in real-world enterprise scheduling contexts where correctness and cross-platform consistency are critical.

---

## Problem Statement

Modern applications often need to determine the "next upcoming event" from a collection of events and calculate when to trigger a reminder notification. This seemingly simple task has subtle complexities:

- **Timezone handling**: Events and users may be in different timezones
- **Day boundary semantics**: What does "today" or "tomorrow" mean when trigger times cross midnight?
- **Lead time calculations**: Reminders should fire *before* the event, not at the event time
- **Filtering logic**: Some events may need to be excluded dynamically
- **Cross-platform consistency**: The same logic must produce identical results across Swift, Kotlin, and TypeScript

NIE provides a deterministic, well-tested solution to these problems with identical semantics across all supported platforms.

## Semantic Guarantees (Locked Contract)

### 1. Upcoming Event Selection

- Selection is determined **ONLY** by `startTime`
- The resolver selects the next event whose `startTime > referenceTime` (strictly greater)
- Events at exactly `referenceTime` are NOT considered upcoming
- If no qualifying events exist within the lookahead window (after applying skip predicate), returns `null`

### 2. Trigger Time Calculation

- Trigger time is **ALWAYS** derived from `event.startTime` only
- Formula: `triggerTime = event.startTime - config.triggerLeadTimeMinutes`
- Lead time precision is minutes

### 3. Day Label Logic

Day labels are calculated based on comparing calendar days **in the configured timezone**:

```
dayLabel = compare(startOfDay(triggerTime), startOfDay(referenceTime))

today    → triggerTime falls on same calendar day as referenceTime
tomorrow → triggerTime falls on the next calendar day
later    → triggerTime falls on any day beyond tomorrow
```

**Important**: The day label is based on the **trigger time**, not the event start time. If a 2-hour lead time causes a midnight event's trigger to fall on the previous day, the day label will reflect the trigger day.

### 4. Lookahead Window

- Default: 7 days (configurable)
- The resolver considers events where `startTime` is in the range `(referenceTime, referenceTime + lookaheadDays]`
- Events excluded via `skipPredicate(event) == true` are not considered

### 5. Forbidden Patterns

**Timeline-based day equality selection is FORBIDDEN.**

❌ Incorrect (forbidden):
```
events.first { sameDay(event.startTime, tomorrow) }
```

✅ Correct (required):
```
events
  .filter { event.startTime > referenceTime }
  .filter { event.startTime <= referenceTime + lookahead }
  .filter { !skipPredicate(event) }
  .sortedBy { event.startTime }
  .first
```

The resolver must always sort/filter by absolute time and choose the next `startTime > referenceTime`.

## What NIE Does NOT Do

NIE is intentionally focused and minimal. It does **NOT**:

| Responsibility | Owner | Notes |
|---------------|-------|-------|
| Schedule platform notifications | **Consumer App** | Use `UNUserNotificationCenter` (iOS), `AlarmManager` (Android), `Notification API` (Web) |
| Persist events or state | **Consumer App** | NIE is stateless; store events in your database |
| Provide UI components | **Consumer App** | NIE is headless; build your own UI |
| Handle recurring event expansion | **Consumer App** | Provide pre-expanded event instances |
| Manage notification permissions | **Consumer App** | Request permissions before scheduling |
| Handle event CRUD operations | **Consumer App** | NIE only reads events, never modifies them |
| Provide calendar synchronization | **Consumer App** | Sync with external calendars separately |
| Handle network operations | **Consumer App** | NIE is pure computation, no I/O |

NIE answers one question definitively: **"Given these events and this configuration, what is the next upcoming event and when should I be notified?"**

### Consumer Responsibility Summary

Your application is responsible for:

1. **Data management**: Fetching, storing, and updating events
2. **Platform integration**: Using platform-specific notification APIs
3. **Permission handling**: Requesting and managing notification permissions
4. **Scheduling**: Calling NIE when schedules change and acting on results
5. **Error handling**: Gracefully handling nil results (no upcoming events)
6. **Time synchronization**: Ensuring accurate system time

## Public API

### Core Types

#### Event
```
Event {
  id: string                    // Unique identifier
  startTime: Instant            // When the event begins (required)
  endTime: Instant?             // When the event ends (optional)
  label: string?                // Human-readable name (optional)
  metadata: Map<string, any>?   // Arbitrary key-value data (optional)
}
```

#### ResolverConfig
```
ResolverConfig {
  timezone: string              // IANA timezone ID (required, e.g., "America/New_York")
  lookaheadDays: int            // Days to look ahead (default: 7)
  triggerLeadTimeMinutes: int   // Minutes before event to trigger (default: 0)
  locale: string?               // BCP-47 locale (optional, NOT used for core semantics)
  skipPredicate: (Event) -> bool? // Filter function (optional)
}
```

#### UpcomingEventInfo
```
UpcomingEventInfo {
  event: Event                  // The selected event
  startTime: Instant            // Event start time
  endTime: Instant?             // Event end time (if present)
  triggerTime: Instant          // When to trigger notification
  dayLabel: DayLabel            // today | tomorrow | later
  formattedStartTimeISO: string // ISO 8601 formatted start time
}
```

#### DayLabel
```
enum DayLabel {
  today
  tomorrow
  later
}
```

### Core Function

```
resolveUpcomingEvent(
  referenceTime: Instant,
  events: [Event],
  config: ResolverConfig
) -> UpcomingEventInfo?
```

Returns the next upcoming event with calculated trigger time and day label, or `null` if no qualifying event exists.

## Installation

### Swift (SPM)

Add to your `Package.swift`:
```swift
dependencies: [
  .package(path: "../NotificationIntelligenceEngine/Swift")
  // Or from git:
  // .package(url: "https://github.com/your-org/notification-intelligence-engine.git", from: "1.0.0")
]
```

### Kotlin (Gradle)

```kotlin
// settings.gradle.kts
includeBuild("../NotificationIntelligenceEngine/Kotlin")

// build.gradle.kts
dependencies {
  implementation("com.nie:notification-intelligence:1.0.0")
}
```

### TypeScript (npm)

```bash
npm install notification-intelligence-engine
# or
yarn add notification-intelligence-engine
```

## Usage Examples

### Swift

```swift
import NotificationIntelligence

let events = [
  NIEvent(
    id: "meeting-1",
    startTime: Date(timeIntervalSince1970: 1710518400), // 2024-03-15T14:00:00Z
    label: "Team Standup"
  )
]

let config = NIResolverConfig(
  timezone: TimeZone(identifier: "America/New_York")!,
  triggerLeadTimeMinutes: 15
)

let referenceTime = Date() // now

if let result = NIResolver.resolveUpcomingEvent(
  referenceTime: referenceTime,
  events: events,
  config: config
) {
  print("Next event: \(result.event.label ?? result.event.id)")
  print("Trigger at: \(result.triggerTime)")
  print("Day: \(result.dayLabel)")
}
```

### Kotlin

```kotlin
import com.nie.NotificationIntelligence
import kotlinx.datetime.*

val events = listOf(
  NIEvent(
    id = "meeting-1",
    startTime = Instant.parse("2024-03-15T14:00:00Z"),
    label = "Team Standup"
  )
)

val config = NIResolverConfig(
  timezone = TimeZone.of("America/New_York"),
  triggerLeadTimeMinutes = 15
)

val referenceTime = Clock.System.now()

val result = NIResolver.resolveUpcomingEvent(
  referenceTime = referenceTime,
  events = events,
  config = config
)

result?.let {
  println("Next event: ${it.event.label ?: it.event.id}")
  println("Trigger at: ${it.triggerTime}")
  println("Day: ${it.dayLabel}")
}
```

### TypeScript

```typescript
import { resolveUpcomingEvent, NIEvent, NIResolverConfig } from 'notification-intelligence-engine';

const events: NIEvent[] = [
  {
    id: 'meeting-1',
    startTime: new Date('2024-03-15T14:00:00Z'),
    label: 'Team Standup'
  }
];

const config: NIResolverConfig = {
  timezone: 'America/New_York',
  triggerLeadTimeMinutes: 15
};

const referenceTime = new Date();

const result = resolveUpcomingEvent(referenceTime, events, config);

if (result) {
  console.log(`Next event: ${result.event.label ?? result.event.id}`);
  console.log(`Trigger at: ${result.triggerTime.toISOString()}`);
  console.log(`Day: ${result.dayLabel}`);
}
```

## Test Vectors

All implementations must pass the same test vectors defined in `test-vectors.json`. This ensures cross-platform consistency.

To run tests:

```bash
# Swift
cd Swift && swift test

# Kotlin
cd Kotlin && ./gradlew test

# TypeScript
cd TypeScript && npm test
```

## Design Principles

1. **Determinism**: Given the same inputs, all implementations produce identical outputs
2. **Timezone correctness**: All time operations respect the configured timezone
3. **Minimal surface area**: Small, focused API that does one thing well
4. **Zero dependencies** (where possible): Swift uses only Foundation; Kotlin uses only kotlinx-datetime
5. **Testability**: Comprehensive test vectors ensure correctness
6. **Pure computation**: No I/O, no side effects, no global state
7. **Synchronous API**: No async/await complexity; integrate with any concurrency model

## API Stability

See [API_STABILITY.md](./API_STABILITY.md) for detailed stability guarantees, platform support, and migration notes.

## License

MIT License - See LICENSE file for details.

This library is designed for commercial use. No attribution required, though appreciated.

## Contributing

Contributions are welcome. Please ensure:

1. All test vectors pass on all platforms
2. New features include corresponding test vectors
3. The semantic contract is not violated
4. Code follows platform idioms

## Production Usage

NIE is designed for mission-critical scheduling applications:

- **Healthcare shift scheduling**: Ensure staff receive timely shift reminders
- **Transportation logistics**: Notify drivers of upcoming routes
- **Education platforms**: Remind students of class times across timezones
- **Enterprise workforce management**: Coordinate global team schedules

The library has been validated against 25 comprehensive test vectors covering:
- Timezone edge cases (DST transitions, UTC offsets)
- Midnight boundary conditions
- Lead time calculations crossing day boundaries
- Skip predicate filtering
- Lookahead window enforcement

## Changelog

### 1.0.0
- Initial release
- Swift, Kotlin, and TypeScript implementations
- 25 cross-platform test vectors
- Swift 6 ready (no concurrency warnings)
- Pure synchronous API
