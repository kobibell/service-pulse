# Contributing to Service Pulse

Thanks for your interest in improving Service Pulse! This is a small, focused menubar utility,
and contributions are very welcome.

## Getting started

1. Fork the repo and clone your fork
2. Open `Service Pulse.xcodeproj` in Xcode 16+
3. Build and run with ⌘R (target macOS 13+)

## Guidelines

- Keep the app **native and dependency-free** — no third-party packages
- Match the existing style: minimal, native SwiftUI, no unnecessary abstractions
- New checker types (HTTP, TCP, process, etc.) should follow the pattern of
  `PingChecker.swift` / `DockerChecker.swift` — a simple struct/enum with a static check function
- If you're adding a new `ServiceType`, update `Models.swift`, `ServiceMonitor.swift`,
  `AddServiceView.swift`, and `ServiceRow.swift`

## Reporting bugs / requesting features

Open an issue with as much detail as possible — macOS version, steps to reproduce, and
screenshots if relevant.

## Pull requests

- Keep PRs focused on a single change
- Make sure the project builds cleanly before submitting
- Describe what changed and why in the PR description

## Branding

Please don't reuse the "Service Pulse" name or app icon in forks or redistributions — see the
LICENSE file for details. Feel free to pick your own name if you're shipping a fork!
