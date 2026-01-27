# API Stability Guarantees

## Version: 1.0.0

This document defines the stability guarantees for the Notification Intelligence Engine (NIE) public API.

---

## Stability Classification

### Stable (Will Not Change)

The following API elements are **locked** and will not change without a major version bump:

#### Core Types

| Type | Stability | Notes |
|------|-----------|-------|
| `NIEvent` | **Stable** | All fields frozen |
| `NIResolverConfig` | **Stable** | All fields frozen, defaults frozen |
| `NIUpcomingEventInfo` | **Stable** | All fields frozen |
| `NIDayLabel` | **Stable** | Enum cases frozen (`today`, `tomorrow`, `later`) |

#### Core Function

```
resolveUpcomingEvent(referenceTime, events, config) -> UpcomingEventInfo?
```

- **Signature**: Stable
- **Semantics**: Stable (see Semantic Contract below)
- **Return type**: Stable (nullable/optional result)

---

## Concurrency Model

### Synchronous API

NIE provides a **purely synchronous API**:

- No `async/await`
- No `Actor` isolation
- No `@MainActor` requirements
- No background threading

### Thread Safety

The resolver function is **pure and stateless**:

- ✅ Safe to call from any thread
- ✅ Safe to call concurrently
- ✅ No internal mutable state
- ✅ No global state dependencies

### Swift Concurrency Notes

As of v1.0.0:

- `NIDayLabel` conforms to `Sendable` (enum with raw values)
- `NIEvent`, `NIResolverConfig`, `NIUpcomingEventInfo` do **not** conform to `Sendable`
- This is intentional to avoid Swift 6 compatibility issues with `AnyCodable` metadata
- The resolver remains safe for concurrent use due to its pure, stateless design

---

## Semantic Contract (Locked)

The following semantics are **permanently locked** and will never change:

### 1. Event Selection

```
Selected event = first event where startTime > referenceTime
                 AND startTime <= referenceTime + lookaheadDays
                 AND skipPredicate(event) != true
                 ordered by startTime ascending
```

### 2. Trigger Time Calculation

```
triggerTime = event.startTime - triggerLeadTimeMinutes
```

### 3. Day Label Derivation

```
dayLabel = compare(startOfDay(triggerTime, timezone), startOfDay(referenceTime, timezone))

  0 days difference → today
  1 day difference  → tomorrow
  >1 days difference → later
```

### 4. Determinism Guarantee

Given identical inputs, the resolver will **always** produce identical outputs across:

- All supported platforms (Swift, Kotlin, TypeScript)
- All supported OS versions
- All timezones
- All locales

---

## Platform Support

### Swift

| Platform | Minimum Version | Status |
|----------|-----------------|--------|
| macOS | 12.0+ | ✅ Supported |
| iOS | 15.0+ | ✅ Supported |
| tvOS | 15.0+ | ✅ Supported |
| watchOS | 8.0+ | ✅ Supported |
| Linux | Swift 5.9+ | ✅ Supported |

### Kotlin

| Platform | Minimum Version | Status |
|----------|-----------------|--------|
| JVM | 17+ | ✅ Supported |
| Android | API 26+ | ✅ Supported |
| iOS (KMP) | - | 🔧 Configurable |
| macOS (KMP) | - | 🔧 Configurable |

### TypeScript

| Runtime | Minimum Version | Status |
|---------|-----------------|--------|
| Node.js | 18.0+ | ✅ Supported |
| Browsers | ES2020+ | ✅ Supported |
| Deno | 1.30+ | ✅ Supported |
| Bun | 1.0+ | ✅ Supported |

---

## Backward Compatibility Policy

### Major Version (X.0.0)

- May include breaking API changes
- May include semantic changes
- Migration guide will be provided

### Minor Version (1.X.0)

- No breaking API changes
- May add new optional fields
- May add new configuration options
- Semantic behavior unchanged

### Patch Version (1.0.X)

- Bug fixes only
- No API changes
- No semantic changes

---

## What NIE Guarantees

✅ **Deterministic results** for identical inputs
✅ **No network calls** - pure computation
✅ **No file I/O** - pure computation
✅ **No side effects** - pure computation
✅ **No platform UI dependencies** - core logic only
✅ **No async operations** - synchronous execution
✅ **Explicit timezone handling** - no system timezone assumptions

---

## What NIE Does NOT Guarantee

❌ Notification scheduling (platform responsibility)
❌ Event persistence (consumer responsibility)
❌ Recurring event expansion (consumer responsibility)
❌ Time synchronization (consumer responsibility)
❌ Permission handling (platform responsibility)

---

## Migration Notes

### From Pre-1.0 Versions

If migrating from a pre-release version:

1. `Sendable` conformance removed from `NIEvent`, `NIResolverConfig`, `NIUpcomingEventInfo`
2. `@Sendable` removed from `skipPredicate` closure
3. These changes improve Swift 6 compatibility
4. No semantic changes - behavior is identical

---

## Contact

For API stability questions or concerns, open an issue in the repository.
