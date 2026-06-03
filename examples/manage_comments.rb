require "postproxy"

client = PostProxy::Client.new(
  ENV.fetch("POSTPROXY_API_KEY"),
  profile_group_id: ENV["POSTPROXY_PROFILE_GROUP_ID"]
)

post_id = "your-post-id"
profile_id = "your-profile-id"

# List comments on a post
comments = client.comments.list(post_id, profile_id: profile_id)
puts "Total comments: #{comments.total}"
comments.data.each do |comment|
  puts "  #{comment.author_username}: #{comment.body}"
  comment.replies.each do |reply|
    puts "    #{reply.author_username}: #{reply.body}"
  end
end

# Create a comment
new_comment = client.comments.create(post_id, "Thanks for the feedback!", profile_id: profile_id)
puts "Created: #{new_comment.id} (status: #{new_comment.status})"

# Reply to a comment
reply = client.comments.create(post_id, "Glad you liked it!", profile_id: profile_id, parent_id: new_comment.id)
puts "Reply: #{reply.id}"

# Hide / unhide
client.comments.hide(post_id, new_comment.id, profile_id: profile_id)
puts "Comment hidden"

client.comments.unhide(post_id, new_comment.id, profile_id: profile_id)
puts "Comment unhidden"

# Like / unlike
client.comments.like(post_id, new_comment.id, profile_id: profile_id)
puts "Comment liked"

client.comments.unlike(post_id, new_comment.id, profile_id: profile_id)
puts "Comment unliked"

# Synced comments may carry media attachments and author metadata
fetched = client.comments.get(post_id, new_comment.id, profile_id: profile_id)
fetched.attachments.each { |att| puts "  attachment: #{att.type} -> #{att.url} (#{att.status})" }
puts "  follower_count: #{(fetched.metadata || {})[:follower_count]}" if fetched.metadata

# Private reply to a comment's author (Instagram/Facebook) — returns a Message
message = client.comments.private_reply(
  post_id, new_comment.id,
  profile_id: profile_id,
  text: "Thanks — DM-ing you the details."
)
puts "Private reply queued: #{message.id} (chat: #{message.chat_id})"

# Delete
client.comments.delete(post_id, new_comment.id, profile_id: profile_id)
puts "Comment deleted"
