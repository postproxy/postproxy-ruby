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
rescue PostProxy::ValidationError => e
  puts "Invalid: #{e.message}"            # 422
rescue PostProxy::BadRequestError => e
  puts "Bad request: #{e.message}"        # 400
rescue PostProxy::Error => e
  puts "Error #{e.status_code}: #{e.message}"
  puts e.response  # parsed response body
end
```

## License

MIT
