require "postproxy"

client = PostProxy::Client.new("your-api-key", profile_group_id: "profile-group-id")

# Simple post
profiles = client.profiles.list.data

instagram_profile = profiles.find { |p| p.platform == "instagram" }

# Post with media URLs
post = client.posts.create(
  "Check out this photo!",
  profiles: [instagram_profile.id],
  media: ["https://example.com/photo.jpg"],
  draft: true
)

# puts "Draft: #{post.id} (#{post.status})"

# Publish draft
published = client.posts.publish_draft(draft.id)
puts "Published: #{published.status}"

# Post with local file upload
post = client.posts.create(
  "Local upload!",
  profiles: [instagram_profile.id],
  media_files: ["./image.jpg"],
  draft: true
)

puts "Draft: #{post.id} (#{post.status})"

# Scheduled post
post = client.posts.create(
  "Scheduled post",
  profiles: [profiles.first.id],
  scheduled_at: (Time.now + 3600).iso8601
)
puts "Scheduled: #{post.id} (#{post.status})"

tiktok_profile = profiles.find { |p| p.platform == "tiktok" }

# Cross-platform with platform-specific params
platform_params = PostProxy::PlatformParams.new(
  instagram: PostProxy::InstagramParams.new(format: "post", first_comment: "First!", collaborators: ["@friend"]),
  tiktok: PostProxy::TikTokParams.new(format: "image", privacy_status: "PUBLIC_TO_EVERYONE", auto_add_music: true),
)

post = client.posts.create(
  "Cross-platform post!",
  profiles: [instagram_profile.id, tiktok_profile.id],
  media: ["https://example.com/photo.jpg"],
  platforms: platform_params,
  draft: true
)
puts "Cross-platform post: #{post.id}"

# Thread post
twitter_profile = profiles.find { |p| p.platform == "twitter" }

thread_post = client.posts.create(
  "Here's a thread about PostProxy 🧵",
  profiles: [twitter_profile.id],
  thread: [
    { body: "First, connect your social accounts." },
    { body: "Then, create posts with media!", media: ["https://example.com/demo.jpg"] },
    { body: "Finally, schedule or publish instantly." },
  ]
)
puts "Thread post: #{thread_post.id} (#{thread_post.thread.length} children)"
