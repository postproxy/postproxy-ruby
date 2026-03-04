require "spec_helper"

RSpec.describe PostProxy::Resources::Posts do
  let(:client) { new_client }

  describe "#list" do
    it "returns paginated posts" do
      stub_api(:get, "/posts", body: {
        data: [
          { id: "post-1", body: "Hello", status: "processed", created_at: "2025-01-01T00:00:00Z", platforms: [] }
        ],
        total: 1,
        page: 1,
        per_page: 10
      })

      result = client.posts.list
      expect(result).to be_a(PostProxy::PaginatedResponse)
      expect(result.data.length).to eq(1)
      expect(result.data.first.id).to eq("post-1")
      expect(result.total).to eq(1)
      expect(result.page).to eq(1)
      expect(result.per_page).to eq(10)
    end

    it "sends filter parameters" do
      stub = stub_api(:get, "/posts",
        body: { data: [], total: 0, page: 2, per_page: 5 },
        query: { page: "2", per_page: "5", status: "draft" }
      )

      client.posts.list(page: 2, per_page: 5, status: "draft")
      expect(stub).to have_been_requested
    end
  end

  describe "#get" do
    it "returns a single post with platform results" do
      stub_api(:get, "/posts/post-1", body: {
        id: "post-1",
        body: "Hello",
        status: "processed",
        created_at: "2025-01-01T00:00:00Z",
        platforms: [
          {
            platform: "instagram",
            status: "published",
            attempted_at: "2025-01-01T00:01:00Z",
            insights: { impressions: 100, on: "2025-01-02T00:00:00Z" }
          }
        ]
      })

      post = client.posts.get("post-1")
      expect(post.id).to eq("post-1")
      expect(post.platforms.length).to eq(1)
      expect(post.platforms.first.platform).to eq("instagram")
      expect(post.platforms.first.status).to eq("published")
      expect(post.platforms.first.insights.impressions).to eq(100)
    end
  end

  describe "#create" do
    it "creates a post with JSON payload" do
      stub = stub_api(:post, "/posts", body: {
        id: "post-new",
        body: "Test post",
        status: "pending",
        created_at: "2025-01-01T00:00:00Z",
        platforms: []
      })

      post = client.posts.create("Test post", profiles: ["prof-1"])
      expect(post.id).to eq("post-new")
      expect(post.body).to eq("Test post")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:post][:body] == "Test post" && body[:profiles] == ["prof-1"]
        }
    end

    it "includes media URLs in payload" do
      stub_api(:post, "/posts", body: {
        id: "post-media",
        body: "With media",
        status: "pending",
        created_at: "2025-01-01T00:00:00Z",
        platforms: []
      })

      client.posts.create("With media", profiles: ["prof-1"], media: ["https://example.com/img.jpg"])

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:media] == ["https://example.com/img.jpg"]
        }
    end

    it "includes platform params" do
      stub_api(:post, "/posts", body: {
        id: "post-plat",
        body: "Platform post",
        status: "pending",
        created_at: "2025-01-01T00:00:00Z",
        platforms: []
      })

      platforms = PostProxy::PlatformParams.new(
        facebook: PostProxy::FacebookParams.new(format: "post", first_comment: "Hi!")
      )

      client.posts.create("Platform post", profiles: ["prof-1"], platforms: platforms)

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:platforms][:facebook][:format] == "post" &&
            body[:platforms][:facebook][:first_comment] == "Hi!"
        }
    end
  end

  describe "#stats" do
    let(:stats_response) do
      {
        data: {
          "abc123" => {
            platforms: [
              {
                profile_id: "prof_abc",
                platform: "instagram",
                records: [
                  {
                    stats: { impressions: 1200, likes: 85, comments: 12, saved: 8 },
                    recorded_at: "2026-02-20T12:00:00Z"
                  },
                  {
                    stats: { impressions: 1523, likes: 102, comments: 15, saved: 11 },
                    recorded_at: "2026-02-21T04:00:00Z"
                  }
                ]
              }
            ]
          },
          "def456" => {
            platforms: [
              {
                profile_id: "prof_def",
                platform: "twitter",
                records: [
                  {
                    stats: { impressions: 430, likes: 22, retweets: 5 },
                    recorded_at: "2026-02-20T12:00:00Z"
                  }
                ]
              }
            ]
          }
        }
      }
    end

    it "returns stats for multiple posts" do
      stub_api(:get, "/posts/stats",
        body: stats_response,
        query: { post_ids: "abc123,def456" }
      )

      result = client.posts.stats(["abc123", "def456"])
      expect(result).to be_a(PostProxy::StatsResponse)
      expect(result.data.keys).to contain_exactly("abc123", "def456")

      ig = result.data["abc123"]
      expect(ig).to be_a(PostProxy::PostStats)
      expect(ig.platforms.length).to eq(1)
      expect(ig.platforms.first.platform).to eq("instagram")
      expect(ig.platforms.first.profile_id).to eq("prof_abc")
      expect(ig.platforms.first.records.length).to eq(2)
      expect(ig.platforms.first.records.first.stats[:impressions]).to eq(1200)
      expect(ig.platforms.first.records.first.recorded_at).to be_a(Time)

      tw = result.data["def456"]
      expect(tw.platforms.first.platform).to eq("twitter")
      expect(tw.platforms.first.records.first.stats[:retweets]).to eq(5)
    end

    it "accepts a string of post_ids" do
      stub = stub_api(:get, "/posts/stats",
        body: { data: {} },
        query: { post_ids: "abc123" }
      )

      client.posts.stats("abc123")
      expect(stub).to have_been_requested
    end

    it "sends filter parameters" do
      stub = stub_api(:get, "/posts/stats",
        body: { data: {} },
        query: {
          post_ids: "abc123",
          profiles: "instagram,twitter",
          from: "2026-02-01T00:00:00Z",
          to: "2026-02-24T00:00:00Z"
        }
      )

      client.posts.stats(
        ["abc123"],
        profiles: ["instagram", "twitter"],
        from: "2026-02-01T00:00:00Z",
        to: "2026-02-24T00:00:00Z"
      )
      expect(stub).to have_been_requested
    end

    it "accepts profiles as a string" do
      stub = stub_api(:get, "/posts/stats",
        body: { data: {} },
        query: { post_ids: "abc123", profiles: "instagram" }
      )

      client.posts.stats("abc123", profiles: "instagram")
      expect(stub).to have_been_requested
    end

    it "accepts Time objects for from/to" do
      from_time = Time.parse("2026-02-01T00:00:00Z")
      to_time = Time.parse("2026-02-24T00:00:00Z")

      stub = stub_api(:get, "/posts/stats",
        body: { data: {} },
        query: {
          post_ids: "abc123",
          from: from_time.iso8601,
          to: to_time.iso8601
        }
      )

      client.posts.stats("abc123", from: from_time, to: to_time)
      expect(stub).to have_been_requested
    end
  end

  describe "#create with thread" do
    it "sends thread in request body" do
      stub_api(:post, "/posts", body: {
        id: "post-thread",
        body: "Main post",
        status: "pending",
        created_at: "2025-01-01T00:00:00Z",
        platforms: [],
        thread: [
          { id: "t-1", body: "Reply 1", media: [] },
          { id: "t-2", body: "Reply 2", media: [] },
        ]
      })

      post = client.posts.create("Main post", profiles: ["prof-1"], thread: [
        { body: "Reply 1" },
        { body: "Reply 2", media: ["https://example.com/img.jpg"] },
      ])
      expect(post.thread.length).to eq(2)
      expect(post.thread.first).to be_a(PostProxy::ThreadChild)
      expect(post.thread.first.body).to eq("Reply 1")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:thread].length == 2 &&
            body[:thread][0][:body] == "Reply 1" &&
            body[:thread][1][:media] == ["https://example.com/img.jpg"]
        }
    end
  end

  describe "#get with media and thread" do
    it "parses post with media and thread" do
      stub_api(:get, "/posts/post-1", body: {
        id: "post-1",
        body: "Hello",
        status: "media_processing_failed",
        created_at: "2025-01-01T00:00:00Z",
        platforms: [],
        media: [
          { id: "m-1", status: "processed", content_type: "image/jpeg", url: "https://cdn.example.com/img.jpg" }
        ],
        thread: [
          { id: "t-1", body: "Reply", media: [] }
        ]
      })

      post = client.posts.get("post-1")
      expect(post.status).to eq("media_processing_failed")
      expect(post.media.length).to eq(1)
      expect(post.media.first).to be_a(PostProxy::Media)
      expect(post.media.first.status).to eq("processed")
      expect(post.thread.length).to eq(1)
      expect(post.thread.first).to be_a(PostProxy::ThreadChild)
      expect(post.thread.first.body).to eq("Reply")
    end
  end

  describe "#publish_draft" do
    it "publishes a draft post" do
      stub_api(:post, "/posts/post-1/publish", body: {
        id: "post-1",
        body: "Draft",
        status: "processing",
        created_at: "2025-01-01T00:00:00Z",
        platforms: []
      })

      post = client.posts.publish_draft("post-1")
      expect(post.status).to eq("processing")
    end
  end

  describe "#delete" do
    it "deletes a post" do
      stub_api(:delete, "/posts/post-1", body: { deleted: true })

      result = client.posts.delete("post-1")
      expect(result).to be_a(PostProxy::DeleteResponse)
      expect(result.deleted).to be true
    end
  end
end
