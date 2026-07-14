require "postproxy"

client = PostProxy::Client.new("your-api-key")

# List existing profile groups
groups = client.profile_groups.list
puts "Existing groups: #{groups.data.map(&:name)}"

# Create a new profile group
group = groups.data.first || client.profile_groups.create("My App")
puts "Created group: #{group.id}"

# Initialize an OAuth connection for Instagram
connection = client.profile_groups.initialize_connection(
  group.id,
  platform: "instagram",
  redirect_url: "https://myapp.com/callback"
)

puts "Redirect user to: #{connection.url}"

# After connecting, list a profile's placements (Pages, channels, locations)
placements = client.profiles.placements("profile-id").data
puts "Placements: #{placements.map { |p| [p.id, p.name] }}"

# Move one placement to a different profile group
unless placements.empty?
  client.profiles.assign_placement_to_group("profile-id",
    placement_id: placements.first.id,
    target_profile_group_id: "other-group-id"
  )
end
