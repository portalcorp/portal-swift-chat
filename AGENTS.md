# Repository Guidelines

## Project Structure & Module Organization
The Xcode workspace lives in `portal.xcodeproj`; open it to manage schemes, assets, and signing. The SwiftUI source sits in `portal/`, with `portalApp.swift` bootstrapping the app and `ContentView.swift` orchestrating the main layout. Feature code is grouped by role: `Models/` extends `ModelConfiguration`, `LLMEvaluator`, and device metrics; `Views/Chat`, `Views/Onboarding`, and `Views/Settings` encapsulate screen-specific SwiftUI components; `Support/` hosts auxiliary helpers when needed. Visual assets stay in `Assets.xcassets` and `moon-phases.mp4`, while `Preview Content` exists solely for SwiftUI previews.

## Build, Test, and Development Commands
- `open portal.xcodeproj` launches the project in Xcode for local development.
- `xcodebuild -project portal.xcodeproj -scheme portal build` performs a CI-friendly build of the iOS target.
- `xcodebuild -project portal.xcodeproj -scheme portal -destination 'platform=iOS Simulator,name=iPhone 15' test` runs the test bundle against a simulator; adjust the destination to match your installed runtimes.

## Coding Style & Naming Conventions
Follow standard Swift style: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for variables and functions, and enum cases in `lowerCamelCase`. Prefer value types and SwiftUI composition, keeping views small (`Views/Chat` demonstrates the pattern). Keep model identifiers and asset names synchronized with the MLX model IDs defined in `Models/Models.swift`. No automatic formatter is enforced; run `swift-format` locally if you depend on it and confirm the diff stays minimal.


## Commit & Pull Request Guidelines
Keep commits focused and written in sentence case imperative mood (for example, `Update fade mask effect on bottom`). Include context in the body when touching models or build settings. Pull requests should describe the user-facing impact, list any model assets or entitlements that changed, and note manual test steps. Link to the tracked issue or todo item when applicable, and attach screenshots or screen recordings for visible UI updates.
