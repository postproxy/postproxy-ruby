require "postproxy"

client = PostProxy::Client.new("your-api-key", profile_group_id: "profile-group-id")

# Get stats for specific posts
stats = client.posts.stats(["post-id-1", "post-id-2"])

stats.data.each do |post_id, post_stats|
  puts "Post: #{post_id}"
  post_stats.platforms.each do |platform|
    puts "  #{platform.platform} (#{platform.profile_id}):"
    platform.records.each do |record|
      puts "    #{record.recorded_at}: #{record.stats}"
    end
  end
end

# Filter by network names
stats = client.posts.stats(
  ["post-id-1"],
  profiles: ["instagram", "twitter"]
)

# Filter by time range
stats = client.posts.stats(
  ["post-id-1"],
  from: "2026-02-01T00:00:00Z",
  to: "2026-02-24T00:00:00Z"
)

# Using Time objects for time range
stats = client.posts.stats(
  ["post-id-1"],
  from: Time.now - 86400 * 7,
  to: Time.now
)

# Combine all filters
stats = client.posts.stats(
  ["post-id-1", "post-id-2"],
  profiles: ["instagram", "prof-abc"],
  from: Time.now - 86400 * 30,
  to: Time.now
)

# Access specific metrics
stats.data.each do |post_id, post_stats|
  post_stats.platforms.each do |platform|
    latest = platform.records.last
    next unless latest

    puts "#{post_id} on #{platform.platform}:"
    puts "  Impressions: #{latest.stats[:impressions]}"
    puts "  Likes: #{latest.stats[:likes]}"
  end
end
