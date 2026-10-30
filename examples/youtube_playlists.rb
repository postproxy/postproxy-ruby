require "postproxy"

client = PostProxy::Client.new(ENV.fetch("POSTPROXY_API_KEY"))

profile_id = "your-youtube-profile-id"

# List the channel's playlists, page by page
page_token = nil
loop do
  page = client.profiles.youtube_playlists(profile_id, page_token: page_token)
  page.data.each do |p|
    puts "#{p.id}: #{p.title} (#{p.privacy_status}, #{p.item_count} videos)"
  end
  page_token = page.next_page_token
  break unless page_token
end

# Create a playlist and publish a video into it
playlist = client.profiles.create_youtube_playlist(profile_id, "Tutorials",
  description: "Step-by-step guides",
  privacy_status: "public"
)

post = client.posts.create(
  "How to set up your account",
  profiles: [profile_id],
  media: ["https://example.com/tutorial.mp4"],
  platforms: PostProxy::PlatformParams.new(
    youtube: PostProxy::YouTubeParams.new(title: "How to set up your account", playlist_id: playlist.id)
  )
)
puts "Post: #{post.id}"

# Rename it later; fields left out keep their value
client.profiles.update_youtube_playlist(profile_id, playlist.id, title: "Getting started")

# Deleting a playlist keeps its videos
# client.profiles.delete_youtube_playlist(profile_id, playlist.id)
