# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.13.0] - 2026-08-17

### Added

- **Interactive DMs on Facebook and Instagram.** `messages.send` accepts **`quick_replies`** (up to 13 tappable chips above the participant's composer, gone once tapped — each `title` + `payload`, typed as the new `PostProxy::QuickReply`) and **`buttons`** (up to 3 attached to the message, each a `web_url` or `postback`, typed as `PostProxy::MessageButton`). An optional **`card`** (`PostProxy::MessageCard`: `subtitle`, `image_url`, `default_action` as `CardDefaultAction`) fills in the rest of the card carrying `buttons`, and requires them. Meta's equivalent of what Telegram has had via `reply_markup`. Each param takes model instances **or** plain hashes; models serialize with nils dropped.
- **`Message#tapped_action`** — set on inbound messages created by a tap, typed as the new `PostProxy::TappedAction` (`kind`, `payload`, `title`). Present on the `message.*` webhook payloads too, so you no longer dig through `platform_data` for the payload you set. Derived rather than stored, so it also resolves for taps recorded earlier, including Instagram ice-breaker taps and Telegram callback queries (`kind` `"callback_query"` — the one part of this that isn't Meta-only).
- `Message#quick_replies`, `Message#buttons`, and `Message#card`, echoing back what was sent. All four stay `nil` rather than `[]` when the API omits them.
- Quick-replies and buttons examples in `examples/manage_messages.rb` and the README's Direct Messages section.

### Notes

- Buttons are delivered as a Meta generic template and your `body` becomes its element title, so **`body` is capped at 80 characters when buttons are present** — Meta's limit, not ours; longer text is rejected with a `422` naming the length. Buttons cannot be combined with media.
- **Instagram is stricter than Messenger**: it delivers quick replies only on a plain-text message, so `quick_replies` with media or with `buttons` returns `422` on Instagram while both are accepted on Facebook.
- Meta-only — `quick_replies` / `buttons` / `card` return `422` on Telegram and Bluesky chats, where `reply_markup` remains the Telegram equivalent.
- Validation is server-side and names the offending index (e.g. `buttons[1].url must be an https:// URL`), surfacing as the usual error for a `422`. The SDK does not duplicate the limits.
- The new params are sent on the JSON path only. To combine quick replies with an attachment, pass `media` as a hosted URL rather than uploading via `media_files`.

## [1.12.0] - 2026-08-06

### Added

- **Post syncs & backfill.** `profiles.backfill_posts(id, from:)` walks a profile's feed backwards from the newest post and imports the history behind it; `profiles.post_syncs(id, trigger:, status:, page:, per_page:)` and `profiles.post_sync(id, post_sync_id)` expose every post pull — the one fired on connect, the recurring poll, and backfills — as the new `PostSync` type.
- **`comments.list_all(post_ids:, profiles:, from:, to:, page:, per_page:)`** — comments across every post in the profile group in one request. Flat: replies are their own entries linked by `parent_external_id`, typed as the new `BulkComment` (adds `post_id`, `profile_id`, `platform`).
- `from:` and `to:` on `comments.list`, filtering on when PostProxy received the comment.
- **Idempotency.** Every write method accepts `idempotency_key:`, sent as the `Idempotency-Key` header, so a dropped connection no longer forces a choice between a duplicate write and a lost one.
- `PostProxy::ConflictError` (409), raised for a duplicate submission (`response[:duplicate_post_id]`), a backfill already running (`response[:profile_sync_id]`), or an in-flight idempotency key. Previously these surfaced as a bare `PostProxy::Error`.
- **Instagram user tags.** `InstagramParams#user_tags` with the new `InstagramUserTag` type (`username`, `x`, `y`, `media_index`) — tag accounts on feed posts, reels, and stories.
- `StatsRecord#raw_stats` — every metric under its original platform name, alongside the normalized `stats`.
- `examples/backfill_posts.rb`, and cross-post comment listing in `examples/manage_comments.rb`.

### Changed

- LinkedIn post stats now normalize `likes`, `comments`, `shares`, and `clicks` alongside `impressions` (server-side; `stats` was already an open hash).
- `HUMAN_AGENT` is now approved on **both** Facebook and Instagram and extends the reply window to 7 days. `messages.send_message(chat_id, tag: "HUMAN_AGENT")` is unchanged — see the README for Meta's policy limits.

## [1.11.0] - 2026-07-14

### Added

- `profiles.ice_breakers(id)`, `profiles.set_ice_breakers(id, ice_breakers)`, and `profiles.delete_ice_breakers(id)` for managing Instagram DM ice breakers, with `IceBreaker` and `IceBreakersResponse` models.
- `profiles.assign_placement_to_group(id, placement_id:, target_profile_group_id:)` to move a placement (Facebook Page, Telegram channel, GBP location) to another profile group.
- `Placement#metadata` and `Placement#profile_group_id` attributes.
- Twitter polls: `TwitterParams` gains `poll_options` (2-4 choices, max 25 chars each) and `poll_duration_minutes` (5-10080) for `format: "poll"`.

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
