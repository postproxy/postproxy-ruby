# Backfill a profile's older posts and follow the sync run to completion.

require "postproxy"

client = PostProxy::Client.new(
  ENV.fetch("POSTPROXY_API_KEY"),
  profile_group_id: ENV["POSTPROXY_PROFILE_GROUP_ID"]
)

profile_id = "your-profile-id"

# Start a backfill. It walks the profile's feed backwards from the newest post
# in batches of 25 and stops at `from` — or earlier, if the platform stops
# returning history. Runs in the background.
sync = begin
  client.profiles.backfill_posts(profile_id, from: "2025-01-01")
rescue PostProxy::ConflictError => e
  # Only one backfill runs per profile at a time; the running one already
  # covers any window a second request could ask for.
  running_id = e.response[:profile_sync_id]
  puts "Backfill already running: #{running_id}"
  client.profiles.post_sync(profile_id, running_id)
end

puts "Backfill #{sync.id} — status: #{sync.status}"

# Poll until it finishes.
while ["pending", "running"].include?(sync.status)
  sleep 5
  sync = client.profiles.post_sync(profile_id, sync.id)
  puts "  #{sync.status}: #{sync.posts_imported} imported of #{sync.posts_seen} seen, " \
       "reached back to #{sync.oldest_posted_at}"
end

if sync.status == "failed"
  warn "Backfill failed: #{sync.error}"
else
  puts "Done. Imported #{sync.posts_imported} posts, oldest #{sync.oldest_posted_at}"
end

# Every pull is recorded — the sync fired on connect, the recurring poll, and
# each backfill. Runs are kept for 30 days.
runs = client.profiles.post_syncs(profile_id, per_page: 10)
puts "\nRecent post syncs (#{runs.total}):"
runs.data.each do |run|
  puts "  #{run.created_at} #{run.trigger} → #{run.status} (#{run.posts_imported}/#{run.posts_seen} new)"
end
