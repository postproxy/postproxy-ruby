# PostProxy Ruby SDK

Ruby client for the [PostProxy API](https://postproxy.dev) — manage social media posts, profiles, and profile groups.

## Installation

```bash
gem install postproxy-sdk
```

Or add to your Gemfile:

```ruby
gem "postproxy-sdk"
```

## Quick Start

```ruby
require "postproxy"

client = PostProxy::Client.new("your-api-key", profile_group_id: "pg-abc")

profiles = client.profiles.list.data
post = client.posts.create(
  "Hello from PostProxy!",
  profiles: [profiles.first.id]
)
puts post.id, post.status
```

## Client

```ruby
# Basic
client = PostProxy::Client.new("your-api-key")

# With default profile group
client = PostProxy::Client.new("your-api-key", profile_group_id: "pg-abc")

# With custom base URL
client = PostProxy::Client.new("your-api-key", base_url: "https://custom.api.dev")

# With custom Faraday client
faraday = Faraday.new(url: "https://api.postproxy.dev") do |f|
  f.request :retry
  f.headers["Authorization"] = "Bearer your-api-key"
  f.adapter :net_http
end
client = PostProxy::Client.new("your-api-key", faraday_client: faraday)
```

### Idempotency

Every write method (`POST`/`PUT`/`PATCH`/`DELETE`) accepts an `idempotency_key:`, sent as
the `Idempotency-Key` header. If the connection drops before you see the response, retry
with the same key and you get the original response back instead of a second post:

```ruby
require "securerandom"

key = SecureRandom.uuid
post = client.posts.create("Hello", profiles: ["profile-id"], idempotency_key: key)

# Retrying the same call with the same key replays the original response.
```

Generate a fresh key per logical operation — a UUID is ideal. Keys are scoped to your
account and may be up to 255 characters. The SDK never generates keys or retries for you.

| Situation | Result |
|---|---|
| First request with the key | Runs normally |
| Retry after a success | Original status and body replayed |
| Retry while the first is still running | `ConflictError` (409) — wait and retry |
| Same key, different request body | `ValidationError` (422) |
| Retry after an error response | Runs normally — errors are not replayed |

Only successful (`2xx`) responses are stored, so a request that failed validation or hit a
quota leaves the key free — fix the payload and retry with the same key. Stored responses
are kept for **24 hours**. Requests without a key are unaffected.

## Posts

```ruby
# List posts (paginated)
result = client.posts.list(page: 1, per_page: 10, status: "processed")
result.data    # => [Post, ...]
result.total   # => 42
result.page    # => 1

# Get a single post
post = client.posts.get("post-id")

# Create a post
post = client.posts.create("Hello!", profiles: ["prof-1", "prof-2"])

# Create with media URLs
post = client.posts.create(
  "Check this out!",
  profiles: ["prof-1"],
  media: ["https://example.com/image.jpg"]
)

# Create with local file uploads
post = client.posts.create(
  "Uploaded!",
  profiles: ["prof-1"],
  media_files: ["/path/to/photo.jpg"]
)

# Create a draft
draft = client.posts.create("Draft", profiles: ["prof-1"], draft: true)

# Publish a draft
post = client.posts.publish_draft("post-id")

# Schedule a post
post = client.posts.create(
  "Later!",
  profiles: ["prof-1"],
  scheduled_at: (Time.now + 3600).iso8601
)

# Create a thread post
post = client.posts.create(
  "Thread starts here",
  profiles: ["prof-1"],
  thread: [
    { body: "Second post in the thread" },
    { body: "Third with media", media: ["https://example.com/img.jpg"] },
  ]
)
post.thread.each { |child| puts "#{child.id}: #{child.body}" }

# Delete a post
client.posts.delete("post-id")

# Delete a post and also remove it from social platforms
client.posts.delete("post-id", delete_on_platform: true)

# Delete from platforms only (keeps DB record). Defaults to all platforms.
client.posts.delete_on_platform("post-id")
# Target a single network
client.posts.delete_on_platform("post-id", network: "twitter")
# Target a specific profile
client.posts.delete_on_platform("post-id", profile_id: "prof-abc")
# Target a specific post profile (covers entire thread for that profile)
client.posts.delete_on_platform("post-id", post_profile_id: "pp-abc")
```

## Post Stats

Retrieve stats snapshots for posts over time. Supports filtering by profiles/networks and timespan.

```ruby
# Get stats for one or more posts
stats = client.posts.stats(["post-id-1", "post-id-2"])
stats.data.each do |post_id, post_stats|
  post_stats.platforms.each do |platform|
    puts "#{post_id} on #{platform.platform} (#{platform.profile_id}):"
    platform.records.each do |record|
      puts "  #{record.recorded_at}: #{record.stats}"
    end
  end
end

# Filter by profiles or networks
stats = client.posts.stats(["post-id"], profiles: ["instagram", "twitter"])

# Filter by profile hashids
stats = client.posts.stats(["post-id"], profiles: ["prof-abc", "prof-def"])

# Filter by time range
stats = client.posts.stats(
  ["post-id"],
  from: "2026-02-01T00:00:00Z",
  to: "2026-02-24T00:00:00Z"
)

# Using Time objects
stats = client.posts.stats(
  ["post-id"],
  from: Time.now - 86400 * 7,
  to: Time.now
)
```

Stats vary by platform:

| Platform | Fields |
|----------|--------|
| Instagram | `impressions`, `likes`, `comments`, `saved`, `profile_visits`, `follows` |
| Facebook | `impressions`, `clicks`, `likes` |
| Threads | `impressions`, `likes`, `replies`, `reposts`, `quotes`, `shares` |
| Twitter | `impressions`, `likes`, `retweets`, `comments`, `quotes`, `saved` |
| YouTube | `impressions`, `likes`, `comments`, `saved` |
| LinkedIn | `impressions` |
| TikTok | `impressions`, `likes`, `comments`, `shares` |
| Pinterest | `impressions`, `likes`, `comments`, `saved`, `outbound_clicks` |

## Queues

```ruby
# List all queues
queues = client.queues.list.data

# Get a queue
queue = client.queues.get("queue-id")

# Get next available slot
next_slot = client.queues.next_slot("queue-id")
puts next_slot.next_slot

# Create a queue with timeslots
queue = client.queues.create(
  "Morning Posts",
  profile_group_id: "pg-abc",
  description: "Weekday morning content",
  timezone: "America/New_York",
  jitter: 10,
  timeslots: [
    { day: 1, time: "09:00" },
    { day: 2, time: "09:00" },
    { day: 3, time: "09:00" },
  ]
)

# Update a queue
queue = client.queues.update("queue-id",
  jitter: 15,
  timeslots: [
    { day: 6, time: "10:00" },        # add new timeslot
    { id: 1, _destroy: true },         # remove existing timeslot
  ]
)

# Pause/unpause a queue
client.queues.update("queue-id", enabled: false)

# Delete a queue
client.queues.delete("queue-id")

# Add a post to a queue
post = client.posts.create(
  "This post will be scheduled by the queue",
  profiles: ["prof-1"],
  queue_id: "queue-id",
  queue_priority: "high"
)
```

## Webhooks

```ruby
# List webhooks
webhooks = client.webhooks.list.data

# Get a webhook
webhook = client.webhooks.get("wh-id")

# Create a webhook
webhook = client.webhooks.create(
  "https://example.com/webhook",
  events: ["post.published", "post.failed"],
  description: "My webhook"
)
puts webhook.id, webhook.secret

# Update a webhook
webhook = client.webhooks.update("wh-id", events: ["post.published"], enabled: false)

# Delete a webhook
client.webhooks.delete("wh-id")

# List deliveries
deliveries = client.webhooks.deliveries("wh-id", page: 1, per_page: 10)
deliveries.data.each { |d| puts "#{d.event_type}: #{d.success}" }
```

### Signature verification

Verify incoming webhook signatures using HMAC-SHA256:

```ruby
PostProxy::WebhookSignature.verify(
  payload: request.body.read,
  signature_header: request.headers["X-PostProxy-Signature"],
  secret: "whsec_..."
)
```

### Event types and typed payloads

Subscribe to any of these events (or pass `["*"]` for all):

`post.processed`, `post.imported`, `platform_post.published`, `platform_post.failed`, `platform_post.failed_waiting_for_retry`, `platform_post.insights`, `profile.connected`, `profile.disconnected`, `profile.stats`, `media.failed`, `comment.created`, `profile_comment.created`, `message.received`, `message.sent`, `message.delivered`, `message.read`, `message.edited`, `message.deleted`, `message.failed_waiting_for_retry`, `message.failed`, `reaction.received`.

`PostProxy::WebhookEvents.parse` validates the envelope and returns a typed `Event` — `event.data` is the right model for the event:

```ruby
event = PostProxy::WebhookEvents.parse(request.body.read)
case event.type
when "profile.stats"
  puts "#{event.data.profile_id}: #{event.data.stats}"
when "platform_post.published"
  puts "Published: #{event.data.platform_id}"
when "comment.created"
  puts "#{event.data.author_username}: #{event.data.body}"
when "message.received"
  # MessageEventData — event.data.message is a full Message
  puts "DM from #{event.data.message.chat_id}: #{event.data.message.body}"
when "reaction.received"
  # ReactionEventData
  puts "#{event.data.action}: #{event.data.reaction} on #{event.data.message.id}"
when "profile_comment.created"
  # ProfileCommentCreatedData
  puts "#{event.data.author_username}: #{event.data.body}"
end
```

The direct-message events (`message.*`) carry a `MessageEventData` (`data.message` is a full `Message`); `reaction.received` carries a `ReactionEventData`; `profile_comment.created` carries a `ProfileCommentCreatedData`.

## Comments

```ruby
# List comments on a post (paginated)
comments = client.comments.list("post-id", profile_id: "profile-id")
comments.data.each do |comment|
  puts "#{comment.author_username}: #{comment.body}"
  comment.replies.each do |reply|
    puts "  #{reply.author_username}: #{reply.body}"
  end
end

# List with pagination
comments = client.comments.list("post-id", profile_id: "profile-id", page: 2, per_page: 10)

# Filter by when PostProxy received the comment (created_at, not posted_at).
# A bare date means that date's start of day. Applies to top-level comments —
# one in range brings its full replies array with it.
recent = client.comments.list("post-id",
  profile_id: "profile-id",
  from: "2026-03-25",
  to: "2026-03-26T12:00:00Z"
)

# Get a single comment
comment = client.comments.get("post-id", "comment-id", profile_id: "profile-id")

# Create a comment
comment = client.comments.create("post-id", profile_id: "profile-id", text: "Great post!")

# Reply to a comment
reply = client.comments.create("post-id", profile_id: "profile-id", text: "Thanks!", parent_id: "comment-id")

# Delete a comment
result = client.comments.delete("post-id", "comment-id", profile_id: "profile-id")
puts result.accepted  # true

# Hide / unhide a comment
client.comments.hide("post-id", "comment-id", profile_id: "profile-id")
client.comments.unhide("post-id", "comment-id", profile_id: "profile-id")

# Like / unlike a comment
client.comments.like("post-id", "comment-id", profile_id: "profile-id")
client.comments.unlike("post-id", "comment-id", profile_id: "profile-id")

# Synced comments may carry media attachments and author metadata
comment = client.comments.get("post-id", "comment-id", profile_id: "profile-id")
comment.attachments.each { |att| puts "#{att.type} #{att.url} (#{att.status})" }
puts comment.metadata[:follower_count] if comment.metadata

# Private reply to a comment's author (Instagram/Facebook) — returns a Message
message = client.comments.private_reply("post-id", "comment-id", profile_id: "profile-id", text: "DM-ing you the details.")
puts message.chat_id, message.status
```

### Comments across posts

`comments.list_all` returns comments spanning every post in the profile group in one
request — the comments counterpart to `posts.stats`. Every filter is optional.

**This list is flat.** Unlike the per-post list, replies are not nested: every comment,
top-level or reply, is its own entry linked to its parent by `parent_external_id`, so
`total` counts every comment and paging is exact.

```ruby
all = client.comments.list_all(
  profiles: ["instagram", "prof-abc"],  # profile IDs or network names, mixed
  post_ids: ["post-1", "post-2"],       # omit for every post in scope
  from: "2026-03-25",
  per_page: 50                          # max 100
)

all.data.each do |c|
  # Each entry says where it came from, so you can act on it with the
  # post-scoped methods above.
  puts "#{c.platform} #{c.post_id} #{c.profile_id}: #{c.body}"
  puts "  ↳ reply to #{c.parent_external_id}" if c.parent_external_id
end

# Reply to one of them
first = all.data.first
client.comments.create(first.post_id, "Thanks!", profile_id: first.profile_id, parent_id: first.id)
```

Unknown or out-of-scope IDs in `post_ids` and `profiles` are ignored rather than erroring.
Results are ordered newest first by receipt time.

## Direct Messages

Read and send 1:1 messages on DM-capable profiles (Facebook Messenger, Instagram, Telegram, Bluesky). A conversation is a **Chat**; it holds **Messages**. Outbound sends are processed asynchronously (`status` starts as `pending`).

```ruby
# List chats for a profile (paginated, most recent first)
chats = client.chats.list("profile-id", per_page: 20)
chats.data.each { |chat| puts "#{chat.participant_username}: #{chat.last_message_at}" }

# Find or create a chat with a participant (idempotent)
chat = client.chats.create("profile-id", "igsid_8675309", participant_username: "jane_doe")

# Get a single chat
chat = client.chats.get(chat.id)

# List messages in a chat (filter by direction/status)
messages = client.messages.list(chat.id, direction: "inbound")
messages.data.each do |msg|
  puts "#{msg.direction}: #{msg.body}"
  msg.attachments.each { |att| puts "  #{att.url}" }
end

# Send a text message (within the 24h window)
sent = client.messages.send(chat.id, body: "Yes, we ship worldwide!")

# Send outside the 24h window with a tag (Facebook/Instagram)
client.messages.send(chat.id, body: "Following up.", tag: "HUMAN_AGENT")

# Send media — by hosted URL or local file
client.messages.send(chat.id, media: ["https://cdn.example.com/photo.png"])
client.messages.send(chat.id, media_files: ["./photo.png"])

# Telegram: reply threading + inline keyboard
client.messages.send(
  chat.id,
  body: "Pick one:",
  reply_markup: { inline_keyboard: [[{ text: "Track order", callback_data: "track:1" }]] }
)

# Get / edit (Telegram only) a message
msg = client.messages.get(sent.id)
client.messages.edit(sent.id, body: "Updated answer.")

# React / unreact (Facebook & Instagram)
client.messages.react(sent.id, reaction: "love", emoji: "❤️")
client.messages.unreact(sent.id)

# Archive / unarchive a chat (Bluesky only)
client.chats.archive(chat.id)
client.chats.unarchive(chat.id)

# Private reply to a comment's author (Instagram/Facebook) — returns a Message
message = client.comments.private_reply("post-id", "comment-id", profile_id: "profile-id", text: "DM-ing you the details.")
puts message.chat_id, message.status
```

### Quick replies and buttons (Facebook & Instagram)

Meta's two interactive primitives. **Quick replies** are chips above the participant's
composer that disappear once tapped; **buttons** are attached to the message and stay in
the thread. Telegram's equivalent is `reply_markup` above — passing `quick_replies` or
`buttons` on a Telegram or Bluesky chat returns `422`.

Each param accepts model instances or plain hashes, whichever you prefer:

```ruby
# Quick replies — up to 13. title ≤ 20 chars, payload ≤ 1000.
client.messages.send(
  chat.id,
  body: "What can I help with?",
  quick_replies: [
    PostProxy::QuickReply.new(title: "Track order", payload: "TRACK"),
    { title: "Talk to support", payload: "HELP" }
  ]
)

# Buttons — up to 3, each either web_url or postback. card is optional and
# requires buttons.
client.messages.send(
  chat.id,
  body: "Your order shipped",
  buttons: [
    PostProxy::MessageButton.new(type: "web_url", title: "Track", url: "https://shop.example.com/o/123"),
    PostProxy::MessageButton.new(type: "postback", title: "Cancel", payload: "CANCEL:123")
  ],
  card: PostProxy::MessageCard.new(
    subtitle: "Arriving Friday",
    image_url: "https://cdn.example.com/shoe.png",
    default_action: { type: "web_url", url: "https://shop.example.com/o/123" }
  )
)
```

Buttons are delivered as a Meta generic template and your `body` becomes the template's
element title — so **`body` is capped at 80 characters when buttons are present**. That is
Meta's limit, not PostProxy's, and a longer body is rejected with a `422` naming the
length. Buttons cannot be combined with media. Instagram is stricter than Messenger: it
delivers quick replies only on a plain-text message, so `quick_replies` with media or with
`buttons` returns `422` on Instagram while both are accepted on Facebook.

Validation happens server-side and names the offending index — `buttons[1].url must be an
https:// URL` — surfacing as the SDK's usual error for a `422`.

> The new params are sent on the JSON path only. To combine quick replies with an
> attachment, pass `media` as a hosted URL rather than uploading via `media_files`.

A tap comes back as an **inbound message** carrying `tapped_action`:

```ruby
inbound = client.messages.list(chat.id, direction: "inbound")
inbound.data.each do |msg|
  next unless msg.tapped_action

  # kind: "quick_reply", "postback", or "callback_query"
  puts "#{msg.tapped_action.kind}: #{msg.tapped_action.payload}"
end
```

Subscribe to `message.received` to react to taps as they happen — the same field is on the
webhook payload. `tapped_action` is derived rather than stored, so it also resolves for
taps recorded before PostProxy exposed it, including Instagram ice-breaker taps and
Telegram callback queries (`kind` `"callback_query"`). A tap also opens the 24h window.

## Profile comments (Google Business reviews)

Profile-level comments expose Google Business reviews and replies. Reviews are user-generated — the SDK lets you list/get them and reply to or delete your own replies. Reviews sync twice daily.

```ruby
# List reviews for a profile (paginated)
reviews = client.profile_comments.list("profile-id")
reviews.data.each do |review|
  rating = (review.platform_data || {})[:star_rating]
  puts "#{review.author_username} #{rating}: #{review.body}"
  review.replies.each { |r| puts "  reply: #{r.body}" }
end

# Filter by placement (location)
reviews = client.profile_comments.list("profile-id", placement_id: "accounts/123/locations/456")

# Get a single review
review = client.profile_comments.get("profile-id", "review-id")

# Reply to a review (parent_id is the review id)
reply = client.profile_comments.create("profile-id", parent_id: "review-id", text: "Thanks for visiting!")

# Delete your reply
client.profile_comments.delete("profile-id", "reply-id")
```

## Profiles

```ruby
# List profiles
profiles = client.profiles.list.data

# Get a profile
profile = client.profiles.get("prof-id")

# Get placements for a profile
placements = client.profiles.placements("prof-id").data

# Move a placement (e.g. a Facebook Page or Telegram channel) to another group
placement = client.profiles.assign_placement_to_group("prof-id",
  placement_id: "placement-external-id",
  target_profile_group_id: "pg-other"
)
puts placement.profile_group_id # => "pg-other"

# Ice breakers (Instagram DMs): FAQ prompts shown when a user opens a chat
result = client.profiles.ice_breakers("prof-id")
puts result.ice_breakers.map(&:question)

client.profiles.set_ice_breakers("prof-id", [
  { question: "What services do you offer?", payload: "services" },
  { question: "What are your hours?", payload: "hours" }
]) # 1-4 items

client.profiles.delete_ice_breakers("prof-id")

# Delete a profile
client.profiles.delete("prof-id")

# Profile stats timeseries — placement_id required for facebook, linkedin, telegram
stats = client.profiles.get_profile_stats("prof_li_001",
  placement_id: "108520199",
  from: "2026-04-01T00:00:00Z"
)
stats.data.records.each do |r|
  puts "#{r.recorded_at}: #{r.stats[:followerCount]}"
end

# Bluesky — no placements
bsky = client.profiles.get_profile_stats("prof_bsky_001")
puts bsky.data.records.last.stats[:followersCount]
```

Every stats record (post stats and profile stats alike) carries `raw_stats` alongside the
normalized `stats`, exposing each metric under its **original platform name**:

```ruby
stats = client.posts.stats(["post-id"])
record = stats.data["post-id"].platforms.first.records.first

puts record.stats[:impressions]          # normalized
puts record.raw_stats[:views]            # Instagram's own name
puts record.raw_stats[:impression_count] # Twitter/X's own name
```

LinkedIn post stats now normalize `likes`, `comments`, `shares`, and `clicks` alongside
`impressions` — previously only `impressions` was normalized.

### Post syncs & backfill

PostProxy mirrors posts published natively on a platform into your account. Every one of
those pulls is recorded as a **post sync**: the one fired when the profile connects, the
recurring poll, and any backfill you start.

```ruby
# Start a backfill — walks the feed backwards from the newest post in batches
# of 25 until it reaches `from` or the platform stops returning posts.
sync = client.profiles.backfill_posts("prof-id", from: "2025-01-01")
puts sync.id, sync.status # => "sync456def" "pending"

# Poll it to completion — finished when status is "completed" or "failed"
run = client.profiles.post_sync("prof-id", sync.id)
puts "#{run.posts_imported} of #{run.posts_seen}, back to #{run.oldest_posted_at}"

# List recent runs (kept for 30 days), newest first
runs = client.profiles.post_syncs("prof-id",
  trigger: "backfill",   # connect | scheduled | backfill
  status: "completed",   # pending | running | completed | failed
  per_page: 25
)
```

| `PostSync` field | Description |
|---|---|
| `id` | Sync identifier |
| `profile_id` | Profile this run belongs to |
| `kind` | Always `posts` today |
| `trigger` | `connect`, `scheduled`, or `backfill` |
| `status` | `pending`, `running`, `completed`, or `failed` |
| `started_at` / `completed_at` | `Time` or `nil` |
| `posts_seen` | Posts the platform returned across the run |
| `posts_imported` | Posts that were **new** and got created |
| `backfill_from` | The date floor requested; `nil` for `connect`/`scheduled` |
| `oldest_posted_at` | Publish date of the oldest post the run reached |
| `error` | Platform error message when `status` is `"failed"` |
| `created_at` | `Time` |

**How far back a backfill reaches depends on the platform's API**, not on PostProxy: where
history is pageable we follow it, otherwise the run ends early with whatever it got and
still reports `status == "completed"`.

Only one backfill runs per profile at a time — starting a second raises `ConflictError`
carrying the running one's id:

```ruby
begin
  client.profiles.backfill_posts("prof-id", from: "2025-01-01")
rescue PostProxy::ConflictError => e
  running_id = e.response[:profile_sync_id]
  # Poll the run that's already going.
end
```

Posts you already have are skipped, so overlapping backfills are safe. Imported posts
behave exactly like ones the poll picks up (`source: "imported"`, `post.imported`
webhook), but a backfill's follow-up work is queued at a lower priority so a deep run
can't slow down publishing.

## Profile Groups

```ruby
# List groups
groups = client.profile_groups.list.data

# Get a group
group = client.profile_groups.get("pg-id")

# Create a group
group = client.profile_groups.create("My Group")

# Delete a group
client.profile_groups.delete("pg-id")

# Initialize OAuth connection
connection = client.profile_groups.initialize_connection(
  "pg-id",
  platform: "instagram",
  redirect_url: "https://myapp.com/callback"
)
# Redirect user to connection.url

# BlueSky — app password (synchronous, no OAuth)
bsky = client.profile_groups.connect_bluesky("pg-id",
  identifier: "yourname.bsky.social",
  app_password: "xxxx-xxxx-xxxx-xxxx"
)
puts bsky.profile.id

# Telegram — bring-your-own-bot. Channels populate asynchronously; poll
# placements until non-empty.
tg = client.profile_groups.connect_telegram("pg-id",
  bot_token: "123456789:ABCdef-GhIJklMnOpQrStUvWxYz"
)
puts tg.next_step

placements = []
loop do
  placements = client.profiles.placements(tg.profile.id).data
  break unless placements.empty?
  sleep 3
end
puts "Channels: #{placements.map { |p| [p.id, p.name] }}"
```

## Platform Parameters

```ruby
platforms = PostProxy::PlatformParams.new(
  facebook: PostProxy::FacebookParams.new(
    format: "post",
    first_comment: "First!"
  ),
  instagram: PostProxy::InstagramParams.new(
    format: "reel",
    collaborators: ["@friend"],
    cover_url: "https://example.com/cover.jpg"
  ),
  tiktok: PostProxy::TikTokParams.new(
    privacy_status: "PUBLIC_TO_EVERYONE",
    auto_add_music: true
  ),
  linkedin: PostProxy::LinkedInParams.new(format: "post"),
  youtube: PostProxy::YouTubeParams.new(
    title: "My Video",
    privacy_status: "public"
  ),
  pinterest: PostProxy::PinterestParams.new(
    title: "My Pin",
    board_id: "board-123"
  ),
  threads: PostProxy::ThreadsParams.new(format: "post"),
  # Twitter also supports polls:
  # twitter: PostProxy::TwitterParams.new(format: "poll",
  #   poll_options: ["Yes", "No"], poll_duration_minutes: 1440),
  twitter: PostProxy::TwitterParams.new(format: "post"),
  bluesky: PostProxy::BlueskyParams.new(format: "post"),
  telegram: PostProxy::TelegramParams.new(
    chat_id: "-1001234567890",
    parse_mode: "HTML",
    disable_link_preview: true
  )
)

post = client.posts.create(
  "Cross-platform!",
  profiles: ["prof-1", "prof-2"],
  platforms: platforms
)
```

Supported platforms: `facebook`, `instagram`, `tiktok`, `linkedin`, `youtube`, `twitter`, `threads`, `pinterest`, `bluesky`, `telegram`, `google_business`. Telegram requires a `chat_id` per post — list channels with `client.profiles.placements(profile_id)`.

### Instagram user tags

Tag public Instagram accounts in a post — feed post, reel, or story:

```ruby
client.posts.create(
  "Shot on location",
  profiles: ["ig-profile-id"],
  media: [
    "https://example.com/1.jpg",
    "https://example.com/2.jpg",
    "https://example.com/3.mp4"
  ],
  platforms: PostProxy::PlatformParams.new(
    instagram: PostProxy::InstagramParams.new(
      format: "post",
      user_tags: [
        { username: "natgeo", x: 0.5, y: 0.4 },               # slide 0
        { username: "nasa", x: 0.2, y: 0.8, media_index: 1 },  # slide 1
        { username: "spacex", media_index: 2 }                 # video — username only
      ]
    )
  )
)
```

- **Images require `x` and `y`** — floats `0.0`–`1.0` measured from the top-left corner.
- **Reels and video slides** are tagged by username only; coordinates are ignored and dropped.
- **Stories** accept coordinates but don't need them.
- `media_index` picks the carousel slide (0-based, defaults to `0`, video slides included).
- A leading `@` on a username is stripped for you.

Coordinates outside `0.0`–`1.0`, a `media_index` past the last media item, or an image tag
missing `x`/`y` are rejected with a `ValidationError` naming the offending entry. Accounts
that are private or have tagging turned off are silently skipped by Instagram at publish
time.

### Google Business

Google Business posts use a `google_business` entry in `PlatformParams` (a plain hash; no typed struct). The `location_id` is the location resource path returned by `client.profiles.placements()`. Supported formats: `standard`, `event`, `offer`. CTA actions: `LEARN_MORE`, `BOOK`, `ORDER`, `SHOP`, `SIGN_UP`, `CALL`. Media is limited to one image (≤5 MB).

```ruby
client.posts.create(
  "Now open weekends!",
  ["gbp-profile-id"],
  media: ["https://example.com/store.jpg"],
  platforms: {
    google_business: {
      format: "standard",
      location_id: "accounts/123/locations/456",
      cta_action_type: "LEARN_MORE",
      cta_url: "https://example.com"
    }
  }
)
```

## Error Handling

```ruby
begin
  client.posts.get("bad-id")
rescue PostProxy::AuthenticationError => e
  puts "Auth failed: #{e.message}"       # 401
rescue PostProxy::NotFoundError => e
  puts "Not found: #{e.message}"          # 404
rescue PostProxy::ConflictError => e
  puts "Conflict: #{e.message}"           # 409
  puts e.response[:duplicate_post_id]     # on a duplicate post
  puts e.response[:profile_sync_id]       # on a backfill already running
rescue PostProxy::ValidationError => e
  puts "Invalid: #{e.message}"            # 422
rescue PostProxy::BadRequestError => e
  puts "Bad request: #{e.message}"        # 400
rescue PostProxy::Error => e
  puts "Error #{e.status_code}: #{e.message}"
  puts e.response  # parsed response body
end
```

| Status | Error | Raised for |
|---|---|---|
| 400 | `BadRequestError` | Missing required parameters |
| 401 | `AuthenticationError` | Invalid, missing, or insufficient API key permissions |
| 404 | `NotFoundError` | Resource does not exist or is not accessible |
| 409 | `ConflictError` | Duplicate submission, a backfill already running, or an in-flight `Idempotency-Key` |
| 422 | `ValidationError` | Validation failed |
| 429 | `Error` | Posting rate limit reached |

## License

MIT
