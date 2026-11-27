# Changelog

All notable changes are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com), versioning follows [SemVer](https://semver.org).

## [Unreleased]

### Added
- Search transactions by category, note or amount
- Filter transactions by type, categories and date range
- Sort transactions by newest, oldest, highest or lowest amount
- "No matching transactions" empty state with a Clear all action
- Recurring transactions: repeat weekly or monthly from the Add transaction screen
- Recurring screen to view upcoming repeats and delete rules
- Missed repeats are created automatically when the app opens, including after time away
- Recurring rules sync across devices without creating duplicate transactions
- Budget alerts: a notification at 80% and again at 100% of a monthly budget, sent once per category per month
- Bell button on the Budgets screen to turn budget alerts on or off
- App lock: unlock with fingerprint, face or the phone's PIN when the app opens and after 30 seconds in the background
- App lock can be turned on or off from the menu on the Home screen
- Export transactions to a CSV file from the Home menu, shared through the system share sheet
- Export only the results of the current search or filter

### Changed
- Database upgraded to schema v4 (existing data is preserved)
- Sign out moved into the menu on the Home screen

## [1.0.0] - 2026-10-28

### Added
- Email/password sign-in with email verification and password reset
- Transactions with categories, editing and undo-delete
- Monthly budgets with progress indicators
- Reports: spending by category and 6-month income vs. expense
- Offline-first storage (Drift) with two-way Firestore sync