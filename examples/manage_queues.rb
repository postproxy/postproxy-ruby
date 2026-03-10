require "postproxy"

API_KEY = ENV.fetch("POSTPROXY_API_KEY")
PROFILE_GROUP_ID = ENV.fetch("POSTPROXY_PROFILE_GROUP_ID")

client = PostProxy::Client.new(API_KEY, profile_group_id: PROFILE_GROUP_ID)

# Create a queue with weekday morning timeslots
queue = client.queues.create(
  "Morning Posts",
  profile_group_id: PROFILE_GROUP_ID,
  description: "Weekday morning content",
  timezone: "America/New_York",
  jitter: 10,
  timeslots: [
    { day: 1, time: "09:00" },
    { day: 2, time: "09:00" },
    { day: 3, time: "09:00" },
    { day: 4, time: "09:00" },
    { day: 5, time: "09:00" },
  ]
)
puts "Created queue: #{queue.id} #{queue.name}"
puts "Timeslots: #{queue.timeslots.length}"

# List all queues
queues = client.queues.list.data
puts "All queues: #{queues.map(&:name)}"

# Get next available slot
next_slot = client.queues.next_slot(queue.id)
puts "Next slot: #{next_slot.next_slot}"

# Add a post to the queue
profiles = client.profiles.list.data
post = client.posts.create(
  "This post will be scheduled by the queue",
  profiles: [profiles.first.id],
  queue_id: queue.id,
  queue_priority: "high"
)
puts "Queued post: #{post.id} scheduled at: #{post.scheduled_at}"

# Update the queue — add a timeslot and change jitter
updated = client.queues.update(queue.id, jitter: 15, timeslots: [{ day: 6, time: "10:00" }])
puts "Updated queue timeslots: #{updated.timeslots.length}"

# Pause the queue
paused = client.queues.update(queue.id, enabled: false)
puts "Queue paused: #{!paused.enabled}"

# Delete the queue
deleted = client.queues.delete(queue.id)
puts "Deleted: #{deleted.deleted}"
