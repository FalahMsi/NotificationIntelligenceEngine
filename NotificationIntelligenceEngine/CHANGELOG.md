# Changelog

All notable changes to the Notification Intelligence Engine will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing unreleased.

---

## [1.0.0] - 2024-03-15

### Added

**Core Engine**
- `resolveUpcomingEvent()` function for determining the next upcoming event
- `NIEvent` type for representing schedulable events
- `NIResolverConfig` type for resolver configuration
- `NIUpcomingEventInfo` type for resolution results
- `NIDayLabel` enum (`today`, `tomorrow`, `later`)

**Cross-Platform Implementations**
- Swift Package (SPM) - iOS 15+, macOS 12+, tvOS 15+, watchOS 8+
- Kotlin Module (KMP-ready) - JVM 17+, Android API 26+
- TypeScript Library - Node.js 18+, ES2020+ browsers

**Testing**
- 25 cross-platform test vectors covering:
  - Basic event selection (today, tomorrow, later)
  - Lead time calculations
  - Timezone handling (positive/negative offsets)
  - DST transitions (spring forward, fall back)
  - Midnight boundary conditions
  - Skip predicate filtering
  - Lookahead window enforcement
  - Empty/null edge cases

**Documentation**
- Comprehensive README with usage examples
- API_STABILITY.md with stability guarantees
- Consumer usage validation tests

### Security

- No network operations (pure computation)
- No file I/O
- No global state
- Deterministic outputs

### Notes

- Swift 6 ready (zero concurrency warnings with strict checking)
- Synchronous API (no async/await)
- Thread-safe by design (pure, stateless)

---

## Versioning Policy

### Public API (STABLE)

The following are considered **stable public API** and will not change without a major version bump:

| Element | Stability |
|---------|-----------|
| `resolveUpcomingEvent()` function signature | Stable |
| `NIEvent` fields | Stable |
| `NIResolverConfig` fields | Stable |
| `NIUpcomingEventInfo` fields | Stable |
| `NIDayLabel` enum cases | Stable |
| Semantic behavior (selection, trigger time, day label) | Stable |

### Internal Implementation (EVOLVABLE)

The following may change in minor/patch versions:

- Internal helper functions
- ISO 8601 formatting implementation details
- Test infrastructure
- Documentation improvements

### Breaking Change Policy

- **Major (X.0.0)**: May include breaking API or semantic changes
- **Minor (1.X.0)**: Backward-compatible additions only
- **Patch (1.0.X)**: Bug fixes only, no API changes

---

[Unreleased]: https://github.com/example/notification-intelligence-engine/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/example/notification-intelligence-engine/releases/tag/v1.0.0
