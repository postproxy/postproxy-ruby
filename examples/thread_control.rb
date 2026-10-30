require "postproxy"

client = PostProxy::Client.new(ENV.fetch("POSTPROXY_API_KEY"))

# Meta's own inbox apps
PAGE_INBOX_APP_ID = "263902037430900"
INSTAGRAM_INBOX_APP_ID = "1217981644879628"

# A Facebook or Instagram chat
chat_id = "your-chat-id"

# Who controls the conversation right now? Both fields are nil when idle.
owner = client.chats.thread_owner(chat_id)
puts "Owner app: #{owner.app_id.inspect} until #{owner.expires_at.inspect}"

# Escalate to a human in Meta's inbox (use INSTAGRAM_INBOX_APP_ID for Instagram)
chat = client.chats.pass_thread_control(chat_id,
  target_app_id: PAGE_INBOX_APP_ID,
  metadata: "escalated to support"
)
puts "Thread control: #{chat.metadata&.dig(:thread_control)}"

# Later: take it back (needs Conversation Routing on the Page) ...
client.chats.take_thread_control(chat_id)
# ... or, without Conversation Routing, ask the owner to pass it back and
# wait for the chat.thread_control_changed webhook.
# client.chats.request_thread_control(chat_id)

# Done: let the conversation go idle
client.chats.release_thread_control(chat_id)
