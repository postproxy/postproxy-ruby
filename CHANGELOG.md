# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.15.0] - 2026-10-30

### Added

- **Thread control (Facebook & Instagram).** `chats.pass_thread_control(chat_id, target_app_id:, metadata:)`, `take_thread_control`, `release_thread_control` and `request_thread_control` (each takes `metadata:` and returns the `Chat`, whose `metadata[:thread_control]` holds the owner), plus `chats.thread_owner` (`ThreadOwner`: `app_id`, `expires_at`).
- **Instagram collaboration invites** (Facebook login): `profiles.instagram_collaboration_invites(id, after:)` (`InstagramCollaborationInvitesResponse` / `InstagramCollaborationInvite`), `accept_instagram_collaboration_invite` and `decline_instagram_collaboration_invite` (`InstagramCollaborationInviteResult`).
- **Pinterest boards:** `profiles.create_pinterest_board(id, name, description:, privacy:)` returns the new `Placement`; `profiles.delete_pinterest_board(id, board_id)` (`PinterestBoardDeleted`). Constant `PINTEREST_BOARD_PRIVACIES`.
- **YouTube playlists:** `profiles.youtube_playlists(id, page_token:)` (`YouTubePlaylistsResponse`), `create_youtube_playlist`, `update_youtube_playlist` (`YouTubePlaylist`) and `delete_youtube_playlist` (`YouTubePlaylistDeleted`).
- **Google Business:** `google_business.search_keywords(profile_id, location_id, from_month:, to_month:)` returns a typed `SearchKeywordsResponse` (`SearchKeywordsMonth`, `SearchKeyword`) — unlike the other Google Business methods, the response is PostProxy-shaped.
- **Post params:** `InstagramParams` gains `disable_comment`, `location_id` and (reels) `share_to_feed`; `LinkedInParams` gains `document_title` and `first_comment`; `YouTubeParams` gains `playlist_id`.
- **Webhooks:** `profile_comment.edited` (`ProfileCommentCreatedData`), `chat.thread_control_changed` (`ThreadControlChangedEventData`) and `chat.thread_control_requested` (`ThreadControlRequestedEventData`). `ProfileEventData` gains `error` and `error_details` (`ErrorDetails`), set on `profile.disconnected`.
- Examples: `youtube_playlists.rb`, `thread_control.rb`; search keywords in `google_business.rb`.

### Changed

- `messages.send_message(reply_to_external_id:)` now also works on Instagram chats.

## [1.14.0] - 2026-10-20

### Added

- **WhatsApp.** `"whatsapp"` joins `PLATFORMS`. DMs: `chats.create` takes `placement_id:` (the phone number id, required for WhatsApp), and `messages.send` takes `template:` (`PostProxy::MessageTemplateInput`: `id` or `name` + `language`, `variables`, `button_params`, `header_media`, `header_location`), `interactive:`, `location:` (`PostProxy::MessageLocation`), `contacts:`, plus the send options `category:`, `link_preview:`, `voice_note:` and `filename:`. `Chat` gains `external_placement_id`, `group` and `within_messaging_window`; `Message` gains `template` (`MessageTemplateRef`), `interactive`, `location`, `contacts` and `error_details`.
- **`client.whatsapp_templates`** — `list`, `get`, `create`, `update`, `delete`, `library` for message templates (`PostProxy::WhatsAppTemplate`). Template ids/names are URL-encoded.
- **`client.whatsapp`** — number administration: `number_info`, `register_phone_number`, `request_verification_code`, `verify_phone_number`, `business_profile`, `update_business_profile`, `update_business_profile_photo`, `display_name`, `request_display_name_change`, `username`, `set_username`, `delete_username`, `username_suggestions`, blocked users (`blocked_users`, `blocked_user_status`, `block_users`, `unblock_users`), groups (`groups`, `create_group`, `group`, `update_group`, `delete_group`, `add_group_participants`, `remove_group_participants`, `create_group_invite_link`, `group_join_requests`, `approve_group_join_requests`, `reject_group_join_requests`), conversions (`dataset`, `create_dataset`, `send_conversion_event`) and `media`, which returns a `PostProxy::RawResponse` (`data` bytes + `content_type`). Responses are Meta's payloads as hashes.
- **`client.google_business`** — manage a Google Business location's own data: `location`, `update_location`, `available_location_categories`, `update_hours`, `attributes`, `available_attributes`, `update_attributes`, `service_list`, `update_service_list`, `food_menus`, `update_food_menus`, `place_action_links`, `available_place_action_types`, `create_place_action_link`, `update_place_action_link`, `delete_place_action_link`, `media`, `create_media`, `delete_media`. Google's camelCased payloads pass through as hashes.
- **`client.placements`** (`list`, `set_active_profile`, returning `AccountPlacement`) and **`client.api_keys`** (`list`, `create`, `delete`, returning `ApiKey`) — account-wide keys only.
- **Profiles:** `assign_to_group`, `daily_stats` (with `attribution:`; `DailyStatsResponse` / `DailyStats` / `DailyStatsRecord`, whose per-platform metrics read as `record[:impressions]`), `follower_history` (`FollowerHistoryResponse`), `participant_status` (Instagram, `ParticipantStatus`), `resolve_mention` (LinkedIn, `ResolvedMention`), `instagram_available_audio`, `facebook_page` / `update_facebook_page`, and chat backfill — `backfill_chats`, `chat_syncs`, `chat_sync` (`ChatSync`). `Profile` gains `username`, `platform_id`, `platform_url`, `avatar_url`, `inactive_reason` and `placements_sync_status`; `Placement` gains `avatar_url`; `PostSync` gains `placement_id`.
- **Comments:** `edit` (Facebook, YouTube), `pin` / `unpin` (TikTok), `private_reply` accepts `quick_replies:`, `buttons:`, `card:` and `elements:`, and `list_all` accepts `placement_id:`. `Comment` and `BulkComment` gain `external_edited_at`.
- **Chats:** `mark_read`, `start_typing`, `stop_typing`.
- **Carousels:** `messages.send(elements:)` with the new `PostProxy::MessageElement` (up to 10 cards, Facebook and Instagram). `Message#elements` and `Message#story_reply`.
- **Post params:** `alt_text` (string or per-media array) on Facebook, Instagram, LinkedIn, Bluesky, Threads, Pinterest and Twitter; `made_with_ai` on Instagram and Facebook; Facebook `link` and `countries`; LinkedIn `format: "poll"` with `poll_question` / `poll_options` / `poll_duration_days`, plus `countries` and `reshare_urn`; Threads `topic_tag`; TikTok `upload_as_draft`, `cover_url`, `thumb_offset`; Instagram `audio_id`, `audio_volume`, `video_volume`, `strip_audio`.
- **`cover_file`** on Instagram, TikTok, YouTube and Pinterest params: a local path is uploaded with the post (the request switches to multipart even without `media_files`); a base64 data URL is sent as-is. Works on `posts.create` and `posts.update`.
- `posts.create(skip_duplicate_check: true)` sends `X-Skip-Duplicate-Check`. `media` items may be `{ url: }` hashes as well as strings.
- `PlatformResult` gains `profile_id`, `profile_name`, `permalink` and `attachments` (`PlatformAttachment`); `ThreadChild` gains `platforms`, so you can see whether each item in a thread went out. `Post` gains `draft` and `source`.
- `profile_groups.initialize_connection` takes `onboarding:` (`"instagram"` / `"facebook"` for Instagram, `"api"` / `"business_app"` for WhatsApp) and `refresh_connection:`.
- **Webhooks:** `platform_post.edited`, `platform_post.edit_failed`, `profile.placements_synced`, `placement.orphaned`, `placement.restored`, `comment.delivery_unconfirmed`, `comment.edited`, `comment.edit_failed`, `profile_comment.deleted`, `message_template.status_updated`, `message_template.category_updated`, `placement.name_status_updated`, `placement.quality_updated` and `whatsapp.automatic_event`, plus the previously missing `comment.failed`, `comment.failed_waiting_for_retry`, `profile_comment.failed`, `profile_comment.failed_waiting_for_retry` and `referral.received`. `WebhookEvents.parse` raised `WebhookParseError` on these before. New typed payloads: `PlacementEventData`, `PlacementsSyncedData`, `WebhookChatData`, `ReferralEventData`, `MessageTemplateEventData`, `WhatsAppAutomaticEventData`; `ProfileEventData` gains `platform_id` and `origin`, `CommentCreatedData` gains `profile_id`, `error`, `error_details` and `external_edited_at`, `ProfileCommentCreatedData` gains `error`, `error_details` and `permalink`.
- `PostProxy::ForbiddenError` (403 — account canceled or past due, or the platform refused) and `PostProxy::RateLimitError` (429, with `retry_after` from the `Retry-After` header). Both subclass `PostProxy::Error`.
- Constants: `INSTAGRAM_TRIAL_STRATEGIES`, `INSTAGRAM_AUDIO_TYPES`, `CONNECTION_ONBOARDINGS`, `DAILY_STATS_ATTRIBUTIONS`, `PROFILE_INACTIVE_REASONS`, `POST_SYNC_TRIGGERS`, `POST_SYNC_STATUSES`; `LINKEDIN_FORMATS` gains `poll`.
- Examples: `google_business.rb`, `whatsapp_templates.rb`, `whatsapp_groups.rb`, `dm_carousel.rb`, `edit_published_post.rb`; a `cover_file` post in `create_post.rb` and onboarding options in `initialize_connection.rb`.

### Changed

- `InstagramParams#trial_strategy` takes `"MANUAL"` or `"SS_PERFORMANCE"` (documented; the API never accepted a boolean).
- `posts.update` on a **published** post now edits it on the platforms: only `body`, `platforms.youtube.title`, `platforms.pinterest.title` and `platforms.pinterest.destination_link` may change.

### Fixed

- Multipart requests sent repeated fields as `profiles[][]` / `media[][]` (read by Rails as nested arrays); they now go out as `profiles[]` / `media[]`. Array platform params (e.g. `alt_text`) are sent as `[]` parts and arrays of hashes (e.g. Instagram `user_tags`) with indexed keys, instead of their `to_s`.

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
