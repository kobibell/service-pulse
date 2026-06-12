# Service Pulse

A lightweight macOS menubar app that monitors your services and shows their health at a glance.

![status: green/yellow/red](https://img.shields.io/badge/status-active-brightgreen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What it does

Service Pulse sits in your menu bar and keeps an eye on the things you care about:

- **Ping checks** — ICMP ping to any host or IP, with live latency
- **Docker checks** — reads your local Docker socket and reports container health
- **Background polling** every 30 seconds, plus a manual refresh button
- **Native notifications** when something goes down or comes back up
- **Local-only** — no servers, no telemetry, no accounts. Everything runs and stays on your Mac

The menubar icon reflects overall status:

| Icon | Meaning |
| --- | --- |
| 🟢 | All services healthy |
| 🟡 | Some services down |
| 🔴 | All services down |
| ⚪ | No data yet |

## Requirements

- macOS 13.0 or later
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (only if you want to monitor containers)

## Installation

Service Pulse isn't notarized yet, so for now the recommended way to run it is to build it
yourself — this avoids the macOS Gatekeeper warning entirely, since locally-built apps aren't
quarantined.

1. Clone the repo:
   ```bash
   git clone https://github.com/kobibell/service-pulse.git
   cd service-pulse
   ```
2. Open `Service Pulse.xcodeproj` in Xcode (16+)
3. Build and run (⌘R)

The app will launch and appear in your menu bar — no Dock icon, since it's a menubar-only app.

A pre-built DMG is also available on the [Releases](../../releases) page, but since it isn't
notarized, macOS will block it on first launch. If you go that route, see
[Privacy & Security in System Settings](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac)
for how to allow it, or run `xattr -cr "/Applications/Service Pulse.app"` from Terminal.

## Usage

1. Click the menubar icon to open the dropdown
2. Click **Add Service** to monitor a new ping target or Docker host
3. Statuses refresh automatically every 30 seconds, or click the refresh icon
4. Right-click or use the minus button on a row to remove a service

## Why no sandbox?

Service Pulse needs to run `/sbin/ping` and talk to `/var/run/docker.sock` directly, both of which
are restricted under the App Sandbox. It's distributed outside the App Store as a result.

## Support this project

Service Pulse is free and open source. If you find it useful, consider supporting development:

- ☕ [Buy Me a Coffee](https://buymeacoffee.com/kobibell)
- 💖 [GitHub Sponsors](https://github.com/sponsors/kobibell)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Source code is licensed under the [MIT License](LICENSE). The "Service Pulse" name and logo are
trademarks and may not be reused in forks or derivative distributions — see the LICENSE file for
details.
