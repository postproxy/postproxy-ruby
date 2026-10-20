require "postproxy"

client = PostProxy::Client.new(ENV.fetch("POSTPROXY_API_KEY"))

profile_id = "your-instagram-profile-id"

chat = client.chats.list(profile_id, per_page: 1).data.first

# Show the participant we're on it, then send a product carousel
client.chats.mark_read(chat.id)
client.chats.start_typing(chat.id)

client.messages.send(
  chat.id,
  elements: [
    PostProxy::MessageElement.new(
      title: "Red sneaker",
      subtitle: "$89 — sizes 38-46",
      image_url: "https://cdn.example.com/red.png",
      buttons: [{ type: "web_url", title: "Buy", url: "https://shop.example.com/red" }]
    ),
    PostProxy::MessageElement.new(
      title: "Blue sneaker",
      subtitle: "$92 — back in stock soon",
      image_url: "https://cdn.example.com/blue.png",
      buttons: [{ type: "postback", title: "Notify me", payload: "NOTIFY:blue" }]
    )
  ]
)

client.chats.stop_typing(chat.id)
