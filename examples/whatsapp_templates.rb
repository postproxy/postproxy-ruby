require "postproxy"

client = PostProxy::Client.new(ENV.fetch("POSTPROXY_API_KEY"))

profile_id = "your-whatsapp-profile-id"

# Create a template — Meta reviews it before it can be sent
template = client.whatsapp_templates.create(profile_id,
  name: "order_shipped",
  category: "UTILITY",
  language: "en_US",
  components: [
    { type: "BODY", text: "Hi {{1}}, your order {{2}} has shipped." }
  ]
)
puts "#{template.name} #{template.status}" # => "order_shipped PENDING"

# Check approval status (or subscribe to message_template.status_updated)
approved = client.whatsapp_templates.list(profile_id, status: "APPROVED", refresh: true)
puts "Approved: #{approved.data.map(&:name)}"

# Send it to a customer. The phone number id is a placement of the profile.
number = client.profiles.placements(profile_id).data.first
chat = client.chats.create(profile_id, "15551234567", placement_id: number.id)

client.messages.send(
  chat.id,
  template: PostProxy::MessageTemplateInput.new(
    name: "order_shipped",
    language: "en_US",
    variables: ["Jane", "#1234"]
  )
)

# Inside the 24h window, free-form messages work too
fresh = client.chats.get(chat.id)
if fresh.within_messaging_window
  client.messages.send(
    chat.id,
    location: PostProxy::MessageLocation.new(latitude: 52.52, longitude: 13.405, name: "Pickup point")
  )
end
