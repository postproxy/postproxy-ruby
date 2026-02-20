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
