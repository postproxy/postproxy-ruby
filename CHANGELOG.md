# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.10.0] - 2026-06-03

### Added

- **Direct Messages API.** New `chats` resource (`list`, `create`, `get`, `archive`, `unarchive`) and `messages` resource (`list`, `send`, `get`, `edit`, `react`, `unreact`), with `Chat`, `Message`, `Reaction`, and shared `Attachment` models. Supports Facebook Messenger, Instagram, Telegram, and Bluesky.
- `comments.private_reply(post_id, comment_id, profile_id:, text:)` — sends a DM in reply to a comment's author (Instagram/Facebook); returns a `Message`.
- `Comment#attachments` (array of `Attachment`) and `Comment#metadata` fields.
- New webhook event types: `profile_comment.created`, `message.received`, `message.sent`, `message.delivered`, `message.read`, `message.edited`, `message.deleted`, `message.failed_waiting_for_retry`, `message.failed`, `reaction.received`, with typed payloads `MessageEventData`, `ReactionEventData`, and `ProfileCommentCreatedData`.

## [1.9.0] - 2026-05-15

### Added

- `google_business` platform value for posts and profiles.
- `profile_comments` resource: `list`, `get`, `create`, `delete` for review replies via `/api/profiles/:profile_id/comments`.
- Per-media platform error reporting: `Media#platforms` containing `MediaPlatformError` entries with `error_details`.
