require "spec_helper"

RSpec.describe "PostProxy types" do
  describe PostProxy::Post do
    it "parses basic post attributes" do
      post = PostProxy::Post.new(
        id: "post-1",
        body: "Hello",
        status: "processed",
        created_at: "2025-01-01T00:00:00Z"
      )

      expect(post.id).to eq("post-1")
      expect(post.body).to eq("Hello")
      expect(post.status).to eq("processed")
      expect(post.created_at).to be_a(Time)
      expect(post.platforms).to eq([])
    end

    it "parses platform results with insights" do
      post = PostProxy::Post.new(
        id: "post-1",
        body: "Hello",
        status: "processed",
        created_at: "2025-01-01T00:00:00Z",
        platforms: [
          {
            platform: "instagram",
            status: "published",
            attempted_at: "2025-01-01T00:01:00Z",
            insights: { impressions: 250, on: "2025-01-02T00:00:00Z" }
          }
        ]
      )

      expect(post.platforms.length).to eq(1)
      pr = post.platforms.first
      expect(pr).to be_a(PostProxy::PlatformResult)
      expect(pr.platform).to eq("instagram")
      expect(pr.insights).to be_a(PostProxy::Insights)
      expect(pr.insights.impressions).to eq(250)
    end
  end

  describe PostProxy::Profile do
    it "parses profile attributes" do
      profile = PostProxy::Profile.new(
        id: "prof-1",
        name: "Test",
        status: "active",
        platform: "facebook",
        profile_group_id: "pg-1",
        post_count: 42
      )

      expect(profile.id).to eq("prof-1")
      expect(profile.post_count).to eq(42)
      expect(profile.expires_at).to be_nil
    end
  end

  describe PostProxy::ProfileGroup do
    it "parses profile group attributes" do
      group = PostProxy::ProfileGroup.new(id: "pg-1", name: "Group", profiles_count: 3)

      expect(group.id).to eq("pg-1")
      expect(group.name).to eq("Group")
      expect(group.profiles_count).to eq(3)
    end
  end

  describe PostProxy::PaginatedResponse do
    it "wraps data with pagination info" do
      response = PostProxy::PaginatedResponse.new(
        data: [1, 2, 3],
        total: 100,
        page: 1,
        per_page: 3
      )

      expect(response.data).to eq([1, 2, 3])
      expect(response.total).to eq(100)
      expect(response.page).to eq(1)
      expect(response.per_page).to eq(3)
    end
  end

  describe PostProxy::StatsRecord do
    it "parses stats and recorded_at" do
      record = PostProxy::StatsRecord.new(
        stats: { impressions: 1200, likes: 85 },
        recorded_at: "2026-02-20T12:00:00Z"
      )

      expect(record.stats).to eq({ impressions: 1200, likes: 85 })
      expect(record.recorded_at).to be_a(Time)
    end
  end

  describe PostProxy::PlatformStats do
    it "parses platform stats with nested records" do
      ps = PostProxy::PlatformStats.new(
        profile_id: "prof_abc",
        platform: "instagram",
        records: [
          { stats: { impressions: 100 }, recorded_at: "2026-02-20T12:00:00Z" }
        ]
      )

      expect(ps.profile_id).to eq("prof_abc")
      expect(ps.platform).to eq("instagram")
      expect(ps.records.length).to eq(1)
      expect(ps.records.first).to be_a(PostProxy::StatsRecord)
    end
  end

  describe PostProxy::PostStats do
    it "parses post stats with nested platform stats" do
      post_stats = PostProxy::PostStats.new(
        platforms: [
          {
            profile_id: "prof_abc",
            platform: "instagram",
            records: [
              { stats: { impressions: 1200 }, recorded_at: "2026-02-20T12:00:00Z" }
            ]
          }
        ]
      )

      expect(post_stats.platforms.length).to eq(1)
      expect(post_stats.platforms.first).to be_a(PostProxy::PlatformStats)
      expect(post_stats.platforms.first.records.first.stats[:impressions]).to eq(1200)
    end
  end

  describe PostProxy::StatsResponse do
    it "wraps data hash" do
      response = PostProxy::StatsResponse.new(data: { "abc" => "value" })
      expect(response.data).to eq({ "abc" => "value" })
    end
  end

  describe PostProxy::Attachment do
    it "parses attachment attributes" do
      att = PostProxy::Attachment.new(id: "att_1", type: "image",
        url: "https://cdn.example.com/a.jpg", status: "processed", external_id: nil)
      expect(att.id).to eq("att_1")
      expect(att.type).to eq("image")
      expect(att.status).to eq("processed")
      expect(att.external_id).to be_nil
    end
  end

  describe PostProxy::Reaction do
    it "parses reaction attributes and timestamp" do
      reaction = PostProxy::Reaction.new(sender_external_id: "psid_1",
        emoji: "❤️", reaction: "love", at: "2026-05-31T14:04:00Z")
      expect(reaction.sender_external_id).to eq("psid_1")
      expect(reaction.reaction).to eq("love")
      expect(reaction.at).to be_a(Time)
    end
  end

  describe PostProxy::Chat do
    it "parses chat attributes and timestamps; archived is optional" do
      chat = PostProxy::Chat.new(
        id: "chat_1", profile_id: "prof_1", platform: "instagram",
        participant_external_id: "igsid_1",
        last_message_at: "2026-05-31T15:10:00Z",
        metadata: { follower_count: 10 },
        created_at: "2026-04-12T08:00:00Z"
      )
      expect(chat.id).to eq("chat_1")
      expect(chat.last_message_at).to be_a(Time)
      expect(chat.created_at).to be_a(Time)
      expect(chat.metadata[:follower_count]).to eq(10)
      expect(chat.archived).to be_nil
    end
  end

  describe PostProxy::Message do
    it "parses message with nested reactions and attachments" do
      msg = PostProxy::Message.new(
        id: "msg_1", chat_id: "chat_1", direction: "inbound",
        body: "hi", status: "received",
        external_posted_at: "2026-05-31T14:02:00Z",
        reactions: [{ sender_external_id: "psid_1", reaction: "love", at: "2026-05-31T14:04:00Z" }],
        attachments: [{ id: "att_1", type: "image", url: "u", status: "processed" }],
        created_at: "2026-05-31T14:02:01Z"
      )
      expect(msg.direction).to eq("inbound")
      expect(msg.external_posted_at).to be_a(Time)
      expect(msg.created_at).to be_a(Time)
      expect(msg.reactions.first).to be_a(PostProxy::Reaction)
      expect(msg.attachments.first).to be_a(PostProxy::Attachment)
      expect(msg.is_unsupported).to be false
    end

    it "defaults reactions and attachments to empty arrays" do
      msg = PostProxy::Message.new(id: "m", chat_id: "c", direction: "outbound",
        status: "pending", created_at: "2026-05-31T14:02:01Z")
      expect(msg.reactions).to eq([])
      expect(msg.attachments).to eq([])
      expect(msg.body).to be_nil
    end
  end

  describe PostProxy::PlatformParams do
    it "serializes platform params excluding nil values" do
      params = PostProxy::PlatformParams.new(
        facebook: PostProxy::FacebookParams.new(format: "post", first_comment: "Hello"),
        instagram: PostProxy::InstagramParams.new(format: "reel")
      )

      h = params.to_h
      expect(h[:facebook]).to eq({ format: "post", first_comment: "Hello" })
      expect(h[:instagram]).to eq({ format: "reel" })
      expect(h).not_to have_key(:tiktok)
      expect(h).not_to have_key(:twitter)
    end
  end

  describe PostProxy::InstagramUserTag do
    it "serializes user tags as plain hashes, dropping unset coordinates" do
      params = PostProxy::PlatformParams.new(
        instagram: PostProxy::InstagramParams.new(
          format: "post",
          user_tags: [
            { username: "natgeo", x: 0.5, y: 0.4 },
            { username: "nasa", x: 0.2, y: 0.8, media_index: 1 },
            # Video slides are tagged by username only.
            { username: "spacex", media_index: 2 }
          ]
        )
      )

      tags = params.to_h[:instagram][:user_tags]
      expect(tags.length).to eq(3)
      expect(tags[0]).to eq({ username: "natgeo", x: 0.5, y: 0.4 })
      expect(tags[2]).to eq({ username: "spacex", media_index: 2 })
    end
  end

  describe PostProxy::StatsRecord do
    it "carries raw_stats alongside stats" do
      record = PostProxy::StatsRecord.new(
        stats: { impressions: 1200 },
        raw_stats: { views: 1200, impression_count: 1200 },
        recorded_at: "2026-02-20T12:00:00Z"
      )

      expect(record.raw_stats[:views]).to eq(1200)
      expect(record.recorded_at).to be_a(Time)
    end

    it "defaults raw_stats to an empty hash when absent" do
      record = PostProxy::StatsRecord.new(stats: {}, recorded_at: "2026-02-20T12:00:00Z")
      expect(record.raw_stats).to eq({})
    end
  end

  describe PostProxy::PostSync do
    it "parses timestamps and counts" do
      sync = PostProxy::PostSync.new(
        id: "sync456def",
        profile_id: "prof123abc",
        kind: "posts",
        trigger: "backfill",
        status: "running",
        started_at: "2026-08-06T09:15:02.000Z",
        completed_at: nil,
        posts_seen: 150,
        posts_imported: 143,
        backfill_from: "2025-01-01T00:00:00.000Z",
        oldest_posted_at: "2025-11-04T18:22:00.000Z",
        error: nil,
        created_at: "2026-08-06T09:15:00.000Z"
      )

      expect(sync.trigger).to eq("backfill")
      expect(sync.posts_imported).to be < sync.posts_seen
      expect(sync.started_at).to be_a(Time)
      expect(sync.completed_at).to be_nil
    end
  end
end
