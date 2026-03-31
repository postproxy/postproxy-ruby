require "spec_helper"

RSpec.describe PostProxy::Resources::Comments do
  let(:client) { new_client }
  let(:post_id) { "post1" }
  let(:profile_id) { "prof1" }
  let(:comment_id) { "cmt_abc123" }

  let(:mock_reply) do
    {
      id: "cmt_def456",
      external_id: "17858893269123457",
      body: "Thanks!",
      status: "synced",
      author_username: "author",
      author_avatar_url: nil,
      author_external_id: "67890",
      parent_external_id: "17858893269123456",
      like_count: 1,
      is_hidden: false,
      permalink: nil,
      platform_data: nil,
      posted_at: "2026-03-25T10:05:00Z",
      created_at: "2026-03-25T10:05:00Z",
      replies: [],
    }
  end

  let(:mock_comment) do
    {
      id: "cmt_abc123",
      external_id: "17858893269123456",
      body: "Great post!",
      status: "synced",
      author_username: "someuser",
      author_avatar_url: nil,
      author_external_id: "12345",
      parent_external_id: nil,
      like_count: 3,
      is_hidden: false,
      permalink: nil,
      platform_data: nil,
      posted_at: "2026-03-25T10:00:00Z",
      created_at: "2026-03-25T10:01:00Z",
      replies: [mock_reply],
    }
  end

  describe "#list" do
    it "returns paginated comments" do
      stub_api(:get, "/posts/#{post_id}/comments",
        body: { data: [mock_comment], total: 1, page: 0, per_page: 20 },
        query: { profile_id: profile_id })

      result = client.comments.list(post_id, profile_id: profile_id)
      expect(result).to be_a(PostProxy::PaginatedResponse)
      expect(result.total).to eq(1)
      expect(result.data.length).to eq(1)
      expect(result.data.first).to be_a(PostProxy::Comment)
      expect(result.data.first.id).to eq("cmt_abc123")
      expect(result.data.first.body).to eq("Great post!")
      expect(result.data.first.replies.length).to eq(1)
      expect(result.data.first.replies.first.id).to eq("cmt_def456")
    end

    it "supports pagination params" do
      stub_api(:get, "/posts/#{post_id}/comments",
        body: { data: [], total: 42, page: 2, per_page: 10 },
        query: { profile_id: profile_id, page: "2", per_page: "10" })

      result = client.comments.list(post_id, profile_id: profile_id, page: 2, per_page: 10)
      expect(result.total).to eq(42)
      expect(result.page).to eq(2)
    end
  end

  describe "#get" do
    it "returns a single comment" do
      stub_api(:get, "/posts/#{post_id}/comments/#{comment_id}",
        body: mock_comment,
        query: { profile_id: profile_id })

      comment = client.comments.get(post_id, comment_id, profile_id: profile_id)
      expect(comment).to be_a(PostProxy::Comment)
      expect(comment.id).to eq("cmt_abc123")
      expect(comment.body).to eq("Great post!")
      expect(comment.like_count).to eq(3)
      expect(comment.replies.length).to eq(1)
    end
  end

  describe "#create" do
    it "creates a comment" do
      created = mock_comment.merge(id: "cmt_new", body: "Nice!", status: "pending", external_id: nil, replies: [])
      stub_api(:post, "/posts/#{post_id}/comments",
        body: created,
        query: { profile_id: profile_id })

      comment = client.comments.create(post_id, "Nice!", profile_id: profile_id)
      expect(comment).to be_a(PostProxy::Comment)
      expect(comment.id).to eq("cmt_new")
      expect(comment.status).to eq("pending")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts/#{post_id}/comments?profile_id=#{profile_id}")
        .with { |req| JSON.parse(req.body)["text"] == "Nice!" }
    end

    it "creates a reply with parent_id" do
      reply = mock_comment.merge(id: "cmt_reply", body: "Thanks!", status: "pending", replies: [])
      stub_api(:post, "/posts/#{post_id}/comments",
        body: reply,
        query: { profile_id: profile_id })

      comment = client.comments.create(post_id, "Thanks!", profile_id: profile_id, parent_id: "cmt_abc123")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts/#{post_id}/comments?profile_id=#{profile_id}")
        .with { |req|
          body = JSON.parse(req.body)
          body["text"] == "Thanks!" && body["parent_id"] == "cmt_abc123"
        }
    end
  end

  describe "#delete" do
    it "deletes a comment" do
      stub_api(:delete, "/posts/#{post_id}/comments/#{comment_id}",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.delete(post_id, comment_id, profile_id: profile_id)
      expect(result).to be_a(PostProxy::AcceptedResponse)
      expect(result.accepted).to be true
    end
  end

  describe "#hide" do
    it "hides a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/hide",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.hide(post_id, comment_id, profile_id: profile_id)
      expect(result).to be_a(PostProxy::AcceptedResponse)
      expect(result.accepted).to be true
    end
  end

  describe "#unhide" do
    it "unhides a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/unhide",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.unhide(post_id, comment_id, profile_id: profile_id)
      expect(result.accepted).to be true
    end
  end

  describe "#like" do
    it "likes a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/like",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.like(post_id, comment_id, profile_id: profile_id)
      expect(result.accepted).to be true
    end
  end

  describe "#unlike" do
    it "unlikes a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/unlike",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.unlike(post_id, comment_id, profile_id: profile_id)
      expect(result.accepted).to be true
    end
  end
end
