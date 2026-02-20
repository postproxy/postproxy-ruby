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

# Delete a post
client.posts.delete("post-id")
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
