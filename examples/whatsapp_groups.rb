require "postproxy"

client = PostProxy::Client.new(ENV.fetch("POSTPROXY_API_KEY"))
wa = client.whatsapp

profile_id = "your-whatsapp-profile-id"
phone_number_id = "your-phone-number-id"

# Business profile
wa.update_business_profile(profile_id, phone_number_id,
  about: "Fresh coffee, fast replies",
  websites: ["https://example.com"]
)

# Create a group and share its invite link
group = wa.create_group(profile_id, phone_number_id, "VIP customers",
  description: "Early access to new roasts",
  join_approval_mode: "approval_required"
)
group_id = group[:id].to_s
invite = wa.create_group_invite_link(profile_id, phone_number_id, group_id)
puts "Invite link: #{invite}"

# Approve everyone waiting to join
requests = wa.group_join_requests(profile_id, phone_number_id, group_id)
puts "Join requests: #{requests}"
wa.approve_group_join_requests(profile_id, phone_number_id, group_id, ["15551234567"])

# Block a spammer
wa.block_users(profile_id, phone_number_id, ["15557654321"])

# Report a purchase back to Meta for a click-to-WhatsApp ad
wa.send_conversion_event(profile_id,
  event_name: "Purchase",
  event_id: "order-1234",
  phone: "15551234567",
  currency: "USD",
  value: 24.5
)
