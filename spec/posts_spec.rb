require "spec_helper"
require "tempfile"

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

    it "includes twitter poll params" do
      stub_api(:post, "/posts", body: {
        id: "post-poll",
        body: "Which framework?",
        status: "pending",
        created_at: "2025-01-01T00:00:00Z",
        platforms: []
      })

      platforms = PostProxy::PlatformParams.new(
        twitter: PostProxy::TwitterParams.new(
          format: "poll",
          poll_options: ["Rails", "Django", "Laravel"],
          poll_duration_minutes: 1440
        )
      )

      client.posts.create("Which framework?", profiles: ["prof-1"], platforms: platforms)

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:platforms][:twitter][:format] == "poll" &&
            body[:platforms][:twitter][:poll_options] == %w[Rails Django Laravel] &&
            body[:platforms][:twitter][:poll_duration_minutes] == 1440
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
                    raw_stats: { views: 1200, like_count: 85 },
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

    it "passes delete_on_platform query param" do
      stub = stub_api(:delete, "/posts/post-1",
        body: { deleted: true },
        query: { delete_on_platform: "true" }
      )

      result = client.posts.delete("post-1", delete_on_platform: true)
      expect(result.deleted).to be true
      expect(stub).to have_been_requested
    end
  end

  describe "#delete_on_platform" do
    it "deletes from all platforms with no params" do
      stub = stub_request(:post, "#{BASE_URL}/api/posts/post-1/delete_on_platform")
        .to_return(
          status: 200,
          body: {
            success: true,
            deleting: [{ post_profile_id: "pp-1", platform: "twitter" }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.posts.delete_on_platform("post-1")
      expect(result).to be_a(PostProxy::DeleteOnPlatformResponse)
      expect(result.success).to be true
      expect(result.deleting.length).to eq(1)
      expect(result.deleting.first).to be_a(PostProxy::DeletingPlatform)
      expect(result.deleting.first.platform).to eq("twitter")
      expect(stub).to have_been_requested
    end

    it "filters by network" do
      stub = stub_request(:post, "#{BASE_URL}/api/posts/post-1/delete_on_platform")
        .with(body: { network: "twitter" }.to_json)
        .to_return(
          status: 200,
          body: { success: true, deleting: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client.posts.delete_on_platform("post-1", network: "twitter")
      expect(stub).to have_been_requested
    end

    it "filters by profile_id" do
      stub = stub_request(:post, "#{BASE_URL}/api/posts/post-1/delete_on_platform")
        .with(body: { profile_id: "prof-1" }.to_json)
        .to_return(
          status: 200,
          body: { success: true, deleting: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client.posts.delete_on_platform("post-1", profile_id: "prof-1")
      expect(stub).to have_been_requested
    end

    it "filters by post_profile_id" do
      stub = stub_request(:post, "#{BASE_URL}/api/posts/post-1/delete_on_platform")
        .with(body: { post_profile_id: "pp-1" }.to_json)
        .to_return(
          status: 200,
          body: { success: true, deleting: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client.posts.delete_on_platform("post-1", post_profile_id: "pp-1")
      expect(stub).to have_been_requested
    end
  end
end

RSpec.describe PostProxy::Resources::Posts, "new platform params" do
  let(:client) { new_client }
  let(:post_body) { { id: "p", body: "hi", status: "pending", created_at: "2026-09-01T00:00:00Z", platforms: [] } }

  before { stub_api(:post, "/posts", body: post_body) }

  def sent_json
    body = nil
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts").with { |req| body = JSON.parse(req.body) }
    body
  end

  it "accepts { url: } media items" do
    client.posts.create("hi", profiles: ["prof_1"], media: ["https://a.test/1.jpg", { url: "https://a.test/2.jpg" }])
    expect(sent_json["media"]).to eq(["https://a.test/1.jpg", { "url" => "https://a.test/2.jpg" }])
  end

  it "sends new platform params in JSON" do
    platforms = PostProxy::PlatformParams.new(
      facebook: PostProxy::FacebookParams.new(link: "https://acme.test", countries: %w[US CA]),
      instagram: PostProxy::InstagramParams.new(
        format: "reel", audio_id: "123", audio_volume: 40, video_volume: 80,
        trial_strategy: "MANUAL", made_with_ai: true, strip_audio: false
      ),
      linkedin: PostProxy::LinkedInParams.new(
        format: "poll", organization_id: "1", poll_question: "Tabs or spaces?",
        poll_options: %w[Tabs Spaces], poll_duration_days: 3, reshare_urn: "urn:li:share:1"
      ),
      threads: PostProxy::ThreadsParams.new(topic_tag: "Coffee", alt_text: "A cup"),
      tiktok: PostProxy::TikTokParams.new(
        format: "video", upload_as_draft: true, cover_url: "https://a.test/c.jpg", thumb_offset: 1500
      ),
      twitter: PostProxy::TwitterParams.new(alt_text: %w[one two]),
      bluesky: PostProxy::BlueskyParams.new(alt_text: "sky"),
      pinterest: PostProxy::PinterestParams.new(alt_text: "pin")
    )

    client.posts.create("hi", profiles: ["prof_1"], platforms: platforms)
    expect(sent_json["platforms"]).to eq(
      "facebook" => { "link" => "https://acme.test", "countries" => %w[US CA] },
      "instagram" => {
        "format" => "reel", "audio_id" => "123", "audio_volume" => 40, "video_volume" => 80,
        "trial_strategy" => "MANUAL", "made_with_ai" => true, "strip_audio" => false
      },
      "linkedin" => {
        "format" => "poll", "organization_id" => "1", "poll_question" => "Tabs or spaces?",
        "poll_options" => %w[Tabs Spaces], "poll_duration_days" => 3, "reshare_urn" => "urn:li:share:1"
      },
      "threads" => { "topic_tag" => "Coffee", "alt_text" => "A cup" },
      "tiktok" => {
        "format" => "video", "upload_as_draft" => true, "cover_url" => "https://a.test/c.jpg", "thumb_offset" => 1500
      },
      "twitter" => { "alt_text" => %w[one two] },
      "bluesky" => { "alt_text" => "sky" },
      "pinterest" => { "alt_text" => "pin" }
    )
  end

  it "sends X-Skip-Duplicate-Check only when requested" do
    client.posts.create("hello", profiles: ["prof_1"], skip_duplicate_check: true)
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts")
      .with(headers: { "X-Skip-Duplicate-Check" => "true" }).once

    WebMock.reset_executed_requests!
    client.posts.create("hello", profiles: ["prof_1"])
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts")
      .with { |req| !req.headers.key?("X-Skip-Duplicate-Check") }.once
  end
end

RSpec.describe PostProxy::Resources::Posts, "cover_file" do
  let(:client) { new_client }
  let(:post_body) { { id: "p", body: "x", status: "pending", created_at: "2026-09-01T00:00:00Z", platforms: [] } }
  let(:cover) do
    file = Tempfile.new(["cover", ".jpg"])
    file.write("fake-jpeg")
    file.flush
    file
  end

  after { cover.close! }

  it "uploads a local cover_file as multipart even without media_files" do
    stub_api(:post, "/posts", body: post_body)

    client.posts.create("New video", profiles: ["tt-profile"],
      media: ["https://a.test/clip.mp4"],
      platforms: { tiktok: { format: "video", cover_file: cover.path } })

    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts").with { |req|
      body = req.body
      req.headers["Content-Type"].include?("multipart/form-data") &&
        body.include?(%(name="platforms[tiktok][cover_file]"; filename="#{File.basename(cover.path)}")) &&
        body.include?("fake-jpeg") &&
        body.include?(%(name="platforms[tiktok][format]")) &&
        body.include?(%(name="media[]"))
    }
  end

  it "uploads a local cover_file on update" do
    stub_api(:patch, "/posts/post-1", body: post_body)

    client.posts.update("post-1",
      platforms: PostProxy::PlatformParams.new(youtube: PostProxy::YouTubeParams.new(cover_file: cover.path)))

    expect(WebMock).to have_requested(:patch, "#{BASE_URL}/api/posts/post-1").with { |req|
      req.headers["Content-Type"].include?("multipart/form-data") &&
        req.body.include?(%(name="platforms[youtube][cover_file]"; filename=))
    }
  end

  it "sends a base64 data URL cover_file as JSON" do
    stub_api(:post, "/posts", body: post_body)
    data_url = "data:image/png;base64,iVBORw0KGgo="

    client.posts.create("Pin", profiles: ["pin-profile"],
      media: ["https://a.test/v.mp4"],
      platforms: { pinterest: { board_id: "b1", cover_file: data_url } })

    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts").with { |req|
      JSON.parse(req.body)["platforms"] == { "pinterest" => { "board_id" => "b1", "cover_file" => data_url } }
    }
  end

  it "encodes array params and repeated fields as flat [] parts in multipart" do
    stub_api(:post, "/posts", body: post_body)

    client.posts.create("Multi", profiles: %w[p1 p2],
      media: ["https://a.test/1.jpg", { url: "https://a.test/2.jpg" }],
      platforms: {
        instagram: {
          cover_file: cover.path,
          alt_text: %w[first second],
          user_tags: [{ username: "nasa", x: 0.1, y: 0.2 }]
        }
      })

    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts").with { |req|
      names = req.body.scan(/name="([^"]+)"/).flatten
      names.count("profiles[]") == 2 &&
        names.count("media[]") == 2 &&
        names.count("platforms[instagram][alt_text][]") == 2 &&
        names.include?("platforms[instagram][user_tags][0][username]") &&
        req.body.include?("https://a.test/2.jpg") &&
        names.none? { |n| n.include?("[][]") }
    }
  end
end
