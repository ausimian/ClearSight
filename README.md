# AcuityPro

A native iOS app that uses ARKit's TrueDepth (Face ID) camera to simulate a clinical Snellen eye test. The app measures your real-time distance from the screen, presents correctly-scaled chart letters, and guides you through a standardised visual acuity test for each eye.

**Not a medical device.** Results are indicative only and should prompt you to seek professional optometric assessment.

## Requirements

- iPhone X or later (TrueDepth camera required)
- iOS 17.0+
- Xcode 15+

## How It Works

1. **Calibration** — Hold the phone at arm's length (~33cm). An animated ring locks green when you've held steady for 2 seconds.
2. **Right eye test** — Cover your left eye. Read each row of letters aloud (voice recognition) or tap them on screen. Rows progress from large (6/60) to small (6/4).
3. **Left eye test** — Cover your right eye. Same process with different randomised letters.
4. **Results** — See your Snellen fraction and LogMAR score for each eye, with a traffic-light severity indicator.

### Scoring

- Each row requires 60%+ correct to pass (standard clinical threshold)
- Test stops at the first failed row
- Your score is the last row passed (e.g. pass 6/12 but fail 6/9 = 6/12)
- Results: Normal (6/6-6/9), Mild impairment (6/12-6/18), Significant (6/24+)

### Chart Scaling

Letters are scaled so their angular size at phone distance matches what you'd see on a 6m Snellen chart:

```
Scale Factor = phone_distance_cm / 600
Letter Height = reference_height_mm * scale_factor * device_points_per_mm
```

The scaler uses the device's actual PPI and updates dynamically if your distance drifts.

## Voice Input

Speech recognition runs via Apple's Speech framework (on-device or server). The app maps spoken letters through a phonetic table that handles:

- Letter names ("dee", "aitch", "zed"/"zee")
- NATO phonetic alphabet ("Victor", "Sierra", "Hotel", etc.)
- Common Speech framework mishearings ("the" -> D, "okay" -> K, "eight" -> H, "we" -> V)

An undo button lets you correct misrecognised letters without restarting the row.

## Architecture

**MVVM + Service Layer** — SwiftUI views, ObservableObject view models, and service classes for ARKit, speech, distance measurement, and scoring.

```
AcuityPro/
├── App/                    # Entry point
├── Features/
│   ├── Onboarding/         # Permissions, device check
│   ├── Calibration/        # Distance lock screen
│   ├── EyeTest/            # Chart, voice/tap input, eye cover prompts
│   └── Results/            # Score display, sharing
├── Services/
│   ├── ARFaceTrackingService       # ARKit face tracking, distance, blink detection
│   ├── SpeechRecognitionService    # Speech framework, phonetic mapping
│   ├── DistanceMeasurementService  # 33cm target lock with 2s hold
│   └── EyeTestScoringService      # Row generation, 60% pass threshold
├── Models/                 # TestSession, EyeTestResult, VisualAcuityScale
├── Utilities/              # ChartScaler, haptic feedback
└── Resources/              # Assets, Info.plist
```

## Building

```bash
# Build for device
xcodebuild -project AcuityPro.xcodeproj -scheme AcuityPro \
  -destination 'platform=iOS,name=YouriPhone' \
  -allowProvisioningUpdates build

# Install on device
xcrun devicectl device install app --device <DEVICE_ID> \
  path/to/Build/Products/Debug-iphoneos/AcuityPro.app
```

Set your development team in Xcode's Signing & Capabilities before building.

## Permissions

The app requests all permissions upfront before the test begins:

- **Camera** — TrueDepth face tracking for distance measurement
- **Microphone** — Voice letter input
- **Speech Recognition** — Converting speech to letter identifiers

## License

MIT License. Copyright (c) 2026 Nick Gunn. See [LICENSE](LICENSE) for details.

Not intended for clinical or diagnostic purposes.
