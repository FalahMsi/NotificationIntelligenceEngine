# Nubti - Shift Management App

A comprehensive iOS application for managing work shifts, leaves, and attendance tracking.

## Overview

Nubti helps employees track their rotating shift schedules, manage leaves, and maintain work statistics. The app supports multiple shift systems commonly used in various industries.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Architecture

```
Nubti/
├── App/                    # Application entry point
├── Core/                   # Core business logic
│   ├── ShiftEngine/        # Shift calculation engine
│   │   ├── Systems/        # Supported shift systems
│   │   └── TimeShift/      # Time-based calculations
│   ├── Storage/            # Data persistence
│   ├── Notifications/      # Local notifications
│   ├── Messages/           # Activity log system
│   ├── Logging/            # Structured logging (os.log)
│   └── Utilities/          # Helper utilities
├── Features/               # Feature modules
│   ├── Calendar/           # Calendar views
│   ├── Settings/           # App settings
│   ├── Updates/            # Activity log view
│   └── Onboarding/         # Initial setup flow
├── Models/                 # Data models
├── Services/               # Business services
│   └── Reports/            # PDF report generation
├── UI/                     # Reusable UI components
│   ├── Components/         # Custom views
│   ├── Modifiers/          # SwiftUI modifiers
│   └── Helpers/            # UI helpers
├── Dashboard/              # Statistics dashboard
├── DesignSystem/           # Design tokens & themes
└── Achievement/            # Notes & achievements
```

## Supported Shift Systems

1. **Three Shifts + Two Off** (`threeShiftTwoOff`)
   - Morning, Evening, Night rotation with 2 days off

2. **24/48 System** (`twentyFourFortyEight`)
   - 24-hour shift followed by 48 hours off

3. **Two Work / Four Off** (`twoWorkFourOff`)
   - 2 working days followed by 4 days off

4. **Standard Morning** (`standardMorning`)
   - Traditional weekday schedule (Sun-Thu)

5. **Eight Hour Shift** (`eightHourShift`)
   - Flexible 8-hour daily shifts

## Key Features

- **Shift Calendar**: Visual calendar showing work/off days
- **Leave Management**: Track annual, sick, and other leave types
- **Hourly Events**: Log late arrivals, early departures, overtime
- **Statistics Dashboard**: Monthly attendance metrics
- **PDF Reports**: Generate work reports for HR
- **Notifications**: Shift reminders with customizable timing
- **RTL Support**: Full Arabic language support
- **Dark Mode**: System-integrated appearance

## Building the Project

1. Open `Nubti.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press `Cmd + R` to build and run

## Running Tests

```bash
# Run unit tests
Cmd + U
```

## Project Stats

- **Total Files**: ~122 Swift files
- **Lines of Code**: ~21,860
- **MARK Comments**: 1,548
- **Architecture**: Feature-based modular design
- **State Management**: ObservableObject + @Published

## Technical Highlights

- Clean Architecture with separation of concerns
- Protocol-oriented shift system design
- Structured logging with `os.log`
- UserDefaults + JSON file persistence
- Local notifications with UNUserNotificationCenter
- Accessibility support (VoiceOver, Dynamic Type)
- Bilingual support (Arabic/English)

## License

Private - All rights reserved.
