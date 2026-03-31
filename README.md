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
```

## Profiles

```ruby
# List profiles
profiles = client.profiles.list.data

# Get a profile
profile = client.profiles.get("prof-id")

# Get placements for a profile
placements = client.profiles.placements("prof-id").data

# Delete a profile
client.profiles.delete("prof-id")
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
  twitter: PostProxy::TwitterParams.new(format: "post")
)

post = client.posts.create(
  "Cross-platform!",
  profiles: ["prof-1", "prof-2"],
  platforms: platforms
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
