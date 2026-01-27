# Testing Guide - Nubti App

## Setup Instructions

To add unit tests, create a test target in Xcode:
1. File > New > Target
2. Select "Unit Testing Bundle"
3. Name it "NubtiTests"
4. Click Finish

## Recommended Test Structure

```
NubtiTests/
├── Core/
│   ├── ShiftEngine/
│   │   ├── ShiftEngineTests.swift
│   │   ├── ShiftContextTests.swift
│   │   └── Systems/
│   │       ├── ThreeShiftTwoOffSystemTests.swift
│   │       ├── StandardMorningScheduleTests.swift
│   │       ├── TwentyFourFortyEightSystemTests.swift
│   │       ├── EightHourShiftSystemTests.swift
│   │       └── TwoWorkFourOffSystemTests.swift
│   └── Logic/
│       └── WorkDaysCalculatorTests.swift
├── Stores/
│   ├── ManualLeaveStoreTests.swift
│   └── ShiftEventStoreTests.swift
└── Helpers/
    └── MockData.swift
```

## Priority Test Cases

### Critical Priority

#### 1. ShiftEngine.calculateExactShiftTimes()
```swift
func test_calculateExactShiftTimes_morningShift_returnsCorrectTimes()
func test_calculateExactShiftTimes_nightShift_crossesMidnight()
func test_calculateExactShiftTimes_withCustomStartHour()
func test_calculateExactShiftTimes_nilForOffDay()
```

#### 2. WorkDaysCalculator.calculate()
```swift
func test_calculate_fullMonth_countsCorrectWorkDays()
func test_calculate_withLeaves_deductsCorrectly()
func test_calculate_withPartialAdjustments_calculatesNetMinutes()
func test_calculate_morningSystem_excludesWeekends()
func test_calculate_crossYearRange_handlesCorrectly()
```

### High Priority

#### 3. ThreeShiftTwoOffSystem.buildTimeline()
```swift
func test_buildTimeline_cyclePattern_isCorrect()
func test_buildTimeline_negativeIndex_handlesModulo()
func test_buildTimeline_startFromAnyPhase()
```

#### 4. ManualLeaveStore Operations
```swift
func test_saveLeave_newLeave_addsSuccessfully()
func test_saveLeave_overlapping_removesConflicts()
func test_countDays_singleYear_countsCorrectly()
```

## Mock Data Template

```swift
import Foundation
@testable import Nubti

enum MockData {
    static var sampleShiftContext: ShiftContext {
        var comps = DateComponents()
        comps.hour = 7
        comps.minute = 0

        return ShiftContext(
            systemID: .threeShiftTwoOff,
            startPhase: .morning,
            setupIndex: 0,
            shiftStartTime: comps,
            referenceDate: Date(),
            flexibility: .standard
        )
    }

    static var sampleManualLeave: ManualLeave {
        ManualLeave(
            id: UUID(),
            type: .annual,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 3),
            note: "Test Leave"
        )
    }

    static func dateFromComponents(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
```

## Sample Test File

```swift
import XCTest
@testable import Nubti

final class WorkDaysCalculatorTests: XCTestCase {

    var calculator: WorkDaysCalculator!

    override func setUp() {
        super.setUp()
        calculator = WorkDaysCalculator()
    }

    override func tearDown() {
        calculator = nil
        super.tearDown()
    }

    func test_calculate_fullMonth_countsCorrectWorkDays() {
        // Given
        let context = MockData.sampleShiftContext
        let start = MockData.dateFromComponents(year: 2026, month: 1, day: 1)
        let end = MockData.dateFromComponents(year: 2026, month: 1, day: 31)

        // When
        let result = calculator.calculate(
            from: start,
            to: end,
            context: context,
            referenceDate: context.referenceDate
        )

        // Then
        XCTAssertGreaterThan(result.workingDaysTotal, 0)
        XCTAssertGreaterThanOrEqual(result.netWorkingDays, 0)
        XCTAssertLessThanOrEqual(result.netWorkingDays, result.workingDaysTotal)
    }

    func test_calculate_withNoLeaves_netEqualsTotal() {
        // Given
        let context = MockData.sampleShiftContext
        let start = MockData.dateFromComponents(year: 2026, month: 2, day: 1)
        let end = MockData.dateFromComponents(year: 2026, month: 2, day: 7)

        // When
        let result = calculator.calculate(
            from: start,
            to: end,
            context: context,
            referenceDate: context.referenceDate
        )

        // Then - with no leaves, effective should equal total
        XCTAssertEqual(
            result.netWorkingDays,
            result.workingDaysTotal - result.leaveDaysEffective
        )
    }
}
```

## Running Tests

After creating the test target:

```bash
# Command line
xcodebuild test -scheme ShiftCalendar -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Or in Xcode
Cmd + U
```
