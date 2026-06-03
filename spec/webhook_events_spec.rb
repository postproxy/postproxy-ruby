require "spec_helper"

RSpec.describe PostProxy::WebhookEvents do
  def envelope(type, data)
    { id: "evt_1", type: type, created_at: "2026-05-12T00:00:00Z", data: data }
  end

  it "parses post.processed" do
    event = described_class.parse(envelope("post.processed", {
      id: "p1", body: "hi", status: "processed", scheduled_at: nil,
      created_at: "2026-05-12T00:00:00Z",
      platforms: [{ id: "pf1", platform: "twitter", name: "X" }]
    }).to_json)
    expect(event.type).to eq("post.processed")
    expect(event.data).to be_a(PostProxy::WebhookEvents::PostProcessedData)
    expect(event.data.platforms.first.platform).to eq("twitter")
  end

  it "parses post.imported" do
    event = described_class.parse(envelope("post.imported", {
      id: "p1", body: "x", source: "imported", posted_at: "2026-05-11T00:00:00Z",
      created_at: "2026-05-12T00:00:00Z", platform: "instagram",
      profile: { id: "pf1", name: "Acme", platform: "instagram" },
      platform_post_id: "ig123", public_id: "DEF"
    }).to_json)
    expect(event.data).to be_a(PostProxy::WebhookEvents::PostImportedData)
    expect(event.data.platform_post_id).to eq("ig123")
    expect(event.data.profile.platform).to eq("instagram")
  end

  %w[platform_post.published platform_post.failed platform_post.failed_waiting_for_retry platform_post.insights].each do |type|
    it "parses #{type}" do
      event = described_class.parse(envelope(type, {
        id: "pp1", post_id: "p1", platform: "twitter",
        profile_id: "pf1", profile_name: "X", status: "published",
        error: nil, error_details: nil, platform_id: "tw_999"
      }).to_json)
      expect(event.type).to eq(type)
      expect(event.data).to be_a(PostProxy::WebhookEvents::PlatformPostData)
    end
  end

  %w[profile.connected profile.disconnected].each do |type|
    it "parses #{type}" do
      event = described_class.parse(envelope(type, {
        id: "pf1", name: "X", platform: "twitter",
        profile_group_id: "g1", status: "active", uid: "u1", username: "handle"
      }).to_json)
      expect(event.data).to be_a(PostProxy::WebhookEvents::ProfileEventData)
    end
  end

  it "parses profile.stats" do
    event = described_class.parse(envelope("profile.stats", {
      profile_id: "pf1", platform: "linkedin", placement_id: "org_1",
      stats: { followerCount: 4567 }, recorded_at: "2026-05-12T00:00:00Z"
    }).to_json)
    expect(event.data).to be_a(PostProxy::WebhookEvents::ProfileStatsData)
    expect(event.data.placement_id).to eq("org_1")
    expect(event.data.stats[:followerCount]).to eq(4567)
  end

  it "parses media.failed" do
    event = described_class.parse(envelope("media.failed", {
      id: "m1", post_id: "p1", content_type: "image/jpeg",
      status: "failed", error_message: "broken"
    }).to_json)
    expect(event.data).to be_a(PostProxy::WebhookEvents::MediaFailedData)
  end

  it "parses comment.created" do
    event = described_class.parse(envelope("comment.created", {
      id: "c1", post_id: "p1", platform_post_id: "pp1", platform: "instagram",
      external_id: "ig_c", parent_external_id: nil, body: "great",
      status: "published", author_external_id: "u",
      author_name: "Jane", author_username: "jane",
      author_avatar_url: nil, like_count: 0, reply_count: 0,
      is_hidden: false, permalink: nil, platform_data: nil,
      posted_at: nil, created_at: "2026-05-12T00:00:00Z"
    }).to_json)
    expect(event.data).to be_a(PostProxy::WebhookEvents::CommentCreatedData)
    expect(event.data.author_name).to eq("Jane")
  end

  def mock_message(overrides = {})
    {
      id: "msg_1", chat_id: "chat_1", external_id: "mid.1", direction: "inbound",
      body: "hi", status: "received", reactions: [], attachments: [],
      is_unsupported: false, created_at: "2026-06-01T00:00:00Z"
    }.merge(overrides)
  end

  %w[message.received message.sent message.delivered message.read
     message.edited message.deleted message.failed_waiting_for_retry message.failed].each do |type|
    it "parses #{type}" do
      event = described_class.parse(envelope(type, { message: mock_message }).to_json)
      expect(event.type).to eq(type)
      expect(event.data).to be_a(PostProxy::WebhookEvents::MessageEventData)
      expect(event.data.message).to be_a(PostProxy::Message)
      expect(event.data.message.id).to eq("msg_1")
    end
  end

  it "parses reaction.received" do
    event = described_class.parse(envelope("reaction.received", {
      message: mock_message(reactions: [
        { sender_external_id: "psid_123", emoji: "❤️", reaction: "love", at: "2026-06-01T15:02:00Z" }
      ]),
      sender_external_id: "psid_123",
      action: "react",
      reaction: "love",
      emoji: "❤️",
      occurred_at: "2026-06-01T15:02:00Z"
    }).to_json)
    expect(event.data).to be_a(PostProxy::WebhookEvents::ReactionEventData)
    expect(event.data.action).to eq("react")
    expect(event.data.message).to be_a(PostProxy::Message)
    expect(event.data.message.reactions.first.reaction).to eq("love")
  end

  it "parses profile_comment.created" do
    event = described_class.parse(envelope("profile_comment.created", {
      id: "abc123", profile_id: "prof123", platform: "google_business",
      placement_id: "accounts/1/locations/2",
      external_id: "accounts/1/locations/2/reviews/A", parent_external_id: nil,
      body: "Great coffee!", status: "synced", author_username: "Jane D.",
      author_avatar_url: nil, platform_data: { star_rating: 5 },
      posted_at: "2026-05-10T11:55:00Z", created_at: "2026-05-13T18:00:00Z"
    }).to_json)
    expect(event.data).to be_a(PostProxy::WebhookEvents::ProfileCommentCreatedData)
    expect(event.data.author_username).to eq("Jane D.")
    expect(event.data.platform_data[:star_rating]).to eq(5)
  end

  it "accepts a Hash body" do
    event = described_class.parse(envelope("media.failed", {
      id: "m1", post_id: "p1", content_type: "image/jpeg",
      status: "failed", error_message: "broken"
    }))
    expect(event.type).to eq("media.failed")
  end

  it "raises on unknown type" do
    expect {
      described_class.parse(envelope("foo.bar", {}).to_json)
    }.to raise_error(PostProxy::WebhookParseError)
  end

  it "raises on invalid JSON" do
    expect { described_class.parse("not json{") }.to raise_error(PostProxy::WebhookParseError)
  end
end
