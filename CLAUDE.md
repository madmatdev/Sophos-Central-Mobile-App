# Sophos Central Mobile App — Project Guide

## Overview

iOS app (SwiftUI) that surfaces the Sophos Central security platform on mobile. Lets admins monitor account health, alerts, devices, detections, and cases — and take security actions directly from their phone.

- **Repo:** https://github.com/madmatdev/Sophos-Central-Mobile-App
- **Branch model:** `main` is stable/release; active work on `feature/ui-enhancements`
- **Build:** Xcode project at `CentralMobileApp.xcodeproj`, generated from `project.yml` (XcodeGen)

## Workflow Rules

- After every code change: `git add` (specific files only), `git commit`, `git push origin <branch>`
- Do **not** stage: `.xcuserstate`, `.DS_Store`, `.claude/settings.local.json`
- This keeps Xcode in sync for immediate testing after each update

---

## Architecture

### Key Files

| File | Purpose |
|---|---|
| `CentralMobileApp/Services/SophosAPIService.swift` | All Sophos Central API calls (actor, async/await) |
| `CentralMobileApp/Models/APIModels.swift` | Codable structs for all API responses |
| `CentralMobileApp/Models/CacheModels.swift` | SwiftData persistent cache models |
| `CentralMobileApp/ViewModels/DashboardViewModel.swift` | Observable dashboard state, refresh, persistence |
| `CentralMobileApp/ViewModels/DevicesViewModel.swift` | Device actions with biometric auth guard |
| `CentralMobileApp/Theme/SophosTheme.swift` | All colors, typography, spacing, card styles |
| `CentralMobileApp/Views/Dashboard/DashboardView.swift` | Root TabView (Dashboard / Alerts / Devices / Detections / Cases / Settings) |

### Navigation Structure

```
TabView
├── Dashboard        → DashboardView (cards: AccountHealth, Alerts, Devices, Detections, Cases)
├── Alerts           → AlertsListView → AlertDetailView
├── Devices          → DevicesListView → DeviceDetailView
├── Detections       → DetectionsListView
├── Cases            → CasesListView → CaseDetailView
└── Settings         → SettingsView
```

### API Base URL

Stored in Keychain under `.dataRegionURL`; falls back to `https://api.central.sophos.com`.
All requests include `Authorization: Bearer <token>` and `X-Tenant-ID` headers.

---

## Sophos Central API — Endpoint Device Actions

Source: developer.sophos.com (Endpoint API v1)

### Implemented in App

| Action | API Endpoint | Notes |
|---|---|---|
| Isolate endpoint | `POST /endpoint/v1/endpoints/isolation` | Bulk; `enabled: true` |
| De-isolate endpoint | `POST /endpoint/v1/endpoints/isolation` | Bulk; `enabled: false` |
| Get isolation status | `GET /endpoint/v1/endpoints/{id}/isolation` | Fetched on DeviceDetail load |
| Trigger scan | `POST /endpoint/v1/endpoints/{id}/scans` | Empty body `{}` |
| Get tamper protection | `GET /endpoint/v1/endpoints/{id}/tamper-protection` | |
| Set tamper protection | `POST /endpoint/v1/endpoints/{id}/tamper-protection` | Body: `{"enabled": bool}` |
| Get Adaptive Attack Protection | `GET /endpoint/v1/endpoints/{id}/adaptive-attack-protection` | |
| Set Adaptive Attack Protection | `POST /endpoint/v1/endpoints/{id}/adaptive-attack-protection` | Body: `{"enabled": bool, "expiresAfter": "P7D"}` |
| Acknowledge alert | `POST /common/v1/alerts/{id}/actions` | Body: `{"action": "acknowledge"}` |

### Not Yet Implemented

| Action | API Endpoint | Priority |
|---|---|---|
| Update check | `POST /endpoint/v1/endpoints/{id}/update-checks` | High — triggers agent software update check |
| Clear threat | `POST /common/v1/alerts/{id}/actions` | Medium — body: `{"action": "clearThreat"}` |
| Clean virus | `POST /common/v1/alerts/{id}/actions` | Medium — body: `{"action": "cleanVirus"}` |
| Clean PUA | `POST /common/v1/alerts/{id}/actions` | Medium — body: `{"action": "cleanPua"}` |
| Forensic log collection | `POST /endpoint/v1/endpoints/{id}/forensic-log-collection` | Low — admin-scope only |
| Delete endpoint | `DELETE /endpoint/v1/endpoints/{id}` | Low — destructive |

### Other APIs in Use

| API | Base Path | Purpose |
|---|---|---|
| Account Health | `/account-health-check/v1/health-check` | Dashboard health score |
| Alerts | `/common/v1/alerts` | List + acknowledge |
| Detections | `/detections/v1/queries/detections` | Async query pattern (start → poll → results) |
| Cases | `/cases/v1/cases` | List, fetch, update (PATCH) |

---

## UI Components & Patterns

### Theme Usage
- Colors: `SophosTheme.Colors.*` (sophosBlue, statusHealthy, statusWarning, statusCritical, severityHigh, etc.)
- Typography: `SophosTheme.Typography.headline()`, `.subheadline()`, `.footnote()`, `.caption()`, `.caption2()`
- Spacing: `SophosTheme.Spacing.xs / sm / md / lg / xl`
- Cards: `.sophosCard()` view modifier
- Section headers: `.sophosSectionHeader()` modifier

### Shared Components (in `DashboardView.swift`)
- `SkeletonRow` — animated loading placeholder
- `EmptyStateRow` — icon + message for empty states
- `FilterPill` — tappable filter chip (in `AlertsListView.swift`)
- `SeverityBadge` — colored capsule for alert severity
- `HealthStatusDot` — colored dot + label for endpoint health
- `ErrorView` — full-screen error with retry button

### Device Actions Pattern
All device actions in `DevicesViewModel` follow this pattern:
1. Biometric auth via `authenticateBiometric(reason:)` (Face ID / Touch ID)
2. Set `actionInProgress = endpoint.id`
3. Call API
4. Set `actionSuccess` or `actionError`
5. `defer { actionInProgress = nil }`

---

## Recent Changes (feature/ui-enhancements)

| Commit | Change |
|---|---|
| `9bb6756` | Add date/time range filter to Dashboard Alerts card and Alerts list |
| `65cc347` | Fix Run Security Scan: postEmpty now decodes API errors and logs debug output |
| `aed627e` | Fix device isolation 409: fetch real status on load and handle in-progress state |
| `0108211` | Bump build version to 11 for TestFlight |
| `71ad6d5` | Remove Open/Closed filter from Alerts; confirm dashboard View All navigation |
| `98b3c34` | Fix Alerts Open/Closed filter: switch to client-side filtering |

---

## Date/Time Filter (added in `9bb6756`)

**Dashboard AlertsCard** (`Views/Dashboard/AlertsCard.swift`):
- Quick preset chips: All / Today / 7 Days / 30 Days
- Filters counts and 3-alert preview in the card

**Alerts Tab** (`Views/Alerts/AlertsListView.swift`):
- "Date Range" filter pill alongside severity chips
- Opens `DateRangeFilterSheet` (`.medium` detent sheet)
- Independent From (start) and Until/Stop (end) toggles with graphical `DatePicker`
- Active range shown in pill label; `×` button clears without opening sheet

---

## Build & TestFlight

- Current build version: **11**
- Scheme: `CentralMobileApp`
- Archive → Distribute → TestFlight for internal testing
