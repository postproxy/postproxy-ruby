require "postproxy"

client = PostProxy::Client.new(
  ENV.fetch("POSTPROXY_API_KEY"),
  profile_group_id: ENV["POSTPROXY_PROFILE_GROUP_ID"]
)

# A DM-capable profile (facebook/instagram/telegram/bluesky)
profile_id = "your-profile-id"

# List existing chats for a profile (most recent first)
chats = client.chats.list(profile_id, per_page: 20)
puts "Total chats: #{chats.total}"
chats.data.each do |chat|
  puts "  #{chat.participant_username || chat.participant_external_id}: #{chat.last_message_at}"
end

# Find or create a chat with a participant (idempotent)
chat = client.chats.create(profile_id, "igsid_8675309", participant_username: "jane_doe")
puts "Chat: #{chat.id} (platform: #{chat.platform})"

# Get a single chat
chat = client.chats.get(chat.id)

# List messages in the chat (filter by direction/status)
messages = client.messages.list(chat.id, direction: "inbound")
messages.data.each do |msg|
  puts "  [#{msg.direction}] #{msg.body}"
  msg.attachments.each { |att| puts "    attachment: #{att.type} -> #{att.url}" }
end

# Send a text message (within the 24h window)
sent = client.messages.send(chat.id, body: "Yes, we ship worldwide!")
puts "Sent message: #{sent.id} (status: #{sent.status})"

# Send outside the 24h window with a tag (Facebook/Instagram)
client.messages.send(chat.id, body: "Following up on your order.", tag: "HUMAN_AGENT")

# Send an image by hosted URL
client.messages.send(chat.id, media: ["https://cdn.example.com/photo.png"])

# Send an image from a local file (multipart)
# client.messages.send(chat.id, media_files: ["./photo.png"])

# Telegram: reply threading + inline keyboard
# client.messages.send(
#   chat.id,
#   body: "Pick one:",
#   reply_markup: { inline_keyboard: [[{ text: "Track order", callback_data: "track:1" }]] }
# )

# React / unreact (Facebook & Instagram)
client.messages.react(sent.id, reaction: "love", emoji: "❤️")
client.messages.unreact(sent.id)

# Edit an outbound message (Telegram only)
# client.messages.edit(sent.id, body: "Updated answer.")

# Archive / unarchive a chat (Bluesky only)
# client.chats.archive(chat.id)
# client.chats.unarchive(chat.id)

# Private reply to a comment's author (Instagram/Facebook) — returns a Message
reply = client.comments.private_reply(
  "your-post-id", "comment-id",
  profile_id: profile_id,
  text: "Thanks — DM-ing you the details."
)
puts "Private reply queued: #{reply.id} (chat: #{reply.chat_id})"
