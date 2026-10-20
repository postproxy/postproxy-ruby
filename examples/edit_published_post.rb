require "postproxy"

client = PostProxy::Client.new(ENV.fetch("POSTPROXY_API_KEY"))

# Only the body, the YouTube title and the Pinterest title / destination_link
# can change once a post is published.
post = client.posts.update(
  "published-post-id",
  body: "Launch day! (now with the right link)",
  platforms: PostProxy::PlatformParams.new(
    youtube: PostProxy::YouTubeParams.new(title: "Launch day — full walkthrough"),
    pinterest: PostProxy::PinterestParams.new(destination_link: "https://example.com/launch")
  )
)
post.platforms.each { |p| puts "#{p.platform}: #{p.permalink}" }

# The edit is pushed to each platform in the background. Your webhook handler
# learns how it went:
def handle_webhook(raw_body)
  event = PostProxy::WebhookEvents.parse(raw_body)
  case event.type
  when "platform_post.edited"
    puts "Edited on #{event.data.platform}"
  when "platform_post.edit_failed"
    puts "Edit failed on #{event.data.platform}: #{event.data.error}"
  end
end
