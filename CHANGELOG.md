# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.9.0] - 2026-05-15

### Added

- `google_business` platform value for posts and profiles.
- `profile_comments` resource: `list`, `get`, `create`, `delete` for review replies via `/api/profiles/:profile_id/comments`.
- Per-media platform error reporting: `Media#platforms` containing `MediaPlatformError` entries with `error_details`.
