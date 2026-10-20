require "postproxy"

client = PostProxy::Client.new(ENV.fetch("POSTPROXY_API_KEY"))
gbp = client.google_business

profile_id = "your-google-business-profile-id"

# location_id is the placement id of the location
location_id = client.profiles.placements(profile_id).data.first.id

# Read and update the location
location = gbp.location(profile_id, location_id, read_mask: "title,phoneNumbers,websiteUri,regularHours")
puts "Location: #{location}"

gbp.update_location(profile_id, location_id, { websiteUri: "https://example.com" }, fields: ["websiteUri"])

# Opening hours: Mon-Fri 9-17
weekdays = %w[MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY]
gbp.update_hours(profile_id, location_id,
  fields: ["regularHours"],
  regular_hours: {
    periods: weekdays.map do |day|
      { openDay: day, openTime: { hours: 9 }, closeDay: day, closeTime: { hours: 17 } }
    end
  }
)

# Booking link
types = gbp.available_place_action_types(profile_id, location_id)
puts "Available action types: #{types}"
gbp.create_place_action_link(profile_id, location_id,
  uri: "https://book.example.com",
  place_action_type: "APPOINTMENT",
  is_preferred: true
)

# Add a storefront photo
gbp.create_media(profile_id, location_id, "https://example.com/storefront.jpg",
  category: "EXTERIOR",
  media_format: "PHOTO"
)
puts "Media: #{gbp.media(profile_id, location_id)}"
