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
end
