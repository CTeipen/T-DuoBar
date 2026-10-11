# Security Policy

## Supported Versions

This policy applies to the T-DuoBar fork. Security fixes target the current default branch. There is not yet a Developer ID signed and notarized binary release of this fork.

| Version | Supported |
| --- | --- |
| Current default branch (1.6.0) | Yes |
| Historical upstream versions | Refer to the original DuoBar project |

## Reporting a Vulnerability

Please do not disclose unresolved security vulnerabilities in public GitHub Issues. Use the repository's **Security → Report a vulnerability** option (GitHub Private Vulnerability Reporting). If that option is unavailable, open an issue containing no vulnerability details and ask the maintainers to arrange a private reporting channel.

Reports will be acknowledged and investigated responsibly as soon as reasonably possible. Include the macOS version, T-DuoBar version, reproduction steps, potential impact, and relevant logs or screenshots with sensitive information removed.

## Privacy and Data Handling

T-DuoBar processes battery, network, volume, Bluetooth audio-device, and charging state locally. It has no analytics, tracking, backend service, or telemetry, and no system-status data is uploaded.

Location permission, when requested, is used only to access Wi-Fi SSID information through macOS APIs.

## Scope

Security issues in T-DuoBar itself are in scope. General macOS, Apple framework, or third-party operating-system vulnerabilities are outside the project's scope unless T-DuoBar directly contributes to the issue.

The weekly version checker requests a public HTTPS manifest from our Homebrew tap. It uploads no system-status data. Installation uses an explicitly selected, checksum-pinned Homebrew cask after user action. The experimental builds are not Developer ID signed or notarized.
