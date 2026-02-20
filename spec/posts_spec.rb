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
