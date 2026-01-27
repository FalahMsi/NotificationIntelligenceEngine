# Support Policy

## Version: 1.0.0

This document defines what is supported, what is not supported, and how breaking changes are handled in the Notification Intelligence Engine.

---

## What IS Supported

### Core Functionality

| Feature | Support Level | Notes |
|---------|---------------|-------|
| `resolveUpcomingEvent()` function | **Full** | Deterministic event resolution |
| Event selection by `startTime` | **Full** | Strictly greater than reference time |
| Trigger time calculation | **Full** | `startTime - leadTimeMinutes` |
| Day label calculation | **Full** | `today`, `tomorrow`, `later` |
| Timezone handling | **Full** | IANA timezone identifiers |
| Skip predicate filtering | **Full** | Consumer-provided filter function |
| Lookahead window | **Full** | Configurable, default 7 days |

### Platforms

| Platform | Support Level | Minimum Version |
|----------|---------------|-----------------|
| Swift (iOS) | **Full** | iOS 15.0+ |
| Swift (macOS) | **Full** | macOS 12.0+ |
| Swift (tvOS) | **Full** | tvOS 15.0+ |
| Swift (watchOS) | **Full** | watchOS 8.0+ |
| Swift (Linux) | **Full** | Swift 5.9+ |
| Kotlin (JVM) | **Full** | JDK 17+ |
| Kotlin (Android) | **Full** | API 26+ |
| TypeScript (Node.js) | **Full** | Node.js 18+ |
| TypeScript (Browser) | **Full** | ES2020+ |

### Test Vectors

All 25 test vectors are part of the supported contract. They cover:

- Basic event selection
- Lead time calculations
- Timezone edge cases
- DST transitions
- Midnight boundaries
- Skip predicate filtering
- Lookahead window enforcement
- Null/empty handling

---

## What IS NOT Supported

### Explicitly Out of Scope

| Feature | Reason |
|---------|--------|
| Platform notification scheduling | Use `UNUserNotificationCenter`, `AlarmManager`, etc. |
| Event persistence | NIE is stateless; use your database |
| UI components | NIE is headless |
| Recurring event expansion | Provide pre-expanded instances |
| Notification permissions | Platform responsibility |
| Network operations | NIE is pure computation |
| Calendar synchronization | Consumer responsibility |

### Not Tested / No Guarantees

| Scenario | Notes |
|----------|-------|
| Timezones without IANA identifiers | Use IANA format only (e.g., "America/New_York") |
| Events with invalid dates | Undefined behavior |
| Negative lead times | Not tested, may work but not guaranteed |
| Lookahead > 365 days | Not tested |
| Concurrent modification during resolution | NIE is stateless, but input arrays should not be mutated during call |

---

## Breaking Change Policy

### Definition of Breaking Change

A change is considered "breaking" if it:

1. Changes the function signature of `resolveUpcomingEvent()`
2. Changes the fields of `NIEvent`, `NIResolverConfig`, or `NIUpcomingEventInfo`
3. Changes the values of `NIDayLabel`
4. Changes the semantic behavior (different output for same input)
5. Removes a public type or function

### How Breaking Changes Are Handled

| Version Type | Breaking Changes Allowed? | Process |
|--------------|---------------------------|---------|
| Major (X.0.0) | Yes | Migration guide provided |
| Minor (1.X.0) | No | Backward compatible only |
| Patch (1.0.X) | No | Bug fixes only |

### Deprecation Process

1. Feature marked `@deprecated` in code
2. Deprecation warning in CHANGELOG
3. Minimum 1 minor version before removal
4. Migration path documented

---

## Bug Reports

### How to Report

Open an issue with:

1. Platform and version (e.g., "Swift 5.9, iOS 17")
2. NIE version (e.g., "1.0.0")
3. Minimal reproduction code
4. Expected vs actual behavior
5. Test vector ID if applicable

### Response Time

| Severity | Target Response |
|----------|-----------------|
| Critical (crash, data loss) | 48 hours |
| High (incorrect results) | 1 week |
| Medium (edge case) | 2 weeks |
| Low (documentation) | Best effort |

---

## Security

### Reporting Security Issues

For security vulnerabilities, do NOT open a public issue.

Instead, report privately via:
- GitHub Security Advisories (if repository supports it)
- Direct email to maintainers

### Security Guarantees

NIE provides these security properties:

- No network operations
- No file I/O
- No global state
- No code execution from input
- Deterministic outputs (no randomness)

---

## Getting Help

### Documentation

- [README.md](./README.md) - Overview and usage
- [API_STABILITY.md](./API_STABILITY.md) - API guarantees
- [CHANGELOG.md](./CHANGELOG.md) - Version history
- Test vectors (`test-vectors.json`) - Reference behaviors

### Community

- GitHub Issues - Bug reports and feature requests
- GitHub Discussions - Questions and ideas

---

## Disclaimer

This library is provided "as is" under the MIT License. While we strive for correctness, the library is provided without warranty. See LICENSE for full terms.

Critical scheduling applications should implement their own validation and testing appropriate to their risk tolerance.
