# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Service Pulse, please **do not open a public issue**. Instead, report it privately:

- **GitHub Private Reporting:** [Report a vulnerability](https://github.com/kobibell/service-pulse/security/advisories/new)

Please include:
- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept if possible
- The version of Service Pulse you tested against

I'll acknowledge your report within **72 hours** and aim to ship a fix or mitigation within **14 days** for confirmed issues, depending on severity. I'll credit you in the release notes unless you prefer to stay anonymous.

## Scope

In scope for this project:

- The Service Pulse macOS app itself
- The build/release scripts in this repository

Out of scope:

- The underlying OS or third-party runtimes (Docker Desktop, Apple Mac Containers, macOS)
- Social engineering or physical access attacks

## Design Notes

A few security-relevant decisions documented for transparency:

- **No sandbox.** Service Pulse runs `/sbin/ping` and reads `/var/run/docker.sock` directly, and both require entitlements incompatible with the macOS App Sandbox. The app is distributed outside the App Store as a result.
- **No telemetry.** No data leaves your machine. There are no analytics, crash reporters, or network calls beyond the health checks you configure.
- **Unnotarized builds.** Current releases are not notarized. Installation requires running `xattr -cr "/Applications/Service Pulse.app"` to clear the Gatekeeper quarantine flag. Notarization is planned once the project reaches sustainable traction.
- **Open source.** The full source is available for review. If something looks off, open a discussion or follow the reporting process above.
